import CineShelfCore
import Foundation
import SwiftData
import Testing

// Les **critères** du filtre des titres : ce que chacun retient et ce qu'il exclut.
//
// Depuis `L1`, tout est porté par un prédicat SwiftData ; plus rien n'est filtré en
// mémoire. Le risque n'est donc plus qu'un critère tombe entre deux mécanismes,
// c'est qu'une clause se traduise mal en SQL. Chaque test passe par `save()` puis
// `fetch` (voir `TitleFilterFixture`) : sur du pending, SwiftData évalue en Swift et
// la traduction SQL n'est jamais exercée.
//
// La *forme* du prédicat — neutralisation, conjonction, traduction — est couverte
// par `TitlePredicateTests`. Le maintien des clés dérivées, par `FilterKeyTests`.

@MainActor
struct TitleFilterTests {

    private typealias Fixture = TitleFilterFixture

    // MARK: Visibilité

    @Test("Un titre à la corbeille n'apparaît jamais")
    func deletedTitlesAreHidden() throws {
        let context = try Fixture.makeContext()
        let title = Fixture.makeTitle(in: context)
        title.deletedAt = .now

        #expect(try Fixture.results(TitleFilter(), in: context).isEmpty)
    }

    @Test("Les archivés n'apparaissent que si on le demande")
    func archivedTitlesNeedTheToggle() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Archivé", isArchived: true)

        #expect(try Fixture.results(TitleFilter(), in: context).isEmpty)

