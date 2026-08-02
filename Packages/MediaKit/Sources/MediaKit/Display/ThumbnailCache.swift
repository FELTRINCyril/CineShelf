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

    private let source: MediaDataProvider
    private let directory: URL
    private let diskLimit: Int
    private let quality: Double
    private let memory = NSCache<NSString, CGImage>()
    private var pressureSource: DispatchSourceMemoryPressure?
    /// Les écritures différées, enchaînées : une seule à la fois sur le disque.
    private var writeChain = Task<Void, Never> {}

    /// - Parameters:
    ///   - source: accès aux octets de l'original.
    ///   - directory: dossier de cache. Par défaut `Caches/thumbnails`.
    ///   - memoryLimit: coût total du cache mémoire, en octets.
    ///   - diskLimit: taille du cache disque au-delà de laquelle il est purgé.
    ///   - quality: qualité HEIC des vignettes écrites sur disque.
    public init(
        source: @escaping MediaDataProvider,
        directory: URL? = nil,
        memoryLimit: Int = ThumbnailCache.defaultMemoryLimit,
        diskLimit: Int = ThumbnailCache.defaultDiskLimit,
        quality: Double = MediaIngestor.defaultQuality
    ) {
        self.source = source
        self.directory = directory ?? Self.defaultDirectory()
        self.diskLimit = diskLimit
        self.quality = quality
        memory.totalCostLimit = memoryLimit
    }

    /// La vignette pour cette taille et cette échelle, mémoire puis disque puis
    /// génération. `nil` si l'original est introuvable ou illisible.
    public func thumbnail(for assetID: UUID, targetSize: CGSize, scale: CGFloat) async -> CGImage? {
        let preset = ThumbnailPreset.covering(targetSize)
        let key = Self.key(assetID: assetID, preset: preset, scale: scale)

        if let cached = memory.object(forKey: key as NSString) { return cached }

        let file = directory.appendingPathComponent(key).appendingPathExtension("heic")
        if let stored = ImageDecoder.thumbnail(from: file, maxPixelSize: preset.maxPixelSize(scale: scale)) {
            remember(stored, key: key)
            return stored
        }

        guard let original = try? await source(assetID) else { return nil }
        guard
            let generated = ImageDecoder.thumbnail(
                from: original,
                maxPixelSize: preset.maxPixelSize(scale: scale),
                cacheImmediately: true
            )
        else {
            return nil
        }

        remember(generated, key: key)
        scheduleWrite(generated, to: file)
        return generated
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
