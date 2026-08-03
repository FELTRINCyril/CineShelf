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
    private func results(
        _ filter: TitleFilter, in context: ModelContext, hidingPrivate: Bool = false
    ) throws -> [Title] {
        let descriptor = FetchDescriptor<Title>(
            predicate: filter.predicate(hidingPrivate: hidingPrivate),
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
