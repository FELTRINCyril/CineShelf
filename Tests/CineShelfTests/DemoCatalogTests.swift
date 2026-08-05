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

            // `filterKeys` porte les relations, et `DemoCatalog` les pose à la
            // main — il n'utilise volontairement pas les repositories (décision
            // actée). C'est donc ici, et nulle part ailleurs, que se vérifie que
            // son `refreshDerived()` final intervient bien **après** la
            // bibliothèque, les genres, la collection et le casting. L'ordre
            // inversé rendrait tout le catalogue de démonstration invisible dans
            // sa propre grille, sans casser un seul autre test.
            #expect(
                title.filterKeys.contains(FilterKey.pattern(FilterKey.library(library.id))),
                "Clé de bibliothèque absente sur « \(title.name) »"
            )
            for genre in title.genres ?? [] {
                #expect(
                    title.filterKeys.contains(FilterKey.pattern(FilterKey.genre(genre.id))),
                    "Clé de genre absente sur « \(title.name) »"
                )
            }
            if let collection = title.collection {
                #expect(
                    title.filterKeys.contains(FilterKey.pattern(FilterKey.collection(collection.id))),
                    "Clé de collection absente sur « \(title.name) »"
                )
            }
            for person in (title.credits ?? []).compactMap(\.person) {
                #expect(
                    title.filterKeys.contains(FilterKey.pattern(FilterKey.person(person.id))),
                    "Clé de personne absente sur « \(title.name) »"
                )
            }
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

            // Même raison que pour les titres : `DemoCatalog` pose les relations à
            // la main, donc c'est ici que se vérifie que son `refreshDerived()`
            // vient bien après.
            #expect(
                person.filterKeys.contains(FilterKey.pattern(FilterKey.library(library.id))),
                "Clé de bibliothèque absente sur « \(person.displayName) »"
            )
            for role in person.roles {
                #expect(
                    person.filterKeys.contains(FilterKey.pattern(FilterKey.role(role))),
                    "Clé de rôle absente sur « \(person.displayName) »"
                )
            }

            // `ageAtDeath` ne vaut que pour les défunts, et se calcule.
            if person.deathDate == nil {
                #expect(person.ageAtDeath == nil, "Âge au décès sur un vivant")
            } else {
                #expect(person.ageAtDeath != nil, "Âge au décès manquant sur un défunt")
            }
        }
    }

    @Test("Les personnes de démonstration couvrent les trois tranches d'âge")
    func demoPeopleSpanEveryAgeBand() throws {
        // Un filtre sans donnée à mordre ne se teste pas à l'œil sur le banc d'essai.
        // Ce test fixe l'intention : si la génération des dates de naissance se
        // resserre un jour, les tranches vides se signaleront ici plutôt qu'à l'usage.
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)
        try context.save()

        for band in AgeBand.allCases {
            var filter = PersonFilter()
            filter.ageBand = band
            let found = try context.fetch(
                FetchDescriptor<Person>(
                    predicate: filter.predicate(hidingPrivate: false, libraryID: library.id)
                )
            )
            #expect(!found.isEmpty, "Aucune personne dans la tranche « \(band.label) »")
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

// MARK: - V2 · Le chemin de recadrage est-il exercé ?

@MainActor
struct DemoCropCoverageTests {

    /// L'écart « `CropContext.hero` n'est exercé par aucune donnée de démonstration » est-il
    /// fermé ?
    ///
    /// **Ce test répond à une question, il ne verrouille pas une valeur.** Les comptes exacts
    /// dépendent de la graine du générateur ; ce qui doit rester vrai est qu'il existe **au
    /// moins un** média de chaque sorte, sinon le chemin correspondant redevient mort sans que
    /// rien ne le signale — exactement l'état d'avant `V2`.
    @Test("Les données de démonstration exercent les deux contextes de recadrage")
    func demoDataExercisesBothCropContexts() throws {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)
        try DemoCatalog.populate(in: context, library: library, count: 40)
        try context.save()

        let fresh = ModelContext(container)
        let crops = try fresh.fetch(FetchDescriptor<MediaCrop>())
        let attachments = try fresh.fetch(FetchDescriptor<MediaAttachment>())

        let cardCrops = crops.filter { $0.context == .card }
        let heroCrops = crops.filter { $0.context == .hero }
        let backdrops = attachments.filter { $0.slot == .backdrop }

        #expect(crops.isEmpty == false, "aucune ligne MediaCrop : le chemin est mort")
        #expect(cardCrops.isEmpty == false, "le recadrage de carte n'est pas exercé")
        #expect(heroCrops.isEmpty == false, "CropContext.hero n'est toujours pas exercé")
        #expect(backdrops.isEmpty == false, "aucun backdrop : la fiche se replie toujours")

        // Le repli doit **rester** visible : un backdrop sur tous les titres effacerait le
        // chemin que `V0 bis` a tranché, et qui est le cas majoritaire.
        let titles = try fresh.fetch(FetchDescriptor<Title>())
        #expect(backdrops.count < titles.count, "le repli sur jaquette doit rester majoritaire")

        // Et aucun recadrage n'est neutre : un 50/50/100 serait indistinguable du repli, donc
        // il ne prouverait pas que le recadrage est appliqué.
        for crop in crops {
            let isNeutral = crop.positionX == 50 && crop.positionY == 50 && crop.zoom == 100
            #expect(isNeutral == false, "un recadrage neutre ne prouve rien")
        }
    }
}
