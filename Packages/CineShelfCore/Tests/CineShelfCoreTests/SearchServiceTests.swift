import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Le service de recherche.
//
// Deux choses s'y jouent, et elles ne se recouvrent pas.
//
// **La distinction `idle` / résultats vides.** C'est le cœur du type : un champ vide
// doit montrer les recherches récentes, un champ rempli sans correspondance doit dire
// « aucun résultat ». Les confondre donne soit un écran vide inexplicable, soit le
// catalogue entier sous un champ vide — 5 000 objets, 248 ms mesurées.
//
// **La visibilité, qui n'est pas réimplémentée.** Les titres passent par
// `TitleFilter`, les personnes par `PersonFilter` : ceux de la grille et de la liste.
// Les tests qui suivent le vérifient quand même pour les quatre types, parce que la
// réutilisation ne protège que ce qu'elle couvre — les collections et les signets ont
// leurs propres prédicats, construits à la main, et c'est là que le risque est.

@MainActor
struct SearchServiceTests {

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let library: Library
        let service: SearchService
    }

    private func makeFixture() throws -> Fixture {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)
        return Fixture(
            container: container, context: context, library: library,
            service: SearchService(context: context))
    }

    @discardableResult
    private func title(
        _ name: String,
        in fixture: Fixture,
        isPrivate: Bool = false,
        isArchived: Bool = false,
        library: Library? = nil
    ) -> Title {
        let title = TitleRepository(context: fixture.context)
            .create(name: name, in: library ?? fixture.library)
        title.isPrivate = isPrivate
        title.isArchived = isArchived
        title.refreshDerived()
        return title
    }

    @discardableResult
    private func person(_ first: String, _ last: String, in fixture: Fixture) -> Person {
        PersonRepository(context: fixture.context)
            .create(firstName: first, lastName: last, in: fixture.library)
    }

    @discardableResult
    private func collection(
        _ name: String,
        in fixture: Fixture,
        isPrivate: Bool = false
    ) -> TitleCollection {
        let collection = CollectionRepository(context: fixture.context)
            .create(name: name, in: fixture.library)
        collection.isPrivate = isPrivate
        collection.refreshDerived()
        return collection
    }

    @discardableResult
    private func savedLink(
        url: String,
        name: String?,
        in fixture: Fixture,
        isPrivate: Bool = false
    ) -> SavedLink {
        let link = SavedLink(urlString: url)
        link.name = name
        link.library = fixture.library
        link.isPrivate = isPrivate
        link.refreshDerived()
        fixture.context.insert(link)
        return link
    }

    private func search(
        _ text: String,
        in fixture: Fixture,
        scope: SearchScope = .all,
        hidingPrivate: Bool = false,
        libraryID: UUID? = nil,
        limit: Int = SearchService.defaultLimitPerGroup
    ) throws -> SearchOutcome {
        try fixture.context.save()
        return try fixture.service.search(
            text, scope: scope, hidingPrivate: hidingPrivate, libraryID: libraryID,
            limitPerGroup: limit)
    }

    /// Déballe des résultats, ou échoue en disant que le service a rendu `idle`.
    private func results(_ outcome: SearchOutcome) throws -> SearchResults {
        guard case .results(let results) = outcome else {
            Issue.record("Le service a rendu `idle` alors qu'un terme était saisi")
            throw CancellationError()
        }
        return results
    }

    // MARK: idle contre résultats vides

    @Test("Un terme vide rend idle, pas zéro résultat")
    func emptyTermIsIdle() throws {
        let fixture = try makeFixture()
        title("Le Silence de la mer", in: fixture)

        guard case .idle = try search("", in: fixture) else {
            Issue.record("La chaîne vide doit rendre `idle`")
            return
        }
    }

    @Test("Un terme réduit à des espaces rend idle")
    func whitespaceOnlyIsIdle() throws {
        // Le retrait des espaces précède le test de vacuité, et pas l'inverse : sans
        // ça, « \t\n » serait traité comme une recherche, replié en chaîne vide, et
        // un `CONTAINS ''` en SQL ne matcherait aucune ligne — l'écran afficherait
        // « aucun résultat » pour un champ que l'utilisateur voit vide.
        let fixture = try makeFixture()
        title("Le Silence de la mer", in: fixture)

        for blank in ["   ", "\t", "\n", " \n\t "] {
            guard case .idle = try search(blank, in: fixture) else {
                Issue.record("« \(blank.debugDescription) » doit rendre `idle`")
                return
            }
        }
    }

    @Test("Un terme sans correspondance rend des résultats vides, pas idle")
    func noMatchIsNotIdle() throws {
        // La distinction que le type existe pour rendre impossible à confondre.
        let fixture = try makeFixture()
        title("Le Silence de la mer", in: fixture)

        let results = try results(try search("xyzzy", in: fixture))
        #expect(results.isEmpty)
        #expect(results.total == 0)
    }

    // MARK: Les trois vérifications de la fiche

    @Test("« ame » trouve « Âme »")
    func searchFoldsDiacritics() throws {
        let fixture = try makeFixture()
        title("Une Âme sœur", in: fixture)

        #expect(try results(try search("ame", in: fixture)).titles.total == 1)
        #expect(try results(try search("ÂME", in: fixture)).titles.total == 1)
        #expect(try results(try search("Ame", in: fixture)).titles.total == 1)
    }

    @Test("« downey » trouve « Robert Downey Jr. »")
    func searchFindsPeopleByLastName() throws {
        let fixture = try makeFixture()
        person("Robert", "Downey Jr.", in: fixture)
        person("Ana", "Novak", in: fixture)

        let results = try results(try search("downey", in: fixture))
        #expect(results.people.items.map(\.displayName) == ["Robert Downey Jr."])
    }

    @Test("La chaîne vide ne renvoie pas zéro résultat par accident")
    func emptyStringIsNotAFailedQuery() throws {
        // Non-régression de `e0f0f0b`. `String.contains("")` est vrai en Swift mais
        // `CONTAINS ''` ne matche aucune ligne en SQL : une implémentation naïve
        // rendrait donc `.results` avec zéro correspondance, ce qui est **faux** — le
        // service doit rendre `idle`, et l'écran des recherches récentes.
        let fixture = try makeFixture()
        title("Premier", in: fixture)
        title("Deuxième", in: fixture)

        guard case .idle = try search("", in: fixture) else {
            Issue.record("Le contrat est `idle`, pas des résultats vides")
            return
        }
    }

    // MARK: Portées

    @Test("Chaque portée n'interroge que son type")
    func scopesRestrictTheQuery() throws {
        let fixture = try makeFixture()
        title("Cinéma vérité", in: fixture)
        person("Vera", "Cinéma", in: fixture)
        collection("Cinéma muet", in: fixture)
        savedLink(url: "https://cinema.example", name: "Cinéma en ligne", in: fixture)

        let all = try results(try search("cinema", in: fixture))
        #expect(all.titles.total == 1)
        #expect(all.people.total == 1)
        #expect(all.collections.total == 1)
        #expect(all.savedLinks.total == 1)
        #expect(all.total == 4)

        let onlyTitles = try results(try search("cinema", in: fixture, scope: .titles))
        #expect(onlyTitles.titles.total == 1)
        #expect(onlyTitles.people.total == 0)
        #expect(onlyTitles.collections.total == 0)
        #expect(onlyTitles.savedLinks.total == 0)
        #expect(onlyTitles.total == 1)
    }

    @Test("Un signet se trouve par son URL, pas seulement par son nom")
    func savedLinksMatchTheirURL() throws {
        // `SavedLink.searchText` agrège nom, notes **et** URL. C'est le comportement
        // attendu d'un gestionnaire de signets, et rien d'autre ne le vérifie.
        let fixture = try makeFixture()
        savedLink(url: "https://www.imdb.com/title/tt0111161", name: "Un film", in: fixture)

        #expect(try results(try search("imdb", in: fixture)).savedLinks.total == 1)
    }

    // MARK: Groupes, comptes et tranches

    @Test("Un groupe porte son compte complet, pas celui de sa tranche")
    func groupsCarryTheirTotal() throws {
        // Le compte vient d'un `fetchCount`, qui ne matérialise aucun objet : c'est ce
        // qui permet d'écrire « 12 titres » sous une liste qui n'en montre que trois.
        let fixture = try makeFixture()
        for index in 0..<12 { title("Épisode \(index)", in: fixture) }

        let results = try results(try search("episode", in: fixture, limit: 3))
        #expect(results.titles.items.count == 3)
        #expect(results.titles.total == 12)
        #expect(results.titles.isTruncated)
        #expect(results.titles.isEmpty == false)
    }

    @Test("Un groupe non tronqué le dit")
    func groupsReportWhenComplete() throws {
        let fixture = try makeFixture()
        title("Unique", in: fixture)

        let results = try results(try search("unique", in: fixture, limit: 10))
        #expect(results.titles.total == 1)
        #expect(results.titles.isTruncated == false)
    }

    // MARK: Visibilité — les quatre types

    @Test("La corbeille, l'archivage et le privé sont masqués partout")
    func visibilityAppliesToEveryType() throws {
        let fixture = try makeFixture()

        let trashedTitle = title("Zephyr titre", in: fixture)
        trashedTitle.deletedAt = .now
        title("Zephyr archivé", in: fixture, isArchived: true)
        title("Zephyr privé", in: fixture, isPrivate: true)
        title("Zephyr visible", in: fixture)

        let trashedCollection = collection("Zephyr collection", in: fixture)
        trashedCollection.deletedAt = .now
        collection("Zephyr collection privée", in: fixture, isPrivate: true)
        collection("Zephyr collection visible", in: fixture)

        savedLink(url: "https://a.example", name: "Zephyr signet privé", in: fixture, isPrivate: true)
        savedLink(url: "https://b.example", name: "Zephyr signet visible", in: fixture)

        let results = try results(try search("zephyr", in: fixture, hidingPrivate: true))
        #expect(results.titles.items.map(\.name) == ["Zephyr visible"])
        #expect(results.collections.items.map(\.name) == ["Zephyr collection visible"])
        #expect(results.savedLinks.items.map { $0.name ?? "" } == ["Zephyr signet visible"])
    }

    @Test("Un profil qui ne masque pas le privé le voit")
    func privateContentFollowsTheProfile() throws {
        let fixture = try makeFixture()
        title("Zephyr privé", in: fixture, isPrivate: true)
        collection("Zephyr collection privée", in: fixture, isPrivate: true)

        let hidden = try results(try search("zephyr", in: fixture, hidingPrivate: true))
        #expect(hidden.total == 0)

        let shown = try results(try search("zephyr", in: fixture, hidingPrivate: false))
        #expect(shown.titles.total == 1)
        #expect(shown.collections.total == 1)
    }

    @Test("La bibliothèque restreint les quatre types")
    func libraryScopesEveryType() throws {
        let fixture = try makeFixture()
        let elsewhere = Library(name: "Ailleurs")
        fixture.context.insert(elsewhere)

        title("Zephyr ici", in: fixture)
        title("Zephyr ailleurs", in: fixture, library: elsewhere)

        let mine = collection("Zephyr collection ici", in: fixture)
        let other = CollectionRepository(context: fixture.context)
            .create(name: "Zephyr collection ailleurs", in: elsewhere)
        _ = (mine, other)

        savedLink(url: "https://ici.example", name: "Zephyr signet ici", in: fixture)
        let away = SavedLink(urlString: "https://ailleurs.example")
        away.name = "Zephyr signet ailleurs"
        away.library = elsewhere
        away.refreshDerived()
        fixture.context.insert(away)

        let scoped = try results(
            try search("zephyr", in: fixture, libraryID: fixture.library.id))
        #expect(scoped.titles.items.map(\.name) == ["Zephyr ici"])
        #expect(scoped.collections.items.map(\.name) == ["Zephyr collection ici"])
        #expect(scoped.savedLinks.items.map { $0.name ?? "" } == ["Zephyr signet ici"])

        // Sans portée, tout sort : c'est le cas « aucun profil ouvert ».
        let everywhere = try results(try search("zephyr", in: fixture, libraryID: nil))
        #expect(everywhere.titles.total == 2)
        #expect(everywhere.collections.total == 2)
        #expect(everywhere.savedLinks.total == 2)
    }

    @Test("Les prédicats de collection et de signet sont bien traduits en SQL")
    func manualPredicatesAreEvaluatedByTheStore() throws {
        // Les deux seuls prédicats neufs de `L2`, et les deux construits à la main.
        // Un `ModelContext` neuf n'a aucun objet en attente : le fetch passe donc
        // forcément par SQLite. Si une clause ne se traduisait pas, il lèverait — et
        // si elle se traduisait de travers, le compte serait faux.
        let fixture = try makeFixture()
        collection("Zephyr gardée", in: fixture)
        collection("Autre", in: fixture)
        savedLink(url: "https://z.example", name: "Zephyr gardé", in: fixture)
        savedLink(url: "https://a.example", name: "Autre", in: fixture)
        try fixture.context.save()

        let fresh = ModelContext(fixture.container)
        let collections = try fresh.fetch(
            FetchDescriptor<TitleCollection>(
                predicate: CollectionQuery.matching(
                    term: "zephyr", hidingPrivate: true, libraryID: fixture.library.id))
        )
        let links = try fresh.fetch(
            FetchDescriptor<SavedLink>(
                predicate: SavedLinkQuery.matching(
                    term: "zephyr", hidingPrivate: true, libraryID: fixture.library.id))
        )

        #expect(collections.map(\.name) == ["Zephyr gardée"])
        #expect(links.count == 1)
    }
}
