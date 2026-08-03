import CineShelfCore
import Foundation
import SwiftData
import Testing

// Le filtre des titres est réparti sur deux mécanismes : un `#Predicate`
// SwiftData pour ce qui réduit le nombre de lignes lues, et `matches(_:)` en
// mémoire pour le reste. Cette répartition est une contrainte du compilateur,
// pas un choix — au-delà de cinq ou six clauses `&&`, `#Predicate` ne se
// type-check plus.
//
// Le risque est donc précis : qu'un critère tombe entre les deux et ne soit
// appliqué nulle part. Ces tests vérifient que **chaque** critère filtre
// vraiment, quel que soit le mécanisme qui le porte.

@MainActor
struct TitleFilterTests {

    /// Magasin en mémoire : aucune trace sur disque, aucun CloudKit.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func makeTitle(
        in context: ModelContext,
        name: String = "Un titre",
        runtime: Int? = 100,
        rating: Double? = 7,
        isArchived: Bool = false,
        isPrivate: Bool = false
    ) -> Title {
        let title = Title(name: name)
        title.runtimeMinutes = runtime
        title.rating = rating
        title.isArchived = isArchived
        title.isPrivate = isPrivate
        title.refreshDerived()
        context.insert(title)
        return title
    }

    /// Applique le filtre comme le fait `TitlesGrid` : prédicat puis `matches`.
    ///
    /// Le `save()` n'est pas une précaution, c'est ce qui rend le test valable.
    /// Sur des objets encore en attente, SwiftData évalue le `#Predicate` en
    /// mémoire, côté Swift ; sa traduction SQL n'est jamais exercée. C'est
    /// comme ça qu'un `contains("")` — vrai en Swift, sans correspondance en
    /// SQL — a vidé la grille pendant que ces tests restaient verts.
    private func results(
        _ filter: TitleFilter,
        in context: ModelContext,
        hidingPrivate: Bool = false,
        libraryID: UUID? = nil
    ) throws -> [Title] {
        try context.save()

        let descriptor = FetchDescriptor<Title>(
            predicate: filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID),
            sortBy: filter.descriptors
        )
        return try context.fetch(descriptor).filter(filter.matches)
    }

    // MARK: Visibilité

    @Test("Un titre à la corbeille n'apparaît jamais")
    func deletedTitlesAreHidden() throws {
        let context = try makeContext()
        let title = makeTitle(in: context)
        title.deletedAt = .now

        #expect(try results(TitleFilter(), in: context).isEmpty)
    }

    @Test("Les archivés n'apparaissent que si on le demande")
    func archivedTitlesNeedTheToggle() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Archivé", isArchived: true)

        #expect(try results(TitleFilter(), in: context).isEmpty)

        var filter = TitleFilter()
        filter.showsArchived = true
        #expect(try results(filter, in: context).count == 1)
    }

    @Test("Un profil qui masque le contenu privé ne le voit pas")
    func privateTitlesFollowTheProfile() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Privé", isPrivate: true)

        #expect(try results(TitleFilter(), in: context, hidingPrivate: true).isEmpty)
        #expect(try results(TitleFilter(), in: context, hidingPrivate: false).count == 1)
    }

    // MARK: Critères

    @Test("La recherche porte sur le texte dérivé")
    func searchUsesDerivedText() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Le Silence de la mer")
        makeTitle(in: context, name: "Nuit et brouillard")

        var filter = TitleFilter()
        filter.searchText = "silence"
        #expect(try results(filter, in: context).count == 1)

        // Une recherche vide ne doit rien exclure.
        filter.searchText = "   "
        #expect(try results(filter, in: context).count == 2)
    }

    @Test("Une recherche vide laisse passer tous les titres")
    func emptySearchKeepsEverything() throws {
        // Non-régression. `String.contains("")` est vrai en Swift, mais un
        // `#Predicate` finit en SQL et `CONTAINS ''` n'y matche aucune ligne :
        // la clause de recherche a vidé la grille en permanence. Le test ne vaut
        // que parce que `results(_:in:)` sauvegarde avant de fetcher — sans
        // `save()`, le prédicat serait évalué en mémoire et resterait vert.
        let context = try makeContext()
        makeTitle(in: context, name: "Premier")
        makeTitle(in: context, name: "Deuxième")
        makeTitle(in: context, name: "Troisième")

        #expect(try results(TitleFilter(), in: context).count == 3)

        // Explicitement vide, et espaces seuls : les deux passent par le même
        // repli que la chaîne par défaut.
        var filter = TitleFilter()
        filter.searchText = ""
        #expect(try results(filter, in: context).count == 3)
        filter.searchText = "  \n "
        #expect(try results(filter, in: context).count == 3)
    }

    @Test("Les deux prédicats appliquent les mêmes clauses de visibilité")
    func bothPredicatesShareTheirVisibilityClauses() throws {
        // `predicate(hidingPrivate:libraryID:)` émet DEUX littéraux `#Predicate`
        // — un par branche du `guard search.isEmpty`. Tous les autres tests
        // laissent la recherche vide, donc sans celui-ci la seconde branche n'est
        // exercée par rien : retirer `deletedAt`, `isArchived`, `isPrivate` ou la
        // bibliothèque de ce littéral laisserait la suite entièrement verte.
        // Mesuré. La duplication assumée des deux littéraux rend cet oubli
        // probable, c'est donc ici qu'il se rattrape.
        let context = try makeContext()
        let mine = Library(name: "La mienne")
        let other = Library(name: "L'autre")
        context.insert(mine)
        context.insert(other)

        // « zzz » est dans le nom de tous les titres, donc dans leur `searchText`
        // replié : la clause de recherche les laisse tous passer, et seules les
        // clauses de visibilité peuvent encore les écarter.
        let visible = makeTitle(in: context, name: "zzz visible")
        visible.library = mine

        let trashed = makeTitle(in: context, name: "zzz corbeille")
        trashed.library = mine
        trashed.deletedAt = .now

        let archived = makeTitle(in: context, name: "zzz archivé", isArchived: true)
        archived.library = mine

        let hidden = makeTitle(in: context, name: "zzz privé", isPrivate: true)
        hidden.library = mine

        let elsewhere = makeTitle(in: context, name: "zzz ailleurs")
        elsewhere.library = other

        var filter = TitleFilter()
        filter.searchText = "zzz"
        let withSearch = try results(filter, in: context, hidingPrivate: true, libraryID: mine.id)
        let withoutSearch = try results(
            TitleFilter(), in: context, hidingPrivate: true, libraryID: mine.id
        )

        #expect(withSearch.map(\.name) == ["zzz visible"])
        // La parité est le cœur du test : un terme qui matche tout ne doit rien
        // changer au résultat.
        #expect(withSearch.map(\.id) == withoutSearch.map(\.id))
    }

    @Test("La bibliothèque filtre, et le fait côté SQL")
    func libraryClauseDiscriminates() throws {
        // La seule traversée de relation optionnelle restée dans le prédicat.
        // C'est la construction la plus fragile à traduire en SQL de tout le
        // filtre, et elle porte désormais toute la grille : si elle se traduit
        // mal, la grille se vide pour tout le monde.
        let context = try makeContext()
        let mine = Library(name: "La mienne")
        let other = Library(name: "L'autre")
        context.insert(mine)
        context.insert(other)

        let kept = makeTitle(in: context, name: "Chez moi")
        kept.library = mine
        let excluded = makeTitle(in: context, name: "Ailleurs")
        excluded.library = other
        let orphan = makeTitle(in: context, name: "Sans bibliothèque")
        orphan.library = nil

        let found = try results(TitleFilter(), in: context, libraryID: mine.id)
        #expect(found.count == 1)
        #expect(found.first?.name == "Chez moi")

        // `nil` ne filtre pas : le sélecteur de profil n'a pas encore tranché.
        #expect(try results(TitleFilter(), in: context, libraryID: nil).count == 3)

        // Contrôle négatif : une bibliothèque inconnue ne rend rien. Sans lui,
        // une clause toujours vraie passerait le premier cas.
        #expect(try results(TitleFilter(), in: context, libraryID: UUID()).isEmpty)
    }

    @Test("Le filtre par collection s'applique, même hors du prédicat")
    func collectionFilterIsApplied() throws {
        // Déplacé dans `matches(_:)` quand la bibliothèque a pris sa place dans
        // le prédicat : ce test vérifie que le critère n'est pas tombé entre les
        // deux mécanismes.
        let context = try makeContext()
        let saga = TitleCollection(name: "Une saga")
        context.insert(saga)

        let inside = makeTitle(in: context, name: "Dans la saga")
        inside.collection = saga
        makeTitle(in: context, name: "Hors saga")

        var filter = TitleFilter()
        filter.collectionID = saga.id
        let found = try results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Dans la saga")

        // Une collection inconnue exclut tout, y compris les titres sans
        // collection.
        filter.collectionID = UUID()
        #expect(try results(filter, in: context).isEmpty)
    }

    @Test("Les bornes de durée excluent aussi les titres sans durée")
    func runtimeBoundsExcludeTitlesWithoutRuntime() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Court", runtime: 80)
        makeTitle(in: context, name: "Long", runtime: 150)
        makeTitle(in: context, name: "Série", runtime: nil)

        var filter = TitleFilter()
        filter.minimumRuntime = 100
        let found = try results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Long")
    }

    @Test("Les tranches pré-réglées l'emportent sur les bornes libres")
    func bandsOverrideFreeBounds() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Court", runtime: 80)
        makeTitle(in: context, name: "Moyen", runtime: 100)
        makeTitle(in: context, name: "Long", runtime: 150)

        var filter = TitleFilter()
        filter.minimumRuntime = 1
        filter.maximumRuntime = 10_000
        filter.runtimeBand = .short

        let found = try results(filter, in: context)
        #expect(found.count == 1)
        #expect(found.first?.name == "Court")
    }

    @Test("Les bornes de note excluent les titres non notés")
    func ratingBoundsExcludeUnratedTitles() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Bon", rating: 8)
        makeTitle(in: context, name: "Moyen", rating: 5)
        makeTitle(in: context, name: "Non noté", rating: nil)

        var filter = TitleFilter()
        filter.minimumRating = 7
        let found = try results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Bon")
    }

    @Test("Le filtre par genre s'applique bien, même hors du prédicat")
    func genreFilterIsApplied() throws {
        let context = try makeContext()
        let library = Library()
        context.insert(library)

        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Policier", target: .title, in: library)

        let tagged = makeTitle(in: context, name: "Avec genre")
        tagged.genres = [genre]
        makeTitle(in: context, name: "Sans genre")

        var filter = TitleFilter()
        filter.genreID = genre.id
        let found = try results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Avec genre")
    }

    @Test("Le filtre par personne traverse les crédits")
    func personFilterWalksCredits() throws {
        let context = try makeContext()
        let person = Person(firstName: "Ana", lastName: "Novak")
        person.refreshDerived()
        context.insert(person)

        let credited = makeTitle(in: context, name: "Avec Ana")
        let credit = Credit()
        credit.person = person
        credit.title = credited
        context.insert(credit)

        makeTitle(in: context, name: "Sans Ana")

        var filter = TitleFilter()
        filter.personID = person.id
        let found = try results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Avec Ana")
    }

    // MARK: Tri

    @Test("Le tri par durée respecte le sens demandé")
    func sortingFollowsDirection() throws {
        let context = try makeContext()
        makeTitle(in: context, name: "Court", runtime: 80)
        makeTitle(in: context, name: "Long", runtime: 150)

        var filter = TitleFilter()
        filter.sort = .runtime
        filter.ascending = true
        #expect(try results(filter, in: context).first?.name == "Court")

        filter.ascending = false
        #expect(try results(filter, in: context).first?.name == "Long")
    }

    // MARK: État

    @Test("isActive ignore le tri")
    func sortingIsNotAFilter() {
        var filter = TitleFilter()
        #expect(filter.isActive == false)

        filter.sort = .rating
        filter.ascending = true
        #expect(filter.isActive == false, "Trier ne cache rien")

        filter.minimumRating = 6
        #expect(filter.isActive)
    }

    @Test("Effacer garde le tri en place")
    func clearingKeepsTheSort() {
        var filter = TitleFilter()
        filter.sort = .name
        filter.ascending = true
        filter.minimumRating = 6

        filter.clear()

        #expect(filter.isActive == false)
        #expect(filter.sort == .name)
        #expect(filter.ascending)
    }

    @Test("Le filtre traverse un redémarrage")
    func filterIsRestored() {
        let defaults = UserDefaults(suiteName: "filter.tests.\(UUID().uuidString)") ?? .standard
        let profileID = UUID()

        let saved = NavigationModel()
        saved.titleFilter.runtimeBand = .long
        saved.titleFilter.sort = .rating
        saved.save(profileID: profileID, to: defaults)

        let restored = NavigationModel()
        restored.restore(profileID: profileID, from: defaults)

        #expect(restored.titleFilter.runtimeBand == .long)
        #expect(restored.titleFilter.sort == .rating)
    }
}
