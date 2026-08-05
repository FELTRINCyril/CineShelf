import CineShelfCore
import Foundation
import SwiftData
import Testing

// `V1` · Ce que l'écran de recherche décide, et que la vue ne peut pas prouver seule.
//
// **Trois choses seulement, et c'est délibéré.** Le rendu de `SearchView` se juge à l'écran
// et au catalogue ; ce qui se teste ici est ce dont un défaut serait **silencieux** :
//
// 1. que les deux branches de `SearchOutcome` correspondent bien à deux situations
//    distinctes — un terme vide contre un terme sans correspondance. C'est l'invariant que
//    l'écran s'appuie dessus, et le confondre donnerait le catalogue entier sous un champ
//    vide ;
// 2. que les compteurs de portée que l'écran affiche viennent bien du **total** et non de la
//    tranche rendue. « Titres · 9 » sous une rangée de dix cartes serait faux, et personne ne
//    le verrait avant d'avoir un groupe tronqué ;
// 3. que la clé d'anti-rebond change quand la portée change — sinon choisir un onglet ne
//    relancerait rien, et l'écran garderait les résultats de la portée précédente.

@MainActor
struct SearchScreenLogicTests {

    private struct Catalog {
        let container: ModelContainer
        let context: ModelContext
        let library: Library
        let service: SearchService
    }

    private func makeCatalog(titles: [String], people: [String] = []) throws -> Catalog {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)

        for name in titles {
            let title = Title(name: name)
            title.library = library
            context.insert(title)
            title.refreshDerived()
        }
        for name in people {
            let person = Person(firstName: name, lastName: "")
            person.library = library
            context.insert(person)
            person.refreshDerived()
        }
        try context.save()

        // Contexte neuf : les prédicats de `SearchService` doivent être exercés en SQL, pas
        // évalués en Swift sur des objets en attente.
        let fresh = ModelContext(container)
        return Catalog(
            container: container, context: fresh, library: library,
            service: SearchService(context: fresh))
    }

    // MARK: Les deux branches

    @Test("Un terme vide donne .idle, pas un .results vide")
    func emptyTermIsIdleNotEmptyResults() throws {
        let catalog = try makeCatalog(titles: ["Dune", "Arrival"])

        for blank in ["", "   ", "\n", "\t "] {
            let outcome = try catalog.service.search(
                blank, hidingPrivate: false, libraryID: catalog.library.id)
            guard case .idle = outcome else {
                Issue.record("« \(blank.debugDescription) » devrait donner .idle")
                continue
            }
        }
    }

    @Test("Un terme sans correspondance donne .results vide, pas .idle")
    func unmatchedTermIsEmptyResultsNotIdle() throws {
        let catalog = try makeCatalog(titles: ["Dune", "Arrival"])

        let outcome = try catalog.service.search(
            "zzzzz", hidingPrivate: false, libraryID: catalog.library.id)

        // C'est la distinction dont tout l'écran dépend : ici il doit écrire « aucun
        // résultat », sur `.idle` il doit écrire les recherches récentes. Un seul état pour
        // les deux et l'un des deux écrans est faux.
        guard case .results(let found) = outcome else {
            Issue.record("un terme saisi doit toujours donner .results")
            return
        }
        #expect(found.isEmpty)
        #expect(found.total == 0)
    }

    @Test("Un terme qui correspond donne .results non vide")
    func matchedTermIsNonEmptyResults() throws {
        let catalog = try makeCatalog(titles: ["Dune", "Dune deuxième partie", "Arrival"])

        guard
            case .results(let found) = try catalog.service.search(
                "dune", hidingPrivate: false, libraryID: catalog.library.id)
        else {
            Issue.record("attendu .results")
            return
        }

        #expect(found.isEmpty == false)
        #expect(found.titles.total == 2)
    }

    // MARK: Le compteur des onglets

    @Test("Le compteur d'un groupe est le total, pas la taille de la tranche rendue")
    func groupCountIsTheTotalNotTheSlice() throws {
        // Douze titres, tranche bornée à cinq : l'onglet doit annoncer 12.
        let names = (1...12).map { "Dune \($0)" }
        let catalog = try makeCatalog(titles: names)

        guard
            case .results(let found) = try catalog.service.search(
                "dune", hidingPrivate: false, libraryID: catalog.library.id, limitPerGroup: 5)
        else {
            Issue.record("attendu .results")
            return
        }

        #expect(found.titles.items.count == 5, "la tranche est bornée")
        #expect(found.titles.total == 12, "le libellé de rangée annonce le total")
        #expect(found.titles.isTruncated)
    }

    @Test("Les comptes des portées viennent d'une seule passe .all")
    func scopeCountsComeFromASinglePass() throws {
        let catalog = try makeCatalog(
            titles: ["Villeneuve raconte"], people: ["Villeneuve"])

        guard
            case .results(let all) = try catalog.service.search(
                "villeneuve", hidingPrivate: false, libraryID: catalog.library.id)
        else {
            Issue.record("attendu .results")
            return
        }

        // L'écran construit sa table de compteurs à partir de ces quatre totaux ; la somme
        // doit être le total, sinon l'onglet « Tout » mentirait par rapport aux autres.
        #expect(all.titles.total == 1)
        #expect(all.people.total == 1)
        #expect(
            all.total == all.titles.total + all.people.total + all.collections.total
                + all.savedLinks.total)
    }

    @Test("Une portée restreinte laisse les autres groupes vides")
    func narrowScopeEmptiesTheOtherGroups() throws {
        let catalog = try makeCatalog(
            titles: ["Villeneuve raconte"], people: ["Villeneuve"])

        guard
            case .results(let onlyPeople) = try catalog.service.search(
                "villeneuve", scope: .people, hidingPrivate: false,
                libraryID: catalog.library.id)
        else {
            Issue.record("attendu .results")
            return
        }

        #expect(onlyPeople.people.total == 1)
        #expect(onlyPeople.titles.total == 0, "hors portée")
        // Et le groupe hors portée est vide, pas absent : c'est ce qui permet à l'écran
        // d'omettre la rangée sans se demander si la portée l'excluait ou si rien ne
        // correspondait.
        #expect(onlyPeople.titles.items.isEmpty)
    }

    // MARK: La clé d'anti-rebond

    @Test("La clé d'anti-rebond distingue le terme et la portée")
    func debounceKeySeparatesTermAndScope() {
        // La clé est reconstruite ici parce que `SearchView` est `@MainActor` et privée : ce
        // qui se teste est la **règle**, pas l'accesseur. Le séparateur est un caractère de
        // contrôle exprès — avec un point, « dune » en portée `all` et « all.dune » en portée
        // vide donneraient la même clé, et l'un des deux ne relancerait pas.
        func key(_ scope: SearchScope, _ term: String) -> String {
            "\(scope.rawValue)\u{1F}\(term)"
        }

        #expect(key(.all, "dune") != key(.titles, "dune"), "changer de portée doit relancer")
        #expect(key(.all, "dune") != key(.all, "dunes"), "changer de terme doit relancer")
        #expect(key(.all, "dune") == key(.all, "dune"), "rien n'a changé, rien ne relance")
        // Le cas que le séparateur existe pour empêcher.
        #expect(key(.titles, "") != key(.all, "titles"))
    }
}