        var filter = TitleFilter()
        filter.showsArchived = true
        #expect(try Fixture.results(filter, in: context).count == 1)
    }

    @Test("Un profil qui masque le contenu privé ne le voit pas")
    func privateTitlesFollowTheProfile() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Privé", isPrivate: true)

        #expect(try Fixture.results(TitleFilter(), in: context, hidingPrivate: true).isEmpty)
        #expect(try Fixture.results(TitleFilter(), in: context, hidingPrivate: false).count == 1)
    }

    // MARK: Recherche

    @Test("La recherche porte sur le texte dérivé")
    func searchUsesDerivedText() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Le Silence de la mer")
        Fixture.makeTitle(in: context, name: "Nuit et brouillard")

        var filter = TitleFilter()
        filter.searchText = "silence"
        #expect(try Fixture.results(filter, in: context).count == 1)

        // Une recherche vide ne doit rien exclure.
        filter.searchText = "   "
        #expect(try Fixture.results(filter, in: context).count == 2)
    }

    @Test("La recherche ignore les accents et la casse")
    func searchFoldsDiacriticsAndCase() throws {
        // `searchText` est replié à l'écriture, le terme cherché doit l'être à la
        // lecture. Si l'un des deux repliages disparaît, « ame » cesse de trouver
        // « Âme » et personne ne s'en aperçoit avant de taper un accent.
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Une Âme sœur")

        var filter = TitleFilter()
        filter.searchText = "ame"
        #expect(try Fixture.results(filter, in: context).count == 1)

        filter.searchText = "ÂME"
        #expect(try Fixture.results(filter, in: context).count == 1)
    }

    @Test("Une recherche vide laisse passer tous les titres")
    func emptySearchKeepsEverything() throws {
        // Non-régression. `String.contains("")` est vrai en Swift, mais le prédicat
        // finit en SQL et `CONTAINS ''` n'y matche aucune ligne : la clause de
        // recherche a vidé la grille en permanence. Le test ne vaut que parce que
        // `results(_:in:)` sauvegarde avant de fetcher.
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Premier")
        Fixture.makeTitle(in: context, name: "Deuxième")
        Fixture.makeTitle(in: context, name: "Troisième")

        #expect(try Fixture.results(TitleFilter(), in: context).count == 3)

        // Explicitement vide, et espaces seuls : les deux passent par le même repli
        // que la chaîne par défaut.
        var filter = TitleFilter()
        filter.searchText = ""
        #expect(try Fixture.results(filter, in: context).count == 3)
        filter.searchText = "  \n "
        #expect(try Fixture.results(filter, in: context).count == 3)
    }

    // MARK: Relations

    @Test("Le filtre par collection s'applique")
    func collectionFilterIsApplied() throws {
        let context = try Fixture.makeContext()
        let saga = TitleCollection(name: "Une saga")
        context.insert(saga)

        let inside = Fixture.makeTitle(in: context, name: "Dans la saga")
        inside.collection = saga
        inside.refreshDerived()
        Fixture.makeTitle(in: context, name: "Hors saga")

        var filter = TitleFilter()
        filter.collectionID = saga.id
        let found = try Fixture.results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Dans la saga")

        // Une collection inconnue exclut tout, y compris les titres sans collection.
        filter.collectionID = UUID()
        #expect(try Fixture.results(filter, in: context).isEmpty)
    }

    @Test("Le filtre par genre s'applique")
    func genreFilterIsApplied() throws {
        let context = try Fixture.makeContext()
        let library = Library()
        context.insert(library)

        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Policier", target: .title, in: library)

        let tagged = Fixture.makeTitle(in: context, name: "Avec genre")
        tagged.genres = [genre]
        tagged.refreshDerived()
        Fixture.makeTitle(in: context, name: "Sans genre")

        var filter = TitleFilter()
        filter.genreID = genre.id
        let found = try Fixture.results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Avec genre")
    }

    @Test("Le filtre par personne passe par les crédits")
    func personFilterWalksCredits() throws {
        let context = try Fixture.makeContext()
        let person = Person(firstName: "Ana", lastName: "Novak")
        person.refreshDerived()
        context.insert(person)

        let credited = Fixture.makeTitle(in: context, name: "Avec Ana")
        let credit = Credit()
        credit.person = person
        credit.title = credited
        context.insert(credit)
        credited.refreshDerived()

        Fixture.makeTitle(in: context, name: "Sans Ana")

        var filter = TitleFilter()
        filter.personID = person.id
        let found = try Fixture.results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Avec Ana")
    }

    // MARK: Bornes

    @Test("Les bornes de durée excluent aussi les titres sans durée")
    func runtimeBoundsExcludeTitlesWithoutRuntime() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Court", runtime: 80)
        Fixture.makeTitle(in: context, name: "Long", runtime: 150)
        Fixture.makeTitle(in: context, name: "Série", runtime: nil)

        var filter = TitleFilter()
        filter.minimumRuntime = 100
        let found = try Fixture.results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Long")
    }

    @Test("Une borne supérieure seule exclut aussi les titres sans durée")
    func maximumRuntimeAloneExcludesUnknownRuntime() throws {
        // La sentinelle diffère selon le sens de la borne : `Int.min` pour la borne
        // basse, `Int.max` pour la haute. Se tromper de sentinelle sur la borne haute
        // ferait passer les durées inconnues, et ce cas est le seul qui le montre —
        // avec les deux bornes posées, l'autre clause rattrape.
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Court", runtime: 80)
        Fixture.makeTitle(in: context, name: "Série", runtime: nil)

        var filter = TitleFilter()
        filter.maximumRuntime = 100
        #expect(try Fixture.results(filter, in: context).map(\.name) == ["Court"])
    }

    @Test("Les tranches pré-réglées l'emportent sur les bornes libres")
    func bandsOverrideFreeBounds() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Court", runtime: 80)
        Fixture.makeTitle(in: context, name: "Moyen", runtime: 100)
        Fixture.makeTitle(in: context, name: "Long", runtime: 150)

        var filter = TitleFilter()
        filter.minimumRuntime = 1
        filter.maximumRuntime = 10_000
        filter.runtimeBand = .short

        let found = try Fixture.results(filter, in: context)
        #expect(found.count == 1)
        #expect(found.first?.name == "Court")
    }

    @Test("Les bornes de note excluent les titres non notés")
    func ratingBoundsExcludeUnratedTitles() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Bon", rating: 8)
        Fixture.makeTitle(in: context, name: "Moyen", rating: 5)
        Fixture.makeTitle(in: context, name: "Non noté", rating: nil)

        var filter = TitleFilter()
        filter.minimumRating = 7
        let found = try Fixture.results(filter, in: context)

        #expect(found.count == 1)
        #expect(found.first?.name == "Bon")
    }

    @Test("Une borne de note supérieure seule exclut les non notés")
    func maximumRatingAloneExcludesUnrated() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Moyen", rating: 5)
        Fixture.makeTitle(in: context, name: "Non noté", rating: nil)

        var filter = TitleFilter()
        filter.maximumRating = 6
        #expect(try Fixture.results(filter, in: context).map(\.name) == ["Moyen"])
    }

    // MARK: Tri

    @Test("Le tri par durée respecte le sens demandé")
    func sortingFollowsDirection() throws {
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Court", runtime: 80)
        Fixture.makeTitle(in: context, name: "Long", runtime: 150)

        var filter = TitleFilter()
        filter.sort = .runtime
        filter.ascending = true
        #expect(try Fixture.results(filter, in: context).first?.name == "Court")

        filter.ascending = false
        #expect(try Fixture.results(filter, in: context).first?.name == "Long")
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
