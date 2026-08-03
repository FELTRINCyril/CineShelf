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
        // Sauvegarder **entre** les deux appels, sinon le second juge le premier
        // en mémoire, côté Swift, et la traduction SQL du prédicat n'est jamais
        // exercée : le test resterait vert même si `targetRaw` ne discriminait
        // rien en base.
        try context.save()
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
        // Sauvegarder ici est ce qui donne sa valeur au test : c'est la seule
        // façon d'exercer en SQL la traversée `library?.id` du prédicat de
        // `find`. Sans ce `save()`, le second appel juge le premier genre en
        // mémoire, et une traversée qui ne discriminerait rien en base — un
        // genre fuyant d'une bibliothèque à l'autre — passerait inaperçue.
        try context.save()
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

    // MARK: Corbeille
    //
    // `Genre` a une suppression douce parce qu'un genre supprimé en dur emporte
    // ses associations avec les titres et les personnes, définitivement — voir
    // `docs/02` §3.5. Ces tests verrouillent le comportement, en particulier
    // celui qui n'est pas évident : la recherche ne doit pas ressusciter.

    @Test("Supprimer un genre le met à la corbeille, sans détruire ses associations")
    func softDeleteKeepsTheGraph() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genre = try repository.findOrCreate(name: "Policier", in: library)

        let title = Title(name: "Le Deuxième Souffle")
        title.library = library
        title.genres = [genre]
        title.refreshDerived()
        context.insert(title)
        try context.save()

        repository.softDelete(genre)
        try context.save()

        #expect(genre.deletedAt != nil)
        // Ce que la corbeille protège : le lien survit, donc une restauration
        // rend quelque chose d'utile.
        #expect(title.genres?.contains { $0.id == genre.id } == true)
    }

    @Test("Restaurer un genre annule la suppression")
    func restoreClearsTheDeletionDate() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genre = try repository.findOrCreate(name: "Policier", in: library)

        repository.softDelete(genre)
        repository.restore(genre)
        try context.save()

        #expect(genre.deletedAt == nil)
    }

    @Test("Retaper un genre supprimé en crée un neuf plutôt que de le ressusciter")
    func findOrCreateNeverResurrects() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let original = try repository.findOrCreate(name: "Policier", in: library)
        try context.save()

        repository.softDelete(original)
        try context.save()

        let recreated = try repository.findOrCreate(name: "Policier", in: library)
        try context.save()

        #expect(recreated.id != original.id, "L'ancien genre a été ressuscité avec ses associations")
        #expect(recreated.deletedAt == nil)
        #expect(original.deletedAt != nil)

        // Deux lignes de même clé, dont une seule vivante : c'est le
        // comportement voulu, et ce que la future passe de fusion devra
        // respecter (`docs/02` §8).
        #expect(try context.fetchCount(FetchDescriptor<Genre>()) == 2)
    }

    @Test("La casse et les accents ne font pas échapper un genre supprimé")
    func deletionIsFoundThroughTheFoldedKey() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let original = try repository.findOrCreate(name: "Séries policières", in: library)
        try context.save()

        repository.softDelete(original)
        try context.save()

        // Même clé repliée : la recherche doit l'écarter tout autant.
        let recreated = try repository.findOrCreate(name: "series policieres", in: library)
        #expect(recreated.id != original.id)
    }
}
