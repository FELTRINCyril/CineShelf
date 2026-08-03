import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Le budget de `docs/04` §4 : « Recherche sur 5 000 titres < 50 ms ».
//
// Deux seuils, comme pour `TitleFilterPerformanceTests` : un seuil absolu serré sur un
// runner partagé mesure le bruit de la machine. Les chiffres locaux sont notés à côté
// de chaque assertion, et c'est eux qu'il faut comparer d'une session à l'autre.
//
// La portée `.all` est le cas mesuré parce que c'est le plus coûteux : huit requêtes,
// deux par type — une tranche et un compte.

@MainActor
struct SearchPerformanceTests {

    private static let titleCount = 5_000

    private struct Catalog {
        let context: ModelContext
        let library: Library
        let service: SearchService
    }

    private func makeCatalog() throws -> Catalog {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)

        // Un terme présent partout (« zephyr ») et un terme rare, pour que la mesure
        // ne dépende pas d'un cas trop favorable.
        for index in 0..<Self.titleCount {
            let title = Title(name: index.isMultiple(of: 3) ? "Zephyr \(index)" : "Titre \(index)")
            title.library = library
            title.summary = "Résumé du titre \(index)."
            title.refreshDerived()
            context.insert(title)
        }
        for index in 0..<500 {
            let person = Person(firstName: "Zephyr\(index)", lastName: "Nom\(index)")
            person.library = library
            person.refreshDerived()
            context.insert(person)
        }
        for index in 0..<50 {
            let collection = TitleCollection(name: "Zephyr collection \(index)")
            collection.library = library
            collection.refreshDerived()
            context.insert(collection)
        }
        for index in 0..<50 {
            let link = SavedLink(urlString: "https://zephyr\(index).example")
            link.name = "Zephyr signet \(index)"
            link.library = library
            link.refreshDerived()
            context.insert(link)
        }
        try context.save()

        return Catalog(context: context, library: library, service: SearchService(context: context))
    }

    private func measure(
        _ term: String, in catalog: Catalog, scope: SearchScope = .all, iterations: Int = 5
    ) throws -> (duration: Duration, total: Int) {
        // Une passe à blanc : la première requête paie la préparation des instructions
        // SQL, qui n'arrive qu'une fois dans la vie du processus.
        _ = try catalog.service.search(
            term, scope: scope, hidingPrivate: true, libraryID: catalog.library.id)

        var total = 0
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for _ in 0..<iterations {
                let outcome = try catalog.service.search(
                    term, scope: scope, hidingPrivate: true, libraryID: catalog.library.id)
                if case .results(let results) = outcome { total = results.total }
            }
        }
        return (elapsed / iterations, total)
    }

    @Test("La recherche toutes portées tient le budget sur 5 000 titres")
    func searchStaysWithinBudget() throws {
        let catalog = try makeCatalog()
        let (duration, total) = try measure("zephyr", in: catalog)

        #expect(total > 0, "Une recherche qui ne trouve rien ne mesure rien")

        // Mesuré (Apple silicon, magasin en mémoire, moyenne sur 5 itérations après
        // une passe à blanc) : **8,3 ms** en portée `.all`, soit huit requêtes — deux
        // par type, une tranche et un compte. Un second passage a donné 11,1 ms, ce qui
        // dit la dispersion réelle sur une machine au repos. Le budget de `docs/04` §4
        // est de 50 ms.
        //
        // Seuil à 40 ms : environ quatre fois la mesure haute, et sous le budget. Ni le
        // budget lui-même — il laisserait passer un facteur cinq —, ni 12 ms, qui
        // clignoterait au premier runner chargé.
        #expect(
            duration < .milliseconds(40),
            "Recherche `.all` sur \(Self.titleCount) titres : \(duration) — référence 8 à 11 ms"
        )

        // **Ce que ce fichier ne mesure pas, et pourquoi.** Une première version
        // comparait `.titles` à `.all` pour prouver que la portée restreint vraiment la
        // requête. Mesuré : 6,0 ms contre 11,1 ms, un rapport de 1,85 — trop mince pour
        // être assené sans clignoter sur un runner partagé. Et surtout inutile : la
        // preuve que la portée restreint la requête est **catégorique** et vit dans
        // `SearchServiceTests.scopesRestrictTheQuery`, où une portée unique rend
        // exactement zéro résultat pour les trois autres types. Une preuve catégorique
        // vaut mieux qu'un rapport fragile.
    }

}
