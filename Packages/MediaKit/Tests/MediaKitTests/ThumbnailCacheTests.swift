import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

/// Sérialisée : le test de performance alloue quelques centaines de mégaoctets
/// de `CGImage`, et `NSCache` évince sous pression mémoire — y compris les
/// entrées des autres tests s'ils tournent en parallèle.
@Suite("Cache de vignettes", .serialized)
struct ThumbnailCacheTests {
    @Test("La taille demandée est arrondie au preset qui la couvre")
    func presetsCoverRequestedSizes() {
        #expect(ThumbnailPreset.covering(CGSize(width: 104, height: 156)) == .thumb)
        #expect(ThumbnailPreset.covering(CGSize(width: 148, height: 222)) == .card)
        #expect(ThumbnailPreset.covering(CGSize(width: 340, height: 227)) == .card)
        #expect(ThumbnailPreset.covering(CGSize(width: 900, height: 500)) == .hero)
        #expect(ThumbnailPreset.covering(CGSize(width: 4000, height: 3000)) == .hero)
    }

    @Test("Le nom de fichier suit docs/04 §4")
    func keyFollowsTheDocumentedShape() throws {
        let assetID = try #require(UUID(uuidString: "1B4E28BA-2FA1-11D2-883F-0016D3CCA427"))
        let key = ThumbnailCache.key(assetID: assetID, preset: .card, scale: 2)

        #expect(key == "1B4E28BA-2FA1-11D2-883F-0016D3CCA427-card@2x")
    }

