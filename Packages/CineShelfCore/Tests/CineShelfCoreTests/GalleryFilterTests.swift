import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// `L1 bis` · Le filtre de galerie.
//
// **Tout passe par le magasin**, jamais sur des objets en attente : la règle de `CLAUDE.md`,
// et ici elle a servi pour de vrai. La route écartée — un `#Predicate<MediaAsset>` sur
// `attachments?.isEmpty` — compile, se vérifie sous 200 ms, et **tue le processus** au
// premier `fetch` (`Keypath containing KVC aggregate`, signal 6). Aucune de ces trois
// vérifications ne l'aurait vue ; seul un fetch depuis un contexte neuf l'a montrée.
//
// **Ce fichier ne contient donc pas de test de la route fautive**, et c'est délibéré : il
// ferait mourir la suite entière au lieu d'échouer, et personne ne saurait quel test a
// planté. La démonstration est dans l'en-tête de `GalleryFilter.swift`, avec la trace.

@MainActor
struct GalleryFilterTests {

    private struct Catalog {
        let container: ModelContainer
        let context: ModelContext
        /// Combien de médias sans aucune pièce jointe.
        let orphanCount: Int
        let assetsByOwner: [MediaSource: Set<UUID>]
    }

    /// Un catalogue où chaque source est représentée, et où les comptes diffèrent.
    ///
    /// Des comptes **différents** par source, exprès : avec quatre groupes de même taille,
    /// une confusion entre deux sources passerait inaperçue.
    private func makeCatalog(
        titles: Int, people: Int, collections: Int, orphans: Int
    ) throws -> Catalog {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)

        var byOwner: [MediaSource: Set<UUID>] = [:]

        for index in 0..<titles {
            let title = Title(name: "Titre \(index)")
            title.library = library
            context.insert(title)
            byOwner[.title, default: []].insert(attach(to: title, in: context))
        }
        for index in 0..<people {
            let person = Person(firstName: "Personne", lastName: "\(index)")
            person.library = library
            context.insert(person)
            byOwner[.person, default: []].insert(attach(to: person, in: context))
        }
        for index in 0..<collections {
            let collection = TitleCollection(name: "Collection \(index)")
            collection.library = library
            context.insert(collection)
            byOwner[.collection, default: []].insert(attach(to: collection, in: context))
        }
        for _ in 0..<orphans {
            let asset = MediaAsset()
            context.insert(asset)
        }

