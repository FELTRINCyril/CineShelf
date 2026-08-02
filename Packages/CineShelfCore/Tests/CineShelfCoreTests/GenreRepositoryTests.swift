import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des genres")
@MainActor
struct GenreRepositoryTests {
    @Test("Le premier appel crée le genre")
    func firstCallCreates() throws {
        let (context, library) = try makeTestLibrary()
        let genre = try GenreRepository(context: context).findOrCreate(name: "Action", in: library)
        try context.save()

        #expect(genre.nameKey == "action")
        #expect(genre.target == .title)
        #expect(genre.library?.id == library.id)
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 1)
    }

    @Test("Le deuxième appel réutilise le genre, malgré accents et casse")
    func secondCallReuses() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)

        let first = try repository.findOrCreate(name: "Épouvante", in: library)
        try context.save()
        let second = try repository.findOrCreate(name: "  EPOUVANTE ", in: library)
        try context.save()

        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 1)
    }

    /// Le cas qui compte pour l'import : celui-ci insère par lots de 200, donc
    /// deux lignes du même fichier tombent entre deux sauvegardes.
    @Test("Deux appels avant la première sauvegarde ne créent qu'un genre")
    func deduplicatesBeforeFirstSave() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)

        let first = try repository.findOrCreate(name: "Comédie", in: library)
        let second = try repository.findOrCreate(name: "comedie", in: library)

        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 1)
    }

    @Test("Deux cibles différentes sont deux genres différents")
    func targetsAreDistinct() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)

        let forTitles = try repository.findOrCreate(name: "Drame", target: .title, in: library)
        let forPeople = try repository.findOrCreate(name: "Drame", target: .person, in: library)
        try context.save()

        #expect(forTitles.id != forPeople.id)
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 2)
    }

    @Test("Deux bibliothèques ne partagent pas leurs genres")
    func librariesDoNotShareGenres() throws {
        let (context, library) = try makeTestLibrary()
        let sandbox = Library(name: "Bac à sable", isDefault: false)
        context.insert(sandbox)
        try context.save()

        let repository = GenreRepository(context: context)
        let main = try repository.findOrCreate(name: "Action", in: library)
        let other = try repository.findOrCreate(name: "Action", in: sandbox)
        try context.save()

        #expect(main.id != other.id)
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 2)
    }

    @Test("Renommer rafraîchit la clé de dédoublonnage")
    func renameRefreshesKey() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genre = try repository.findOrCreate(name: "Action", in: library)
        try context.save()

        repository.rename(genre, to: "Aventure")
        try context.save()

        #expect(genre.nameKey == "aventure")

        let reused = try repository.findOrCreate(name: "aventure", in: library)
        #expect(reused.id == genre.id)

        let recreated = try repository.findOrCreate(name: "Action", in: library)
        #expect(recreated.id != genre.id)
    }
}
