import CineShelfCore
import Foundation
import SwiftData
import Testing

// `DemoCatalog` contourne délibérément les repositories — c'est une fixture, pas
// une action de l'utilisateur, et on ne veut pas trois cents `ActivityEntry`
// fictives dans le fil d'activité.
//
// Ce contournement est acceptable pour l'`ActivityRecorder`. Il ne l'est pas
// pour `refreshDerived()` : `sortName` et `searchText` remplacent les colonnes
// générées et l'index FTS que CloudKit interdit. Une entité dont ils sont vides
// est invisible à la recherche et mal triée, **sans que rien ne le signale**.
//
// D'où ces tests : ils rendent l'invariant vérifiable pour le seul endroit du
// dépôt qui écrit sans passer par un repository.

@MainActor
struct DemoCatalogTests {

    private func makeFixture() throws -> (context: ModelContext, library: Library) {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let library = Library()
        context.insert(library)
        return (context, library)
    }

    /// Volume réduit : l'invariant ne dépend pas du nombre, et chaque titre fait
    /// dessiner puis encoder un PNG de 600 × 900.
    private let count = 12

    // MARK: L'invariant

    @Test("Aucun titre de démonstration n'a de champ dérivé vide")
    func everyDemoTitleHasItsDerivedFields() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        let titles = try context.fetch(FetchDescriptor<Title>())
        #expect(titles.count == count)