        try context.save()
        return Catalog(
            container: container, context: context, orphanCount: orphans, assetsByOwner: byOwner)
    }

    private func attach(to title: Title, in context: ModelContext) -> UUID {
        let asset = MediaAsset()
        context.insert(asset)
        let attachment = MediaAttachment(slot: .gallery)
        attachment.asset = asset
        attachment.title = title
        context.insert(attachment)
        return asset.id
    }

    private func attach(to person: Person, in context: ModelContext) -> UUID {
        let asset = MediaAsset()
        context.insert(asset)
        let attachment = MediaAttachment(slot: .gallery)
        attachment.asset = asset
        attachment.person = person
        context.insert(attachment)
        return asset.id
    }

    private func attach(to collection: TitleCollection, in context: ModelContext) -> UUID {
        let asset = MediaAsset()
        context.insert(asset)
        let attachment = MediaAttachment(slot: .gallery)
        attachment.asset = asset
        attachment.collection = collection
        context.insert(attachment)
        return asset.id
    }

    // MARK: Les sources

    @Test("Chaque source ne rend que ses médias, depuis un contexte neuf")
    func eachSourceIsExact() throws {
        let catalog = try makeCatalog(titles: 7, people: 5, collections: 3, orphans: 11)
        // Contexte neuf : c'est ce qui force la traduction SQL du prédicat. Sur du pending,
        // SwiftData évalue en Swift et le chemin réel n'est pas exercé.
        let fresh = ModelContext(catalog.container)

        for source in [MediaSource.title, .person, .collection] {
            let found = try GalleryQuery.assetIDs(
                matching: GalleryFilter(sources: [source]), in: fresh)
            #expect(found == catalog.assetsByOwner[source], "\(source.rawValue)")
        }
    }

    @Test("Les orphelins sont les médias qu'aucune pièce jointe ne réclame")
    func orphansAreAssetsWithoutAnyAttachment() throws {
        let catalog = try makeCatalog(titles: 7, people: 5, collections: 3, orphans: 11)
        let fresh = ModelContext(catalog.container)

        let found = try GalleryQuery.assetIDs(
            matching: GalleryFilter(sources: [.orphan]), in: fresh)

        #expect(found.count == catalog.orphanCount)
        // Et aucun média possédé ne s'y trouve : c'est la moitié de l'assertion qui compte,
        // parce qu'un compte juste peut cacher deux erreurs qui s'annulent.
        for owned in catalog.assetsByOwner.values.flatMap({ $0 }) {
            #expect(!found.contains(owned))
        }
    }

    @Test("Décocher « titre » ne fait pas passer ses médias pour des orphelins")
    func deselectingASourceDoesNotCreateFalseOrphans() throws {
        // Le défaut que la soustraction naïve produirait : retrancher seulement les pièces
        // jointes des sources **retenues** compterait un média de titre comme orphelin dès
        // que « titre » est décoché. Faux, et invisible — l'écran montrerait plus d'images,
        // ce qui ne ressemble pas à une erreur.
        let catalog = try makeCatalog(titles: 7, people: 5, collections: 3, orphans: 11)
        let fresh = ModelContext(catalog.container)

        let found = try GalleryQuery.assetIDs(
            matching: GalleryFilter(sources: [.person, .orphan]), in: fresh)

        #expect(found.count == 5 + 11)
        for titleAsset in catalog.assetsByOwner[.title] ?? [] {
            #expect(!found.contains(titleAsset), "un média de titre compté comme orphelin")
        }
    }

    @Test("Un filtre vide vaut « toutes les sources », pas « aucune »")
    func emptyFilterMeansEverything() throws {
        let catalog = try makeCatalog(titles: 7, people: 5, collections: 3, orphans: 11)
        let fresh = ModelContext(catalog.container)

        let all = try GalleryQuery.assetIDs(matching: GalleryFilter(), in: fresh)

        #expect(all.count == 7 + 5 + 3 + 11)
        #expect(GalleryFilter().isActive == false)
        // Les quatre cochées valent aussi « inactif » : sinon l'interface afficherait un
        // filtre actif alors que rien n'est filtré.
        #expect(GalleryFilter(sources: Set(MediaSource.allCases)).isActive == false)
        #expect(GalleryFilter(sources: [.orphan]).isActive == true)
    }

    @Test("Une galerie sans le moindre média rend un ensemble vide, pas une erreur")
    func emptyCatalogYieldsNothing() throws {
        let catalog = try makeCatalog(titles: 0, people: 0, collections: 0, orphans: 0)
        let fresh = ModelContext(catalog.container)

        #expect(try GalleryQuery.assetIDs(matching: GalleryFilter(), in: fresh).isEmpty)
        #expect(
            try GalleryQuery.assetIDs(matching: GalleryFilter(sources: [.orphan]), in: fresh)
                .isEmpty)
    }

    @Test("Une pièce jointe sans média ne fabrique pas d'identifiant")
    func attachmentWithoutAssetIsIgnored() throws {
        // Cas dégénéré atteignable : `MediaAttachment.asset` est optionnel comme toutes les
        // relations du schéma. Sans le `compactMap`, l'ensemble des « rattachés » serait faux
        // et des médias réellement orphelins disparaîtraient du filtre.
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)
        let title = Title(name: "Sans média")
        title.library = library
        context.insert(title)
        let dangling = MediaAttachment(slot: .gallery)
        dangling.title = title
        context.insert(dangling)
        let orphan = MediaAsset()
        context.insert(orphan)
        try context.save()

        let fresh = ModelContext(container)

        #expect(try GalleryQuery.assetIDs(matching: GalleryFilter(sources: [.title]), in: fresh).isEmpty)
        #expect(
            try GalleryQuery.assetIDs(matching: GalleryFilter(sources: [.orphan]), in: fresh)
                == [orphan.id])
    }

    // MARK: Le mélange à graine stable

    @Test("La même graine rend le même ordre, deux fois et sur deux instances")
    func sameSeedSameOrder() {
        let items = Array(0..<200)
        let first = GalleryFilter(shuffleSeed: 42).shuffled(items)
        let second = GalleryFilter(shuffleSeed: 42).shuffled(items)

        #expect(first == second)
        // Et c'est bien un mélange : l'ordre naturel serait un faux positif de stabilité.
        #expect(first != items)
        #expect(first.sorted() == items, "le mélange ne perd ni ne duplique rien")
    }

    @Test("Deux graines différentes rendent deux ordres différents")
    func differentSeedsDifferentOrders() {
        let items = Array(0..<200)

        #expect(GalleryFilter(shuffleSeed: 1).shuffled(items) != GalleryFilter(shuffleSeed: 2).shuffled(items))
    }

    @Test("Sans graine, l'ordre reçu est conservé tel quel")
    func noSeedKeepsTheOrder() {
        let items = Array(0..<50)

        #expect(GalleryFilter().shuffled(items) == items)
    }

    @Test("Les cas dégénérés du mélange ne piègent pas")
    func shuffleHandlesDegenerateInput() {
        let filter = GalleryFilter(shuffleSeed: 0)

        // Graine nulle : SplitMix64 la tolère, l'incrément est ajouté avant le brassage.
        #expect(filter.shuffled([1, 2, 3]).sorted() == [1, 2, 3])
        #expect(filter.shuffled([Int]()).isEmpty)
        #expect(filter.shuffled([7]) == [7])
        // Une graine au maximum ne déborde pas : les opérateurs sont `&+` et `&*`.
        #expect(GalleryFilter(shuffleSeed: .max).shuffled([1, 2, 3]).sorted() == [1, 2, 3])
    }

    @Test("Le filtre survit à un aller-retour JSON, graine comprise")
    func filterRoundTripsThroughJSON() throws {
        // `NavigationModel` sérialise déjà `TitleFilter` de cette façon : une galerie qui
        // perdrait sa graine au relancement remélangerait tout, ce qui est exactement ce que
        // la graine existe pour éviter.
        let filter = GalleryFilter(sources: [.person, .orphan], shuffleSeed: 99)
        let decoded = try JSONDecoder().decode(
            GalleryFilter.self, from: try JSONEncoder().encode(filter))

        #expect(decoded == filter)
        #expect(decoded.shuffleSeed == 99)
    }
}
