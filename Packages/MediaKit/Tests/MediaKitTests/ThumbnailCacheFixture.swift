import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

// Le decor des tests de cache, sorti de leur fichier : `file_length` le refusait a 506
// lignes, et ces trois types sont du decor partage, pas des assertions.

/// Un cache branché sur un original en mémoire, avec un compteur de lectures.
struct Fixture {
    let directory: URL
    let cache: ThumbnailCache
    let assetID = UUID()
    let sourceReads = Counter()
    let source: MediaDataProvider
    private let originals = Originals()

    init(
        diskLimit: Int = ThumbnailCache.defaultDiskLimit,
        prefetchConcurrency: Int = ThumbnailCache.defaultPrefetchConcurrency,
        slowSourceBy delay: Duration? = nil
    ) async throws {
        directory = try TestImage.makeScratchDirectory()
        let png = try TestImage.makePNGData(width: 2000, height: 3000)
        let ingested = try MediaIngestor().ingest(data: png)

        let originals = self.originals
        let reads = sourceReads
        await originals.register(assetID, data: ingested.data)
        source = { assetID in
            reads.increment()
            // Un original lent rend le travail en vol observable : sans délai, une tâche
            // démarre et finit entre deux instructions du test, et on ne mesure plus rien.
            if let delay { try? await Task.sleep(for: delay) }
            return await originals.data(for: assetID)
        }
        cache = ThumbnailCache(
            source: source,
            directory: directory,
            diskLimit: diskLimit,
            prefetchConcurrency: prefetchConcurrency)
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

actor Originals {
    private var storage: [UUID: Data] = [:]

    func register(_ assetID: UUID, data: Data?) {
        storage[assetID] = data
    }

    func data(for assetID: UUID) -> Data? {
        storage[assetID]
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