        for title in titles {
            #expect(!title.sortName.isEmpty, "sortName vide sur « \(title.name) »")
            #expect(!title.searchText.isEmpty, "searchText vide sur « \(title.name) »")
        }
    }

    @Test("Aucune personne de démonstration n'a de champ dérivé vide")
    func everyDemoPersonHasItsDerivedFields() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        let people = try context.fetch(FetchDescriptor<Person>())
        #expect(!people.isEmpty)

        for person in people {
            #expect(!person.displayName.isEmpty, "displayName vide")
            #expect(!person.sortName.isEmpty, "sortName vide sur « \(person.displayName) »")
            #expect(!person.searchText.isEmpty, "searchText vide sur « \(person.displayName) »")
        }
    }

    @Test("Aucune collection de démonstration n'a de champ dérivé vide")
    func everyDemoCollectionHasItsDerivedFields() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        let collections = try context.fetch(FetchDescriptor<TitleCollection>())
        #expect(!collections.isEmpty)

        for collection in collections {
            #expect(!collection.sortName.isEmpty, "sortName vide sur « \(collection.name) »")
            #expect(!collection.searchText.isEmpty, "searchText vide sur « \(collection.name) »")
        }
    }

    @Test("Le marqueur est retrouvable par sa clé repliée, pas seulement par son nom")
    func markerIsFoundThroughItsFoldedKey() throws {
        let (context, library) = try makeFixture()

        // Un genre homonyme non accentué existe déjà : `findOrCreate` le
        // réutilisera comme marqueur, puisqu'ils ont la même clé repliée. Si le
        // vidage cherchait sur `name`, il ne le retrouverait plus — et les
        // titres de démonstration deviendraient non supprimables.
        let existing = try GenreRepository(context: context)
            .findOrCreate(name: "demonstration", target: .title, in: library)
        try context.save()

        try DemoCatalog.populate(in: context, library: library, count: count)
        #expect(DemoCatalog.isPopulated(in: context, library: library))

        // Le genre existant a servi de marqueur : le vidage doit l'avoir
        // retrouvé, donc emporté, et les titres avec lui.
        try DemoCatalog.clear(in: context, library: library)

        #expect(try context.fetch(FetchDescriptor<Title>()).isEmpty)
        #expect(DemoCatalog.isPopulated(in: context, library: library) == false)
        #expect(
            try context.fetch(FetchDescriptor<Genre>()).contains { $0.id == existing.id } == false,
            "Le marqueur n'a pas été retrouvé : le vidage aurait été un no-op silencieux"
        )
    }

    /// Contrôle négatif : sans lui, les tests ci-dessus passeraient tout aussi
    /// bien si les champs dérivés étaient renseignés par un autre chemin.
    ///
    /// Ce qui est vérifié, c'est qu'une mutation **postérieure à l'init** laisse
    /// les dérivés périmés tant que `refreshDerived()` n'est pas rappelé —
    /// exactement le cas de `bio` et `summary` dans `DemoCatalog`.
    @Test("Une mutation après l'init laisse les champs dérivés périmés")
    func theInvariantIsWorthTesting() {
        let title = Title(name: "Le Silence de la mer")
        #expect(!title.searchText.isEmpty, "L'init appelle déjà refreshDerived")

        title.summary = "Un officier allemand loge chez un vieil homme et sa nièce."
        #expect(!title.searchText.contains("officier"), "Le dérivé est périmé, c'est le point")

        title.refreshDerived()
        #expect(title.searchText.contains("officier"))
    }

    // MARK: Le champ dérivé qui dépend d'une mutation tardive

    @Test("Le marqueur de démonstration est bien dans le texte de recherche")
    func demoMarkerReachesTheSearchText() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        // `bio` et `summary` sont posés *après* l'init, qui a déjà appelé
        // `refreshDerived()` : si l'appel n'était pas refait ensuite, le
        // marqueur manquerait au `searchText`. C'est le cas d'ordre le plus
        // facile à casser par un refactoring innocent.
        let marker = DemoCatalog.marker.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let people = try context.fetch(FetchDescriptor<Person>())
        for person in people {
            #expect(person.searchText.contains(marker), "marqueur absent de « \(person.displayName) »")
        }

        let collections = try context.fetch(FetchDescriptor<TitleCollection>())
        for collection in collections {
            #expect(collection.searchText.contains(marker), "marqueur absent de « \(collection.name) »")
        }
    }

    // MARK: Suppression

    @Test("Vider le catalogue emporte les titres et tout ce qui n'appartient qu'à eux")
    func clearingRemovesEverythingItOwns() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)
        #expect(DemoCatalog.isPopulated(in: context, library: library))

        try DemoCatalog.clear(in: context, library: library)

        #expect(try context.fetch(FetchDescriptor<Title>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TitleCollection>()).isEmpty)
        // Les jaquettes et leurs rattachements partent avec les titres : sans
        // ces deux assertions, une boucle cassée laisserait des mégaoctets
        // d'images orphelines sans qu'aucun test ne bronche.
        #expect(try context.fetch(FetchDescriptor<MediaAsset>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MediaAttachment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Credit>()).isEmpty)
        #expect(DemoCatalog.isPopulated(in: context, library: library) == false)
    }

    /// Les dix genres thématiques survivent — c'est documenté et voulu : ils
    /// viennent de `findOrCreate`, qui réutilise un genre réel homonyme, et
    /// rien ne permet de distinguer les deux cas.
    @Test("Vider le catalogue retire le marqueur mais garde les genres thématiques")
    func clearingRemovesOnlyTheMarkerGenre() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        try DemoCatalog.clear(in: context, library: library)

        let genres = try context.fetch(FetchDescriptor<Genre>())
        #expect(!genres.contains { $0.name == DemoCatalog.markerGenreName })
        #expect(!genres.isEmpty, "Les genres thématiques doivent survivre")
    }

    @Test("Vider le catalogue épargne les données réelles")
    func clearingSparesRealData() throws {
        let (context, library) = try makeFixture()

        // Une personne réelle sans filmographie et une collection réelle vide :
        // exactement ce qu'une heuristique « supprimer les orphelins » emportait.
        let person = Person(firstName: "Chantal", lastName: "Akerman")
        person.library = library
        person.refreshDerived()
        context.insert(person)

        let collection = TitleCollection(name: "À voir en salle")
        collection.library = library
        collection.refreshDerived()
        context.insert(collection)

        try DemoCatalog.populate(in: context, library: library, count: count)
        try DemoCatalog.clear(in: context, library: library)

        let survivors = try context.fetch(FetchDescriptor<Person>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.displayName == "Chantal Akerman")

        let remainingCollections = try context.fetch(FetchDescriptor<TitleCollection>())
        #expect(remainingCollections.count == 1)
        #expect(remainingCollections.first?.name == "À voir en salle")
    }
}
