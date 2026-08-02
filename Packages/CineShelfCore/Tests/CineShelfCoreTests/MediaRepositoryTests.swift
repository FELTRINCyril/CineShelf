import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des médias")
@MainActor
struct MediaRepositoryTests {
    @Test("La création relève la taille des données")
    func createMeasuresPayload() throws {
        let context = ModelContext(try makeTestContainer())
        let payload = Data(repeating: 0xAB, count: 128)
        let asset = MediaRepository(context: context).create(kind: .image, data: payload)
        try context.save()

        #expect(asset.kind == .image)
        #expect(asset.byteSize == 128)
        #expect(asset.data?.count == 128)
        #expect(try activityCount(in: context, action: .create) == 1)
    }

    @Test("Un média hébergé ailleurs n'a pas de données locales")
    func createAcceptsExternalURL() throws {
        let context = ModelContext(try makeTestContainer())
        let asset = MediaRepository(context: context).create(
            kind: .video,
            externalURLString: "https://exemple.test/bande-annonce.mp4"
        )
        try context.save()

        #expect(asset.data == nil)
        #expect(asset.byteSize == 0)
        #expect(asset.externalURLString == "https://exemple.test/bande-annonce.mp4")
    }

    @Test("La mise à jour touche updatedAt")
    func updateTouchesUpdatedAt() throws {
        let context = ModelContext(try makeTestContainer())
        let repository = MediaRepository(context: context)
        let asset = repository.create()
        let before = asset.updatedAt

        repository.update(asset) { updated in
            updated.pixelWidth = 2000
            updated.pixelHeight = 3000
            updated.blurHash = "L6PZfSi_.AyE"
        }
        try context.save()

        #expect(asset.pixelWidth == 2000)
        #expect(asset.updatedAt > before)
    }

    @Test("La suppression est douce, et la restauration la défait")
    func softDeleteAndRestore() throws {
        let context = ModelContext(try makeTestContainer())
        let repository = MediaRepository(context: context)
        let asset = repository.create()

        repository.softDelete(asset)
        try context.save()
        #expect(asset.deletedAt != nil)

        repository.restore(asset)
        try context.save()
        #expect(asset.deletedAt == nil)
    }

    @Test("Les recadrages disparaissent avec le média")
    func cropsCascadeOnRealDelete() throws {
        let context = ModelContext(try makeTestContainer())
        let asset = MediaRepository(context: context).create()
        let crop = MediaCrop(context: .card)
        crop.asset = asset
        context.insert(crop)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<MediaCrop>()) == 1)

        context.delete(asset)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MediaCrop>()) == 0)
    }
}