    @Test("La vignette est générée, plus petite que l'original, et bornée par le preset")
    func thumbnailIsGeneratedAndBounded() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let image = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 148, height: 222),
            scale: 2
        )

        let thumbnail = try #require(image)
        #expect(max(thumbnail.width, thumbnail.height) == ThumbnailPreset.card.maxPixelSize(scale: 2))
    }

    @Test("Un asset inconnu ne donne pas de vignette")
    func unknownAssetYieldsNil() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let image = await fixture.cache.thumbnail(
            for: UUID(),
            targetSize: CGSize(width: 148, height: 222),
            scale: 2
        )

        #expect(image == nil)
    }

    @Test("La vignette est écrite sur disque, et relue sans toucher à l'original")
    func diskCacheIsUsedOnSecondCall() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()
        #expect(fixture.sourceReads.value == 1)

        let file = fixture.directory
            .appendingPathComponent(ThumbnailCache.key(assetID: fixture.assetID, preset: .card, scale: 2))
            .appendingPathExtension("heic")
        #expect(FileManager.default.fileExists(atPath: file.path))

        // Un cache neuf sur le même dossier : la mémoire est vide, le disque non.
        let second = ThumbnailCache(source: fixture.source, directory: fixture.directory)
        let image = await second.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)

        #expect(image != nil)
        #expect(fixture.sourceReads.value == 1)
    }

    /// `NSCache` peut évincer à tout moment sous pression mémoire : on vérifie
    /// que l'entrée est bien posée, et non qu'elle survit indéfiniment.
    @Test("La vignette est posée en mémoire dès le premier appel")
    func thumbnailLandsInMemory() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)

        #expect(await fixture.cache.hasMemoryEntry(for: fixture.assetID, targetSize: size, scale: 2))
        #expect(fixture.sourceReads.value == 1)
    }

    @Test("Une fois le cache chaud, l'original n'est plus relu")
    func warmCacheNeverReadsTheOriginalAgain() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()

        for _ in 0..<5 {
            _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        }

        #expect(fixture.sourceReads.value == 1)
    }

    @Test("Purger la mémoire force une relecture, purger le disque aussi")
    func purgingForcesRegeneration() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)

        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeMemoryCache()
        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        // Le disque a suffi.
        #expect(fixture.sourceReads.value == 1)

        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeMemoryCache()
        await fixture.cache.purgeDiskCache()
        _ = await fixture.cache.thumbnail(for: fixture.assetID, targetSize: size, scale: 2)
        #expect(fixture.sourceReads.value == 2)
    }

    @Test("Deux presets donnent deux entrées de cache distinctes")
    func presetsAreCachedSeparately() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }

        let small = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 104, height: 156),
            scale: 1
        )
        let large = await fixture.cache.thumbnail(
            for: fixture.assetID,
            targetSize: CGSize(width: 340, height: 227),
            scale: 1
        )

        let smallWidth = try #require(small).width
        let largeWidth = try #require(large).width
        #expect(smallWidth < largeWidth)
        #expect(fixture.sourceReads.value == 2)
    }

    @Test("Le cache disque est ramené sous sa limite, les plus anciennes d'abord")
    func diskCacheIsPurgedOverTheLimit() async throws {
        let fixture = try await Fixture(diskLimit: 4_096)
        defer { fixture.tearDown() }

        for index in 0..<12 {
            let side = 100 + index
            _ = await fixture.cache.thumbnail(
                for: fixture.assetID,
                targetSize: CGSize(width: side, height: side),
                scale: CGFloat(1 + index % 3)
            )
        }
        await fixture.cache.flushPendingWrites()
        await fixture.cache.purgeDiskCacheIfNeeded()

        let total = try totalSize(of: fixture.directory)
        #expect(total <= 4_096)
    }

    /// Le budget de `docs/04` §4 : moins de 20 ms pour générer une vignette.
    @Test("Performance : 200 vignettes")
    func twoHundredThumbnails() async throws {
        let fixture = try await Fixture()
        defer { fixture.tearDown() }
        let size = CGSize(width: 148, height: 222)
        let pixels = ThumbnailPreset.card.maxPixelSize(scale: 2)
        let original = try #require(await fixture.originalBytes())
        let clock = ContinuousClock()

        // 1. Le chemin d'affichage seul : décodage partiel et redimension.
        let decoding = clock.measure {
            for _ in 0..<200 {
                _ = ImageDecoder.thumbnail(from: original, maxPixelSize: pixels, cacheImmediately: true)
            }
        }

        // 2. Le même travail au travers du cache, écritures disque comprises.
        let assetIDs = (0..<200).map { _ in UUID() }
        for assetID in assetIDs { await fixture.register(assetID) }
        let throughCache = await clock.measure {
            for assetID in assetIDs {
                _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
            }
            await fixture.cache.flushPendingWrites()
        }

        // 3. Relecture depuis le disque, mémoire vidée.
        await fixture.cache.purgeMemoryCache()
        let fromDisk = await clock.measure {
            for assetID in assetIDs {
                _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
            }
        }

        // 4. Relecture mémoire sur un lot qui tient sous la limite du NSCache.
        let hot = Array(assetIDs.prefix(20))
        for assetID in hot { _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2) }
        let fromMemory = await clock.measure {
            for _ in 0..<10 {
                for assetID in hot {
                    _ = await fixture.cache.thumbnail(for: assetID, targetSize: size, scale: 2)
                }
            }
        }

        print(
            """
            PERF vignette \(pixels) px depuis un original 2000×3000, par unité :
              décodage + redimension seuls : \(Self.milliseconds(decoding, over: 200)) ms
              au travers du cache, écriture disque comprise : \
            \(Self.milliseconds(throughCache, over: 200)) ms
              relecture depuis le disque : \(Self.milliseconds(fromDisk, over: 200)) ms
              relecture depuis la mémoire : \(Self.milliseconds(fromMemory, over: 200)) ms
            """
        )

        // Le budget de docs/04 §4 porte sur la génération. Les relectures ne
        // sont pas comparées entre elles : `NSCache` peut évincer sous pression,
        // et une mesure qui en dépend serait instable.
        #expect(Self.seconds(decoding) / 200 * 1_000 < 20)
        #expect(Self.seconds(fromDisk) < Self.seconds(throughCache))
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    private static func milliseconds(_ duration: Duration, over count: Int) -> String {
        String(format: "%.2f", seconds(duration) / Double(count) * 1_000)
    }

    private func totalSize(of directory: URL) throws -> Int {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        return try files.reduce(0) { $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }
}

/// Un cache branché sur un original en mémoire, avec un compteur de lectures.
private struct Fixture {
    let directory: URL
    let cache: ThumbnailCache
    let assetID = UUID()
    let sourceReads = Counter()
    let source: MediaDataProvider
    private let originals = Originals()

    init(diskLimit: Int = ThumbnailCache.defaultDiskLimit) async throws {
        directory = try TestImage.makeScratchDirectory()
        let png = try TestImage.makePNGData(width: 2000, height: 3000)
        let ingested = try MediaIngestor().ingest(data: png)

        let originals = self.originals
        let reads = sourceReads
        await originals.register(assetID, data: ingested.data)
        source = { assetID in
            reads.increment()
            return await originals.data(for: assetID)
        }
        cache = ThumbnailCache(source: source, directory: directory, diskLimit: diskLimit)
    }

    func originalBytes() async -> Data? {
        await originals.data(for: assetID)
    }

    /// Ajoute un identifiant qui partage les mêmes octets : c'est le coût de
    /// génération qu'on mesure, pas celui de fabriquer 200 images différentes.
    func register(_ assetID: UUID) async {
        await originals.register(assetID, data: await originals.data(for: self.assetID))
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private actor Originals {
    private var storage: [UUID: Data] = [:]

    func register(_ assetID: UUID, data: Data?) {
        storage[assetID] = data
    }

    func data(for assetID: UUID) -> Data? {
        storage[assetID]
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
