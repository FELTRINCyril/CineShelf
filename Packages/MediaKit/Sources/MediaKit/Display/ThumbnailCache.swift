import CoreGraphics
import Dispatch
import Foundation
import ImageIO

/// Fournit les octets de l'original d'un média. C'est le seul lien du cache avec
/// le magasin : il ne connaît ni SwiftData ni `ModelContext`.
public typealias MediaDataProvider = @Sendable (UUID) async throws -> Data?

/// La closure que `MediaThumbnail` recevra en paramètre, côté `DesignSystem`.
public typealias ThumbnailLoader = @Sendable (UUID, CGSize, CGFloat) async -> CGImage?

/// Cache de vignettes à deux étages, mémoire puis disque (`docs/04` §4).
///
/// Rien n'est jamais écrit dans le modèle SwiftData : une vignette est
/// reconstructible, et le quota iCloud appartient à l'utilisateur.
public actor ThumbnailCache {
    public static let defaultMemoryLimit = 64 * 1_024 * 1_024
    public static let defaultDiskLimit = 200 * 1_024 * 1_024
    /// Combien de préchargements tournent en même temps.
    ///
    /// Deux, et non « autant que la fenêtre » : le préchargement doit rester derrière
    /// l'affichage, et une file de vingt décodages simultanés prend le dessus sur lui quoi
    /// qu'on déclare en priorité. Le reste attend dans `pending`.
    public static let defaultPrefetchConcurrency = 2

    private let source: MediaDataProvider
    private let directory: URL
    private let diskLimit: Int
    private let quality: Double
    private let prefetchConcurrency: Int
    private let memory = NSCache<NSString, CGImage>()
    private var pressureSource: DispatchSourceMemoryPressure?
    /// Les écritures différées, enchaînées : une seule à la fois sur le disque.
    private var writeChain = Task<Void, Never> {}
    /// Le travail en cours, par clé de vignette. C'est ce qui garantit « jamais deux fois
    /// le même travail » — entre deux affichages, entre deux préchargements, et entre les
    /// deux : un affichage qui tombe sur un préchargement déjà lancé **l'adopte**.
    private var work: [String: Work] = [:]
    /// Les préchargements en attente d'un créneau, dans l'ordre reçu.
    private var pending: [Request] = []

    /// - Parameters:
    ///   - source: accès aux octets de l'original.
    ///   - directory: dossier de cache. Par défaut `Caches/thumbnails`.
    ///   - memoryLimit: coût total du cache mémoire, en octets.
    ///   - diskLimit: taille du cache disque au-delà de laquelle il est purgé.
    ///   - quality: qualité HEIC des vignettes écrites sur disque.
    ///   - prefetchConcurrency: préchargements simultanés.
    public init(
        source: @escaping MediaDataProvider,
        directory: URL? = nil,
        memoryLimit: Int = ThumbnailCache.defaultMemoryLimit,
        diskLimit: Int = ThumbnailCache.defaultDiskLimit,
        quality: Double = MediaIngestor.defaultQuality,
        prefetchConcurrency: Int = ThumbnailCache.defaultPrefetchConcurrency
    ) {
        self.source = source
        self.directory = directory ?? Self.defaultDirectory()
        self.diskLimit = diskLimit
        self.quality = quality
        self.prefetchConcurrency = max(1, prefetchConcurrency)
        memory.totalCostLimit = memoryLimit
    }

    /// La vignette pour cette taille et cette échelle, mémoire puis disque puis
    /// génération. `nil` si l'original est introuvable ou illisible.
    public func thumbnail(for assetID: UUID, targetSize: CGSize, scale: CGFloat) async -> CGImage? {
        let request = Request(assetID: assetID, targetSize: targetSize, scale: scale)

        if let cached = memory.object(forKey: request.key as NSString) { return cached }

        // Un préchargement déjà en vol sur cette clé est adopté plutôt que doublé, et il
        // cesse d'être annulable : quelqu'un attend son résultat pour l'afficher.
        return await claim(request).value
    }

    // MARK: - Préchargement

    /// Prépare ces vignettes hors du chemin d'affichage.
    ///
    /// Ne rend rien et n'attend rien : c'est un ordre, pas une lecture. Les clés déjà en
    /// mémoire, déjà en travail ou déjà en attente sont ignorées — appeler cette méthode à
    /// chaque événement de défilement est donc sans conséquence.
    public func prefetch(_ assetIDs: [UUID], targetSize: CGSize, scale: CGFloat) {
        for assetID in assetIDs {
            let request = Request(assetID: assetID, targetSize: targetSize, scale: scale)
            guard memory.object(forKey: request.key as NSString) == nil else { continue }
            guard work[request.key] == nil else { continue }
            guard !pending.contains(where: { $0.key == request.key }) else { continue }
            pending.append(request)
        }
        startPendingPrefetches()
    }

    /// Annule le préchargement de ces vignettes.
    ///
    /// **Ce qui a été adopté par un affichage n'est pas annulé.** Une vue qui sort de
    /// l'écran annule ce qu'elle avait demandé en avance ; si une autre vue s'est mise à
    /// l'attendre entre-temps, l'annuler la laisserait sans image.
    public func cancelPrefetch(_ assetIDs: [UUID], targetSize: CGSize, scale: CGFloat) {
        let keys = Set(
            assetIDs.map { Request(assetID: $0, targetSize: targetSize, scale: scale).key }
        )
        pending.removeAll { keys.contains($0.key) }
        for key in keys {
            guard let entry = work[key], entry.isPrefetchOnly else { continue }
            entry.task.cancel()
            // Retirée du registre tout de suite : sinon un affichage qui arrive juste
            // après **adopterait une tâche déjà annulée** et n'obtiendrait jamais d'image.
            // C'est le défaut que le test « ce qu'un affichage attend n'est plus
            // annulable » a trouvé, et il ne se voyait pas sans course.
            work[key] = nil
        }
        startPendingPrefetches()
    }

    /// Vide la file d'attente et annule tous les préchargements non adoptés.
    public func cancelAllPrefetches() {
        pending.removeAll()
        for (key, entry) in work where entry.isPrefetchOnly {
            entry.task.cancel()
            work[key] = nil
        }
    }

    /// Attend la fin de tout le travail en cours, préchargements compris.
    ///
    /// Sert aux tests et aux mesures : sans elle on observe un cache à moitié rempli et on
    /// en tire des chiffres faux.
    public func drainPrefetches() async {
        while let entry = work.values.first {
            _ = await entry.task.value
        }
    }

    /// Ce qui reste à faire, pour les tests : la file d'attente et le travail en cours.
    var prefetchLoad: (pending: Int, running: Int) {
        (pending.count, work.count)
    }

    // MARK: - Le travail lui-même

    /// Rend la tâche qui produira cette vignette, en démarrant une seule si besoin.
    ///
    /// - Parameters:
    ///   - request: la vignette demandée.
    ///   - prefetchOnly: `false` marque la tâche comme attendue par un affichage, ce qui la
    ///     rend **non annulable** par `cancelPrefetch`.
    /// - Returns: la tâche à attendre — celle qui existait déjà, ou une neuve.
    private func claim(_ request: Request, prefetchOnly: Bool = false) -> Task<CGImage?, Never> {
        if let existing = work[request.key] {
            if !prefetchOnly, existing.isPrefetchOnly {
                work[request.key]?.isPrefetchOnly = false
            }
            return existing.task
        }

        let source = self.source
        let file = fileURL(for: request.key)
        let maxPixelSize = request.preset.maxPixelSize(scale: request.scale)
        let assetID = request.assetID

        let id = UUID()
        let task = Task<CGImage?, Never>(priority: prefetchOnly ? .utility : .userInitiated) {
            // `produce` est `nonisolated async` : appelée depuis un contexte isolé, elle
            // s'exécute sur l'exécuteur générique et **pas** sur celui de l'acteur. C'est
            // ce qui empêche un décodage de 25 ms de bloquer une lecture de cache mémoire
            // qui en coûte moins d'une.
            let image = await Self.produce(
                assetID: assetID, file: file, maxPixelSize: maxPixelSize, source: source)
            // Pas d'`await` ici, et c'est la preuve de ce qui précède : ce corps de tâche
            // **est** isolé à l'acteur — un `Task {}` créé en contexte isolé en hérite —
            // donc `finish` est un appel local. Seul `produce`, nonisolée, en sort.
            self.finish(request.key, id: id, image: image, file: file)
            return image
        }

        work[request.key] = Work(id: id, task: task, isPrefetchOnly: prefetchOnly)
        return task
    }

    /// Disque d'abord, génération ensuite. Hors de l'acteur, et annulable entre les deux.
    private nonisolated static func produce(
        assetID: UUID,
        file: URL,
        maxPixelSize: Int,
        source: MediaDataProvider
    ) async -> CGImage? {
        if let stored = ImageDecoder.thumbnail(from: file, maxPixelSize: maxPixelSize) {
            return stored
        }
        // Le seul point d'annulation utile : le décodage disque est déjà fait, celui de
        // l'original est le morceau cher.
        guard !Task.isCancelled else { return nil }
        guard let original = try? await source(assetID) else { return nil }
        guard !Task.isCancelled else { return nil }
        return ImageDecoder.thumbnail(
            from: original, maxPixelSize: maxPixelSize, cacheImmediately: true)
    }

    /// Retire la tâche du registre, mémorise le résultat, et enchaîne l'écriture disque
    /// seulement si la vignette a bien été **générée** — une vignette relue du disque n'a
    /// rien à y réécrire.
    private func finish(_ key: String, id: UUID, image: CGImage?, file: URL) {
        // Seulement si l'entrée est encore la nôtre : une annulation l'a peut-être retirée,
        // et une tâche neuve occupe alors la place.
        if work[key]?.id == id { work[key] = nil }
        defer { startPendingPrefetches() }

        guard let image else { return }
        remember(image, key: key)
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        scheduleWrite(image, to: file)
    }

    /// Remplit les créneaux libres avec la file d'attente.
    private func startPendingPrefetches() {
        while work.count < prefetchConcurrency, !pending.isEmpty {
            let request = pending.removeFirst()
            guard memory.object(forKey: request.key as NSString) == nil else { continue }
            _ = claim(request, prefetchOnly: true)
        }
    }

    /// Attend la fin des écritures différées.
    ///
    /// À appeler avant de purger le disque ou de mesurer le cache : sinon on
    /// court contre une écriture encore en vol.
    public func flushPendingWrites() async {
        await writeChain.value
    }

    /// La même chose, sous la forme de closure que consommeront les vues.
    public nonisolated func loader() -> ThumbnailLoader {
        { assetID, targetSize, scale in
            await self.thumbnail(for: assetID, targetSize: targetSize, scale: scale)
        }
    }

    public func purgeMemoryCache() {
        memory.removeAllObjects()
    }

    /// Vide le cache disque en entier : changement de format de dérivés, ou
    /// « libérer de l'espace » dans les réglages.
    public func purgeDiskCache() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Ramène le cache disque sous sa limite, les vignettes les moins récemment
    /// modifiées d'abord.
    public func purgeDiskCacheIfNeeded() {
        let files = Self.cachedFiles(in: directory)
        let total = files.reduce(0) { $0 + $1.size }
        guard total > diskLimit else { return }

        var remaining = total
        for file in files.sorted(by: { $0.modified < $1.modified }) {
            guard remaining > diskLimit / 2 else { break }
            try? FileManager.default.removeItem(at: file.url)
            remaining -= file.size
        }
    }

    /// Purge la mémoire dès que le système signale une pression.
    ///
    /// `DispatchSource` plutôt que `didReceiveMemoryWarning` : la notification
    /// est UIKit, la source de pression mémoire existe à l'identique sur iOS et
    /// sur macOS.
    public func startObservingMemoryPressure() {
        guard pressureSource == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { await self?.purgeMemoryCache() }
        }
        source.activate()
        pressureSource = source
    }

    /// L'encodage HEIC et l'écriture coûtent plus cher que le décodage : ils
    /// sortent du chemin d'affichage, qui rend la vignette immédiatement.
    private func scheduleWrite(_ image: CGImage, to file: URL) {
        let previous = writeChain
        writeChain = Task { [weak self] in
            await previous.value
            await self?.write(image, to: file)
        }
    }

    private func remember(_ image: CGImage, key: String) {
        memory.setObject(image, forKey: key as NSString, cost: image.height * image.bytesPerRow)
    }

    private func write(_ image: CGImage, to file: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try HEICEncoder.encode(image, quality: quality)
            try encoded.write(to: file, options: .atomic)
        } catch {
            // Un cache qui n'a pas pu écrire reste un cache : la vignette est
            // déjà en mémoire, elle sera simplement régénérée plus tard.
            return
        }
        purgeDiskCacheIfNeeded()
    }

    /// Présence d'une entrée en mémoire. `NSCache` pouvant évincer à tout moment,
    /// cette information n'a de sens qu'immédiatement après un accès.
    func hasMemoryEntry(for assetID: UUID, targetSize: CGSize, scale: CGFloat) -> Bool {
        let preset = ThumbnailPreset.covering(targetSize)
        return memory.object(forKey: Self.key(assetID: assetID, preset: preset, scale: scale) as NSString) != nil
    }

    static func key(assetID: UUID, preset: ThumbnailPreset, scale: CGFloat) -> String {
        "\(assetID.uuidString)-\(preset.rawValue)@\(max(1, Int(scale.rounded())))x"
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("heic")
    }

    private static func defaultDirectory() -> URL {
        let caches =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return caches.appendingPathComponent("thumbnails", isDirectory: true)
    }

    private static func cachedFiles(in directory: URL) -> [CachedFile] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys
            )
        else {
            return []
        }
        return entries.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return CachedFile(
                url: url,
                size: values.fileSize ?? 0,
                modified: values.contentModificationDate ?? .distantPast
            )
        }
    }
}

