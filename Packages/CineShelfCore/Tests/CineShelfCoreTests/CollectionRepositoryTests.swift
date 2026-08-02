import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des collections")
@MainActor
struct CollectionRepositoryTests {
    @Test("La création rattache la collection et calcule les dérivés")
    func createAttachesAndDerives() throws {
        let (context, library) = try makeTestLibrary()
        let collection = CollectionRepository(context: context).create(name: "Épopées", in: library)
        try context.save()

        #expect(collection.library?.id == library.id)
        #expect(collection.sortName == "epopees")
        #expect(collection.searchText == "epopees")
        #expect(try activityCount(in: context, action: .create) == 1)
    }

    @Test("La mise à jour rafraîchit les dérivés")
    func updateRefreshesDerivedValues() throws {
        let (context, library) = try makeTestLibrary()
        let repository = CollectionRepository(context: context)
        let collection = repository.create(name: "Séries", in: library)

        repository.update(collection) { updated in
            updated.name = "Séries télé"
            updated.summary = "À suivre"
        }
        try context.save()

        #expect(collection.sortName == "series tele")
        #expect(collection.searchText == "series tele a suivre")
    }

    @Test("Les titres d'une collection survivent à sa suppression douce")
    func titlesSurviveCollectionSoftDelete() throws {
        let (context, library) = try makeTestLibrary()
        let collection = CollectionRepository(context: context).create(name: "Trilogie", in: library)
        let title = TitleRepository(context: context).create(name: "Le Parrain", in: library)
        title.collection = collection
        try context.save()

        CollectionRepository(context: context).softDelete(collection)
        try context.save()

        #expect(collection.deletedAt != nil)
        #expect(title.deletedAt == nil)
        #expect(title.collection?.id == collection.id)
    }

    @Test("La restauration défait la suppression")
    func restoreUndoesSoftDelete() throws {
        let (context, library) = try makeTestLibrary()
        let repository = CollectionRepository(context: context)
        let collection = repository.create(name: "Muet", in: library)

        repository.softDelete(collection)
        repository.restore(collection)
        try context.save()

        #expect(collection.deletedAt == nil)
        #expect(try activityCount(in: context, action: .restore) == 1)
    }
}
