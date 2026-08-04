import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les fabriques de prédicats de `EntityQueries`.
//
// Ces six prédicats étaient écrits dans des vues, et c'était un écart connu : aucune
// cible de test ne monte les vues, donc ils étaient les seuls prédicats de production
// du dépôt sans couverture possible. Rapatriés dans `CineShelfCore`, ils deviennent
// vérifiables — et la règle `no_predicate_outside_core` empêche qu'un septième
// réapparaisse dans une vue.
//
// Chacun passe par le magasin, comme tout prédicat.

@MainActor
struct EntityQueryTests {

    @Test("Un titre se retrouve par son identifiant")
    func titleByID() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let wanted = repository.create(name: "Cherché", in: library)
        repository.create(name: "Autre", in: library)
        try context.save()

        let found = try context.fetch(FetchDescriptor<Title>(predicate: TitleQuery.withID(wanted.id)))
        #expect(found.map(\.name) == ["Cherché"])

        #expect(try context.fetch(FetchDescriptor<Title>(predicate: TitleQuery.withID(UUID()))).isEmpty)
    }

    @Test("Les genres vivants excluent la corbeille")
    func livingGenres() throws {
        // Le filtre qui compte : `docs/02` §3.5 impose que toute requête de genres
        // écarte la corbeille, sinon un genre supprimé réapparaît dans les sélecteurs.
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        try repository.findOrCreate(name: "Policier", in: library)
        let trashed = try repository.findOrCreate(name: "Navet", in: library)
        repository.softDelete(trashed)
        try context.save()

        let found = try context.fetch(FetchDescriptor<Genre>(predicate: GenreQuery.living))
        #expect(found.map(\.name) == ["Policier"])
    }

    @Test("Les genres épinglés excluent la corbeille et les archivés")
    func pinnedGenres() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)

        let pinned = try repository.findOrCreate(name: "Épinglé", in: library)
        pinned.isPinned = true
        let archived = try repository.findOrCreate(name: "Archivé", in: library)
        archived.isPinned = true
        archived.isArchived = true
        let trashed = try repository.findOrCreate(name: "Corbeille", in: library)
        trashed.isPinned = true
        repository.softDelete(trashed)
        try repository.findOrCreate(name: "Ordinaire", in: library)
        try context.save()

        let found = try context.fetch(FetchDescriptor<Genre>(predicate: GenreQuery.pinned))
        #expect(found.map(\.name) == ["Épinglé"])
    }

    @Test("Un genre se retrouve par sa clé repliée, dans sa bibliothèque")
    func genreByKeyAndLibrary() throws {
        // La clé est repliée sans accents ni casse : c'est ce qui remplace la
        // contrainte d'unicité que CloudKit interdit.
        let (context, library) = try makeTestLibrary()
        let elsewhere = Library(name: "Ailleurs")
        context.insert(elsewhere)
        let repository = GenreRepository(context: context)
        try repository.findOrCreate(name: "Épouvante", in: library)
        try repository.findOrCreate(name: "Épouvante", in: elsewhere)
        try context.save()

        let key = Genre.key(for: "epouvante")
        let scoped = try context.fetch(
            FetchDescriptor<Genre>(
                predicate: GenreQuery.living(key: key, target: .title, inLibrary: library.id))
        )
        #expect(scoped.count == 1)
        #expect(scoped.first?.library?.id == library.id)

        // Sans portée de bibliothèque, les deux sortent.
        let everywhere = try context.fetch(
            FetchDescriptor<Genre>(predicate: GenreQuery.living(key: key)))
        #expect(everywhere.count == 2)
    }

    @Test("Une cible différente ne se confond pas avec une autre")
    func genreTargetDiscriminates() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        try repository.findOrCreate(name: "Voix", target: .person, in: library)
        try context.save()

        let key = Genre.key(for: "Voix")
        let asTitle = try context.fetch(
            FetchDescriptor<Genre>(
                predicate: GenreQuery.living(key: key, target: .title, inLibrary: library.id))
        )
        #expect(asTitle.isEmpty)
    }

    @Test("Un média se retrouve par son identifiant")
    func assetByID() throws {
        let (context, _) = try makeTestLibrary()
        let asset = MediaAsset()
        asset.checksum = "abc"
        context.insert(asset)
        try context.save()

        let found = try context.fetch(
            FetchDescriptor<MediaAsset>(predicate: MediaQuery.asset(withID: asset.id)))
        #expect(found.count == 1)

        #expect(
            try context.fetch(
                FetchDescriptor<MediaAsset>(predicate: MediaQuery.asset(withID: UUID()))
            ).isEmpty
        )
    }
}

// MARK: - Les requêtes par lot d'identifiants

@MainActor
struct BatchIdentifierQueryTests {

    @Test("withIDs se traduit bien en SQL, et discrimine")
    func withIDsTranslatesToSQL() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let wanted = repository.create(name: "Voulu", in: library)
        let other = repository.create(name: "Autre", in: library)
        // `save()` avant le `fetch` : sur des objets encore en attente, SwiftData évalue
        // le prédicat en Swift et sa traduction SQL n'est jamais exercée. C'est la règle
        // de `CLAUDE.md`, et c'est ce qui avait laissé la grille des titres vide derrière
        // 42 tests verts.
        try context.save()

        let found = try context.fetch(
            FetchDescriptor<Title>(predicate: TitleQuery.withIDs([wanted.id])))
        #expect(found.map(\.name) == ["Voulu"])

        // Contrôle négatif : sans lui, un prédicat qui rendrait tout passerait aussi.
        #expect(other.id != wanted.id)
        let none = try context.fetch(
            FetchDescriptor<Title>(predicate: TitleQuery.withIDs([UUID()])))
        #expect(none.isEmpty)

        // Et un lot de plusieurs identifiants : c'est le `IN (...)` qui est en jeu.
        let both = try context.fetch(
            FetchDescriptor<Title>(predicate: TitleQuery.withIDs([wanted.id, other.id])))
        #expect(both.count == 2)
    }

    @Test("Les genres et collections par lot voient aussi la corbeille")
    func batchQueriesSeeTheTrash() throws {
        let (context, library) = try makeTestLibrary()
        let genres = GenreRepository(context: context)
        let genre = try genres.findOrCreate(name: "Policier", target: .title, in: library)
        genres.softDelete(genre)
        try context.save()

        // Délibéré : l'édition en masse doit distinguer « à la corbeille » de « n'existe
        // pas » pour rendre le bon refus. Filtrer ici rendrait les deux indiscernables.
        let found = try context.fetch(
            FetchDescriptor<Genre>(predicate: GenreQuery.withIDs([genre.id])))
        #expect(found.count == 1)
        #expect(found[0].deletedAt != nil)
    }
}
