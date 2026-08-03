import CineShelfCore
import Foundation
import SwiftData
import Testing

@testable import MediaKit

@Suite("Déduplication par checksum")
@MainActor
struct DeduplicationTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(cloudKit: false, inMemory: true))
    }

    @Test("La même source ingérée deux fois ne crée qu'un asset")
    func sameSourceReusesTheAsset() throws {
        let context = try makeContext()
        let repository = MediaRepository(context: context)
        let source = try TestImage.makePNGData(width: 1200, height: 800)
        let ingestor = MediaIngestor()

        let first = try repository.findOrCreate(try ingestor.ingest(data: source).draft)
        try context.save()
        let second = try repository.findOrCreate(try ingestor.ingest(data: source).draft)
        try context.save()

        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)
    }

    @Test("Deux sources différentes font deux assets")
    func differentSourcesCreateTwoAssets() throws {
        let context = try makeContext()
        let repository = MediaRepository(context: context)
        let ingestor = MediaIngestor()

        let first = try repository.findOrCreate(
            try ingestor.ingest(data: try TestImage.makePNGData(width: 600, height: 400)).draft
        )
        // Sauvegarder entre les deux appels : sinon le second juge le premier
        // asset en mémoire et la comparaison de `checksum` du prédicat n'est
        // jamais traduite en SQL. Le cas du dédoublonnage *avant* sauvegarde a
        // son propre test juste en dessous, c'est là qu'il est le sujet.
        try context.save()
        let second = try repository.findOrCreate(
            try ingestor.ingest(data: try TestImage.makePNGData(width: 601, height: 400)).draft
        )
        try context.save()

        #expect(first.id != second.id)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 2)
    }

    @Test("Le dédoublonnage joue avant la première sauvegarde")
    func deduplicatesBeforeFirstSave() throws {
        let context = try makeContext()
        let repository = MediaRepository(context: context)
        let draft = try MediaIngestor().ingest(data: try TestImage.makePNGData(width: 500, height: 500)).draft

        let first = try repository.findOrCreate(draft)
        let second = try repository.findOrCreate(draft)

        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<MediaAsset>()) == 1)
    }

    @Test("L'asset créé porte tous les dérivés de l'ingestion")
    func assetCarriesEveryDerivedValue() throws {
        let context = try makeContext()
        let ingested = try MediaIngestor().ingest(data: try TestImage.makePNGData(width: 3000, height: 2000))
        let asset = try MediaRepository(context: context).findOrCreate(ingested.draft)
        try context.save()

        #expect(asset.checksum == ingested.checksum)
        #expect(asset.blurHash == ingested.blurHash)
        #expect(asset.pixelWidth == 2000)
        #expect(asset.pixelHeight == 1333)
        #expect(asset.byteSize == ingested.byteSize)
        #expect(asset.mimeType == "image/heic")
        #expect(asset.data?.count == ingested.byteSize)
    }

    @Test("Un asset sans checksum est toujours créé")
    func emptyChecksumAlwaysCreates() throws {
        let context = try makeContext()
        let repository = MediaRepository(context: context)

        let first = try repository.findOrCreate(MediaAssetDraft(externalURLString: "https://exemple.test/a.jpg"))
        let second = try repository.findOrCreate(MediaAssetDraft(externalURLString: "https://exemple.test/a.jpg"))
        try context.save()

        #expect(first.id != second.id)
    }

    @Test("Un asset à la corbeille n'est pas ressuscité")
    func trashedAssetIsNotReused() throws {
        let context = try makeContext()
        let repository = MediaRepository(context: context)
        let draft = try MediaIngestor().ingest(data: try TestImage.makePNGData(width: 700, height: 700)).draft

        let first = try repository.findOrCreate(draft)
        repository.softDelete(first)
        try context.save()

        let second = try repository.findOrCreate(draft)
        try context.save()

        #expect(first.id != second.id)
        #expect(second.deletedAt == nil)
    }

    @Test("Le cache lit les octets de l'asset stocké")
    func cacheReadsFromTheStoredAsset() async throws {
        let context = try makeContext()
        let ingested = try MediaIngestor().ingest(data: try TestImage.makePNGData(width: 1600, height: 1200))
        let asset = try MediaRepository(context: context).findOrCreate(ingested.draft)
        try context.save()

        let directory = try TestImage.makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bytes = ingested.data
        let cache = ThumbnailCache(source: { _ in bytes }, directory: directory)
        let thumbnail = await cache.loader()(asset.id, CGSize(width: 148, height: 222), 2)

        #expect(thumbnail != nil)
    }
}
