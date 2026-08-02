import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des titres")
@MainActor
struct TitleRepositoryTests {
    @Test("La création rattache le titre à la bibliothèque et calcule les dérivés")
    func createAttachesAndDerives() throws {
        let (context, library) = try makeTestLibrary()
        let title = TitleRepository(context: context).create(name: "Épouvante", kind: .series, in: library)
        try context.save()

        #expect(title.library?.id == library.id)
        #expect(title.kind == .series)
        #expect(title.sortName == "epouvante")
        #expect(title.searchText == "epouvante")
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
    }

    @Test("La création est journalisée")
    func createIsRecorded() throws {
        let (context, library) = try makeTestLibrary()
        TitleRepository(context: context).create(name: "Solaris", in: library)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<ActivityEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.action == .create)
        #expect(entries.first?.entityTypeRaw == "Title")
        #expect(entries.first?.summary == "Solaris")
    }

    @Test("La mise à jour rafraîchit les dérivés")
    func updateRefreshesDerivedValues() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Dune", in: library)
        let before = title.updatedAt

        repository.update(title) { updated in
            updated.name = "Dune, deuxième partie"
            updated.summary = "Suite du Récit"
        }
        try context.save()

        #expect(title.sortName == "dune, deuxieme partie")
        #expect(title.searchText == "dune, deuxieme partie suite du recit")
        #expect(title.updatedAt > before)
        #expect(try activityCount(in: context, action: .update) == 1)
    }

    @Test("La suppression est douce, et la restauration la défait")
    func softDeleteAndRestore() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Stalker", in: library)

        repository.softDelete(title)
        try context.save()
        #expect(title.deletedAt != nil)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
        #expect(try activityCount(in: context, action: .delete) == 1)

        repository.restore(title)
        try context.save()
        #expect(title.deletedAt == nil)
        #expect(try activityCount(in: context, action: .restore) == 1)
    }

    @Test("Un titre supprimé sort des recherches par prédicat")
    func deletedTitleLeavesQueries() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        repository.create(name: "Persona", in: library)
        let hidden = repository.create(name: "Le Miroir", in: library)
        repository.softDelete(hidden)
        try context.save()

        let alive = FetchDescriptor<Title>(predicate: #Predicate { $0.deletedAt == nil })
        #expect(try context.fetchCount(alive) == 1)
    }
}
