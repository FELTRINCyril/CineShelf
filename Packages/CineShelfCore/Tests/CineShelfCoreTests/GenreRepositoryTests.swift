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

// MARK: - V5b · L'épinglage, écrit quinze prompts après avoir été lu

@Suite("Épinglage des genres")
@MainActor
struct GenrePinningTests {

    /// Trois genres, épinglés dans un ordre qui n'est pas l'ordre alphabétique — sans quoi le
    /// test ne départagerait pas « ordre d'épinglage » de « ordre de création ».
    private func pinnable(
        _ context: ModelContext, _ library: Library, _ names: [String]
    ) throws -> [Genre] {
        let repository = GenreRepository(context: context)
        let genres = try names.map { try repository.findOrCreate(name: $0, in: library) }
        try context.save()
        return genres
    }

    @Test("Épingler pose le genre en queue, pas en tête")
    func pinningAppends() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        // Trois noms qui ne sont pas dans l'ordre alphabétique de leur épinglage : si le rang
        // se déduisait du nom, ce test passerait par accident.
        let genres = try pinnable(context, library, ["Western", "Drame", "Polar"])

        for genre in genres { repository.setPinned(genre, true) }
        try context.save()

        // **Source : `HomeView` lit `GenreQuery.pinned` trié sur `pinIndex`.** L'ordre attendu
        // est donc celui des épinglages, pas celui des noms.
        let pinned = try context.fetch(
            FetchDescriptor<Genre>(
                predicate: GenreQuery.pinned, sortBy: [SortDescriptor(\.pinIndex)]))
        #expect(pinned.map(\.name) == ["Western", "Drame", "Polar"])
    }

    @Test("Désépingler ne renumérote pas, et le suivant ne réutilise pas le rang libéré")
    func unpinningLeavesAHole() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genres = try pinnable(context, library, ["Western", "Drame", "Polar"])
        for genre in genres { repository.setPinned(genre, true) }
        try context.save()

        // On retire celui du **milieu**, pas le premier ni le dernier : sur une borne, « ne
        // renumérote pas » et « renumérote » donnent le même résultat.
        repository.setPinned(genres[1], false)
        try context.save()

        let fourth = try pinnable(context, library, ["Comédie"])[0]
        repository.setPinned(fourth, true)
        try context.save()

        // Le rang 1 est libre, et le nouveau prend 3 : c'est le maximum + 1, pas le compte.
        // Avec le compte, « Comédie » serait entrée à 2 et se serait glissée avant « Polar ».
        #expect(fourth.pinIndex == 3)
        let pinned = try context.fetch(
            FetchDescriptor<Genre>(
                predicate: GenreQuery.pinned, sortBy: [SortDescriptor(\.pinIndex)]))
        #expect(pinned.map(\.name) == ["Western", "Polar", "Comédie"])
    }

    @Test("Réépingler un genre déjà épinglé ne le déplace pas")
    func pinningTwiceIsIdempotent() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genres = try pinnable(context, library, ["Western", "Drame"])
        for genre in genres { repository.setPinned(genre, true) }
        try context.save()

        let before = genres[0].pinIndex
        let journalBefore = try activityCount(in: context, action: .update)
        repository.setPinned(genres[0], true)
        try context.save()

        // Sans la garde, « Western » repartirait en queue **et** journaliserait une
        // modification que l'utilisateur n'a pas faite — une bascule qu'on rappuie par erreur
        // réordonnerait l'accueil.
        #expect(genres[0].pinIndex == before)
        #expect(try activityCount(in: context, action: .update) == journalBefore)
    }

    @Test("Un genre mis à la corbeille sort des épinglés")
    func trashedGenreLeavesThePins() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genres = try pinnable(context, library, ["Western", "Drame"])
        for genre in genres { repository.setPinned(genre, true) }
        try context.save()

        repository.softDelete(genres[0])
        try context.save()

        // `GenreQuery.pinned` porte déjà `deletedAt == nil` : le rail de l'accueil ne doit pas
        // survivre à la mise à la corbeille de son genre.
        let pinned = try context.fetch(FetchDescriptor<Genre>(predicate: GenreQuery.pinned))
        #expect(pinned.map(\.name) == ["Drame"])
    }
}
