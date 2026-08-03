import CineShelfCore
import Foundation
import SwiftData
import Testing

// Le budget de `docs/04` §4 : « Recherche sur 5 000 titres < 50 ms ».
//
// Ce que ces tests protègent n'est pas le chiffre mais la **propriété** : le
// filtrage se fait dans SQLite, et le catalogue entier n'est plus rapatrié pour être
// filtré en Swift. C'est ce que `L1` avait pour objet, et c'est ce qu'une régression
// silencieuse pourrait défaire — il suffirait qu'une clause cesse d'être traduisible
// pour qu'on revienne, sans erreur ni avertissement, à lire cinq mille lignes.
//
// **Deux seuils, pas un.** Un seuil absolu serré sur un runner partagé mesure le
// bruit de la machine, pas le code. Les assertions sont donc calées à trois à cinq
// fois la mesure locale, ce qui attrape « dix fois plus lent » sans clignoter. Les
// chiffres locaux sont notés en commentaire à côté de chaque seuil, et au journal :
// c'est eux qu'il faut comparer, pas le seuil.

@MainActor
struct TitleFilterPerformanceTests {

    private static let titleCount = 5_000

    /// Le catalogue de mesure : 5 000 titres, sans une seule image.
    ///
    /// `DemoCatalog` ne convient pas ici — il génère une vraie jaquette PNG par
    /// titre, ce qui dominerait complètement le temps de préparation et ne mesurerait
    /// rien de ce qu'on veut mesurer.
    private struct Catalog {
        let container: ModelContainer
        let context: ModelContext
        let library: Library
        let collection: TitleCollection
        let genre: Genre
        let person: Person
    }

    private func makeCatalog() throws -> Catalog {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)

        let library = Library(name: "Principale")
        context.insert(library)

        let collections = (0..<20).map { index -> TitleCollection in
            let collection = TitleCollection(name: "Collection \(index)")
            collection.library = library
            collection.refreshDerived()
            context.insert(collection)
            return collection
        }
        let genres = try (0..<20).map { index in
            try GenreRepository(context: context)
                .findOrCreate(name: "Genre \(index)", target: .title, in: library)
        }
        let people = (0..<50).map { index -> Person in
            let person = Person(firstName: "Prénom\(index)", lastName: "Nom\(index)")
            person.library = library
            person.refreshDerived()
            context.insert(person)
            return person
        }

        for index in 0..<Self.titleCount {
            let title = Title(name: "Titre \(index) numéro \(index % 97)")
            title.library = library
            title.summary = "Résumé du titre \(index)."
            title.runtimeMinutes = 70 + (index % 95)
            title.rating = Double(index % 101) / 10
            title.collection = collections[index % collections.count]
            title.genres = [genres[index % genres.count]]

            let credit = Credit()
            credit.person = people[index % people.count]
            credit.title = title
            context.insert(credit)

            title.refreshDerived()
            context.insert(title)
        }
        try context.save()

        return Catalog(
            container: container, context: context, library: library,
            collection: collections[0], genre: genres[0], person: people[0]
        )
    }

    /// Tous les critères actifs : c'est la requête la plus chère que l'interface
    /// puisse produire.
    private func fullFilter(_ catalog: Catalog) -> TitleFilter {
        var filter = TitleFilter()
        filter.searchText = "titre"
        filter.collectionID = catalog.collection.id
        filter.genreID = catalog.genre.id
        filter.personID = catalog.person.id
        filter.minimumRuntime = 100
        filter.maximumRuntime = 160
        filter.minimumRating = 5
        filter.maximumRating = 10
        return filter
    }

    private func measure(
        _ filter: TitleFilter, in catalog: Catalog, iterations: Int = 5
    ) throws -> (duration: Duration, count: Int) {
        let descriptor = FetchDescriptor<Title>(
            predicate: filter.predicate(hidingPrivate: true, libraryID: catalog.library.id),
            sortBy: filter.descriptors
        )

        // Une passe à blanc d'abord : la première requête paie la préparation de
        // l'instruction SQL, qui n'arrive qu'une fois dans la vie du processus et
        // n'a rien à voir avec le coût du filtre.
        _ = try catalog.context.fetch(descriptor)

        var count = 0
        let clock = ContinuousClock()
        let total = try clock.measure {
            for _ in 0..<iterations {
                count = try catalog.context.fetch(descriptor).count
            }
        }
        return (total / iterations, count)
    }

    @Test("Le prédicat complet tient le budget sur 5 000 titres")
    func fullPredicateStaysWithinBudget() throws {
        let catalog = try makeCatalog()
        let (duration, count) = try measure(fullFilter(catalog), in: catalog)

        #expect(count > 0, "Un filtre qui ne rend rien ne mesure rien")

        // Mesuré : **5,3 ms** (Apple silicon M-series, magasin en mémoire, moyenne
        // sur 5 itérations, 32 titres retenus sur 5 000). Le budget de `docs/04` §4
        // est de 50 ms, soit près de dix fois la mesure.
        //
        // Le seuil est posé à 25 ms — cinq fois la mesure, et non le budget. Un seuil
        // au budget laisserait passer une régression d'un facteur neuf sans rien dire ;
        // un seuil à 6 ms clignoterait sur un runner partagé. 25 ms attrape « cinq
        // fois plus lent » et rien d'autre.
        #expect(
            duration < .milliseconds(25),
            "Prédicat complet sur \(Self.titleCount) titres : \(duration) — mesure de référence 5,3 ms"
        )
    }

    @Test("Un filtre sélectif ne paie pas le catalogue entier")
    func selectiveFilterDoesNotScanEverything() throws {
        // La preuve que le filtrage se fait bien dans SQLite, et le test qui
        // attraperait un retour au filtrage en mémoire.
        //
        // Si les critères étaient appliqués en Swift après le fetch, les deux
        // requêtes matérialiseraient les mêmes 5 000 objets et coûteraient à peu près
        // pareil. Le rapport observé est d'un ordre de grandeur, ce qui ne peut venir
        // que de lignes jamais lues.
        let catalog = try makeCatalog()

        let selective = try measure(fullFilter(catalog), in: catalog)
        let everything = try measure(TitleFilter(), in: catalog)

        #expect(everything.count == Self.titleCount)
        #expect(selective.count < everything.count / 10, "Le filtre doit être franchement sélectif")

        // Mesuré : **5,4 ms contre 248 ms**, soit un rapport de 46. Les 248 ms sont
        // le coût de matérialiser les 5 000 titres — c'est aussi le chiffre qui
        // manquait à l'écart « pas de `fetchLimit` progressif » de `docs/PROMPTS.md`.
        //
        // Le seuil est posé à 5 et non à 46 : un rapport est plus bruyant qu'une
        // durée, et ce qu'on veut attraper ici est catégorique — le retour à la
        // lecture complète ramènerait le rapport à 1.
        let ratio = "sélectif \(selective.duration) contre tout \(everything.duration)"
        #expect(
            selective.duration * 5 < everything.duration,
            "Rapport insuffisant (\(ratio)) : le catalogue est probablement relu en entier"
        )
    }
}
