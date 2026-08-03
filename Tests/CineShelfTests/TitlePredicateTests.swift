import CineShelfCore
import Foundation
import SwiftData
import Testing

// La **forme** du prédicat, par opposition à ses critères, couverts par
// `TitleFilterTests`.
//
// Cette suite existe parce que le prédicat des titres n'est plus produit par
// `#Predicate` : la macro plafonne à cinq clauses sur un `@Model` SwiftData, et il
// en faut douze. L'arbre `PredicateExpressions` est donc assemblé à la main — voir
// `predicateClause(active:_:)` pour les mesures et les hypothèses écartées.
//
// Trois choses ne peuvent alors casser qu'ici, et aucune ne se signale à la
// compilation : la neutralisation d'une clause inactive, l'assemblage des
// sous-arbres en conjonction, et la traduction en SQL.

@MainActor
struct TitlePredicateTests {

    private typealias Fixture = TitleFilterFixture

    @Test("Un critère inactif ne restreint rien, un critère actif oui")
    func inactiveClausesAreNeutral() throws {
        // Le prédicat porte ses douze clauses en permanence : celles dont le
        // critère est inactif sont neutralisées par `predicateClause(active:)`. Si
        // cette garde s'inversait, un filtre par défaut ne rendrait plus rien du
        // tout — et c'est le seul test qui l'attraperait.
        let context = try Fixture.makeContext()
        Fixture.makeTitle(in: context, name: "Alpha", runtime: 90, rating: 6)
        Fixture.makeTitle(in: context, name: "Bêta", runtime: 120, rating: 8)

        #expect(try Fixture.results(TitleFilter(), in: context).count == 2, "Aucun critère actif")

        var filter = TitleFilter()
        filter.minimumRating = 7
        #expect(try Fixture.results(filter, in: context).map(\.name) == ["Bêta"])
    }

    @Test("Les douze clauses se combinent en conjonction")
    func allCriteriaCombine() throws {
        // Le prédicat est assemblé en trois sous-arbres recombinés. Un sous-arbre
        // oublié dans la conjonction finale ne casserait aucune compilation et
        // laisserait chaque test mono-critère vert. Seule une requête qui active
        // tout à la fois l'attrape.
        let context = try Fixture.makeContext()
        let library = Library(name: "Principale")
        let saga = TitleCollection(name: "Une saga")
        context.insert(library)
        context.insert(saga)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Policier", target: .title, in: library)
        let person = Person(firstName: "Ana", lastName: "Novak")
        person.refreshDerived()
        context.insert(person)

        func credit(_ title: Title) {
            let credit = Credit()
            credit.person = person
            credit.title = title
            context.insert(credit)
        }

        // La cible satisfait les douze clauses.
        let target = Fixture.makeTitle(in: context, name: "Le Bon Numéro", runtime: 110, rating: 8)
        target.library = library
        target.collection = saga
        target.genres = [genre]
        credit(target)
        target.refreshDerived()

        // Chaque leurre échoue sur exactement une clause : la collection pour
        // l'un, la durée pour l'autre.
        let wrongCollection = Fixture.makeTitle(
            in: context, name: "Le Bon Numéro bis", runtime: 110, rating: 8)
        wrongCollection.library = library
        wrongCollection.genres = [genre]
        credit(wrongCollection)
        wrongCollection.refreshDerived()

        let wrongRuntime = Fixture.makeTitle(
            in: context, name: "Le Bon Numéro ter", runtime: 200, rating: 8)
        wrongRuntime.library = library
        wrongRuntime.collection = saga
        wrongRuntime.genres = [genre]
        credit(wrongRuntime)
        wrongRuntime.refreshDerived()

        var filter = TitleFilter()
        filter.searchText = "numero"
        filter.collectionID = saga.id
        filter.genreID = genre.id
        filter.personID = person.id
        filter.minimumRuntime = 100
        filter.maximumRuntime = 130
        filter.minimumRating = 7
        filter.maximumRating = 10

        let found = try Fixture.results(filter, in: context, hidingPrivate: true, libraryID: library.id)
        #expect(found.map(\.name) == ["Le Bon Numéro"])
    }

    @Test("Le prédicat complet est bien traduit en SQL")
    func predicateIsEvaluatedByTheStore() throws {
        // Le garde-fou le plus important de la suite. Rien ne garantit *a priori*
        // que SwiftData sache traduire tous les nœuds assemblés à la main, et un
        // prédicat intraduisible ne se signale pas à la compilation.
        //
        // Un `ModelContext` neuf n'a aucun objet en attente : le fetch ne peut donc
        // pas être servi depuis la mémoire, il passe forcément par SQLite. Si une
        // clause ne se traduisait pas, le fetch lèverait — et si elle se traduisait
        // de travers, le compte serait faux.
        let store = try Fixture.makeStore()
        let library = Library(name: "Principale")
        store.context.insert(library)

        let kept = Fixture.makeTitle(in: store.context, name: "Gardé", runtime: 110, rating: 8)
        kept.library = library
        kept.refreshDerived()

        let dropped = Fixture.makeTitle(in: store.context, name: "Écarté", runtime: 40, rating: 2)
        dropped.library = library
        dropped.refreshDerived()

        try store.context.save()

        var filter = TitleFilter()
        filter.searchText = "e"
        filter.minimumRuntime = 100
        filter.minimumRating = 7

        let fresh = ModelContext(store.container)
        let found = try fresh.fetch(
            FetchDescriptor<Title>(
                predicate: filter.predicate(hidingPrivate: true, libraryID: library.id),
                sortBy: filter.descriptors
            )
        )

        #expect(found.map(\.name) == ["Gardé"])
    }

    @Test("La bibliothèque filtre, et le fait côté SQL")
    func libraryClauseDiscriminates() throws {
        // La bibliothèque est la clause qui porte toute la grille : si elle se
        // traduit mal, la grille se vide pour tout le monde. Elle est passée d'une
        // traversée de relation à un jeton de `filterKeys`, donc c'est le maintien
        // de ce jeton qui est en jeu ici autant que la clause elle-même.
        let context = try Fixture.makeContext()
        let mine = Library(name: "La mienne")
        let other = Library(name: "L'autre")
        context.insert(mine)
        context.insert(other)

        let kept = Fixture.makeTitle(in: context, name: "Chez moi")
        kept.library = mine
        kept.refreshDerived()
        let excluded = Fixture.makeTitle(in: context, name: "Ailleurs")
        excluded.library = other
        excluded.refreshDerived()
        Fixture.makeTitle(in: context, name: "Sans bibliothèque")

        let found = try Fixture.results(TitleFilter(), in: context, libraryID: mine.id)
        #expect(found.count == 1)
        #expect(found.first?.name == "Chez moi")

        // `nil` ne filtre pas : le sélecteur de profil n'a pas encore tranché.
        #expect(try Fixture.results(TitleFilter(), in: context, libraryID: nil).count == 3)

        // Contrôle négatif : une bibliothèque inconnue ne rend rien. Sans lui, une
        // clause toujours vraie passerait le premier cas.
        #expect(try Fixture.results(TitleFilter(), in: context, libraryID: UUID()).isEmpty)
    }
}