/// Une vignette sur disque, telle que la purge la voit.
private struct CachedFile {
    let url: URL
    let size: Int
    let modified: Date
}

extension ThumbnailCache {

    /// Une demande de vignette, réduite à ce qui l'identifie.
    ///
    /// Le `preset` et la clé se calculent ici et une seule fois : les trois chemins
    /// (affichage, préchargement, annulation) doivent tomber sur **la même** clé, sinon la
    /// coalescence et l'annulation se manquent en silence.
    fileprivate struct Request {
        let assetID: UUID
        let scale: CGFloat
        let preset: ThumbnailPreset
        let key: String

        init(assetID: UUID, targetSize: CGSize, scale: CGFloat) {
            let preset = ThumbnailPreset.covering(targetSize)
            self.assetID = assetID
            self.scale = scale
            self.preset = preset
            self.key = ThumbnailCache.key(assetID: assetID, preset: preset, scale: scale)
        }
    }

    /// Un travail en vol, et s'il reste annulable.
    ///
    /// **`id` n'est pas décoratif.** Une tâche annulée est retirée du registre
    /// immédiatement, ce qui permet à un affichage d'en démarrer une neuve sur la même clé.
    /// Les deux coexistent alors le temps que la première se termine, et sans cette
    /// identité la fin de l'ancienne effacerait l'entrée de la nouvelle — l'affichage
    /// resterait sans image et rien ne le signalerait.
    fileprivate struct Work {
        let id: UUID
        let task: Task<CGImage?, Never>
        var isPrefetchOnly: Bool
    }
}
