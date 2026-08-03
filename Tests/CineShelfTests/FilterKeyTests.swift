import CineShelfCore
import Foundation
import SwiftData
import Testing

// Le maintien de `Title.filterKeys`.
//
// Les critères de bibliothèque, de collection, de genre et de personne ne lisent
// plus les relations : ils lisent une chaîne dérivée, recomposée par
// `refreshDerived()`. Le risque a donc changé de nature — ce n'est plus « la clause
// filtre-t-elle ? » mais « la chaîne est-elle à jour ? ». Une relation mutée sans
// rafraîchissement laisse la chaîne en arrière, et le filtre devient faux sans que
// rien ne casse.
//
// Les fixtures posent donc les relations puis appellent `refreshDerived()`
// explicitement, comme la production doit le faire. L'automatiser masquerait
// exactement ce qu'on veut voir.

@MainActor
struct FilterKeyTests {

    private typealias Fixture = TitleFilterFixture

    @Test("Un titre porte une clé par relation, triée et dédoublonnée")
    func filterKeysCoverEveryRelation() throws {
        let context = try Fixture.makeContext()
        let library = Library(name: "Principale")
        let saga = TitleCollection(name: "Saga")
        context.insert(library)
        context.insert(saga)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Policier", target: .title, in: library)
        let person = Person(firstName: "Ana", lastName: "Novak")
        person.refreshDerived()
        context.insert(person)

        let title = Fixture.makeTitle(in: context, name: "Tout branché")
        title.library = library
        title.collection = saga
        title.genres = [genre]

        // Deux crédits pour la même personne — un rôle d'acteur, un de
        // réalisation. La clé ne doit apparaître qu'une fois.
        for role in [CreditRole.cast, .director] {
            let credit = Credit(role: role)
            credit.person = person
            credit.title = title
            context.insert(credit)
        }
        title.refreshDerived()

        for token in [
            FilterKey.library(library.id), FilterKey.collection(saga.id),
            FilterKey.genre(genre.id), FilterKey.person(person.id)
        ] {
            #expect(title.filterKeys.contains(FilterKey.pattern(token)), "Clé manquante : \(token)")
        }

        let occurrences = title.filterKeys.components(separatedBy: FilterKey.person(person.id)).count - 1
        #expect(occurrences == 1, "La personne créditée deux fois ne doit produire qu'une clé")
    }

    @Test("Les clés sont stables d'un recalcul à l'autre")
    func filterKeysAreDeterministic() throws {
        // Un champ dérivé doit être une fonction de l'état, pas de l'ordre dans
        // lequel SwiftData rend une relation. Sans le tri de `FilterKey.keys`, deux
        // recalculs pourraient produire deux chaînes différentes, donc deux
        // `updatedAt`, donc une synchronisation CloudKit pour rien.
        let context = try Fixture.makeContext()
        let library = Library(name: "Principale")
        context.insert(library)
        let repository = GenreRepository(context: context)
        let first = try repository.findOrCreate(name: "Policier", target: .title, in: library)
        let second = try repository.findOrCreate(name: "Comédie", target: .title, in: library)

        let title = Fixture.makeTitle(in: context, name: "Deux genres")
        title.library = library
        title.genres = [first, second]
        title.refreshDerived()
        let once = title.filterKeys

        title.genres = [second, first]
        title.refreshDerived()

        #expect(title.filterKeys == once)
    }

    @Test("Ajouter un crédit depuis la personne invalide les clés du titre")
    func addingACreditFromThePersonSideInvalidatesKeys() throws {
        // Le cas le plus exposé : un `Credit` s'insère avec deux extrémités, et
        // rien n'oblige l'appelant à passer par le titre. Si le titre n'est pas
        // rafraîchi, il reste introuvable par un filtre de personne alors que la
        // relation, elle, est bien là.
        let context = try Fixture.makeContext()
        let person = Person(firstName: "Ana", lastName: "Novak")
        person.refreshDerived()
        context.insert(person)

        let title = Fixture.makeTitle(in: context, name: "Avec Ana")

        var filter = TitleFilter()
        filter.personID = person.id
        #expect(try Fixture.results(filter, in: context).isEmpty, "Pas encore de crédit")

        let credit = Credit()
        credit.person = person
        credit.title = title
        context.insert(credit)
        title.refreshDerived()

        #expect(try Fixture.results(filter, in: context).map(\.name) == ["Avec Ana"])
    }

    @Test("Muter une relation sans refreshDerived laisse les clés en arrière")
    func mutatingWithoutRefreshLeavesKeysStale() throws {
        // Ce test documente le piège plutôt qu'un comportement souhaitable : il fixe
        // le coût de l'oubli, pour que personne ne le découvre en production sous la
        // forme « la relation est bien là mais le filtre ne trouve rien ». Si un jour
        // SwiftData permet d'observer une relation et de dériver automatiquement,
        // c'est ce test qui devra tomber — et son échec sera la bonne nouvelle.
        let context = try Fixture.makeContext()
        let saga = TitleCollection(name: "Saga")
        context.insert(saga)

        let title = Fixture.makeTitle(in: context, name: "Rattaché en douce")
        title.collection = saga
        // Volontairement pas de `refreshDerived()`.

        var filter = TitleFilter()
        filter.collectionID = saga.id

        #expect(try Fixture.results(filter, in: context).isEmpty, "La clé n'a pas été recalculée")
        #expect(title.collection?.id == saga.id, "La relation, elle, est bien posée")

        title.refreshDerived()
        #expect(try Fixture.results(filter, in: context).count == 1)
    }

    @Test("Renommer un genre n'invalide aucune clé")
    func renamingAGenreDoesNotInvalidateKeys() throws {
        // `filterKeys` stocke des identifiants, pas des noms : un renommage est donc
        // un non-événement. Le test existe parce que « rien à faire » est le genre de
        // conclusion qu'on croit à tort avoir oubliée, et parce que stocker des noms
        // serait la simplification tentante qui casserait ça.
        let context = try Fixture.makeContext()
        let library = Library(name: "Principale")
        context.insert(library)
        let repository = GenreRepository(context: context)
        let genre = try repository.findOrCreate(name: "Policier", target: .title, in: library)

        let title = Fixture.makeTitle(in: context, name: "Un polar")
        title.genres = [genre]
        title.refreshDerived()
        let before = title.filterKeys

        var filter = TitleFilter()
        filter.genreID = genre.id
        #expect(try Fixture.results(filter, in: context).count == 1)

        repository.rename(genre, to: "Film noir")

        #expect(title.filterKeys == before)
        #expect(try Fixture.results(filter, in: context).count == 1)
    }

    @Test("Le repository maintient les clés à la création")
    func repositoryMaintainsKeysOnCreate() throws {
        // `TitleRepository.create` pose la bibliothèque puis appelle
        // `refreshDerived()`. L'ordre compte : inversé, la clé de bibliothèque
        // manquerait et un titre neuf serait invisible dans sa propre grille.
        let context = try Fixture.makeContext()
        let library = Library(name: "Principale")
        context.insert(library)

        let title = TitleRepository(context: context).create(name: "Neuf", in: library)

        #expect(title.filterKeys.contains(FilterKey.pattern(FilterKey.library(library.id))))
        #expect(try Fixture.results(TitleFilter(), in: context, libraryID: library.id).count == 1)
    }

    @Test("Un titre sans aucune relation a des clés vides")
    func aTitleWithoutRelationsHasEmptyKeys() throws {
        // Le cas limite de `FilterKey.keys([])`. Il compte parce qu'un titre neuf
        // sans bibliothèque existe — `TitleRepository.create` en affecte toujours
        // une, mais la relation est optionnelle — et parce qu'une chaîne vide ne doit
        // pas devenir un délimiteur orphelin qu'un `contains` pourrait matcher.
        let context = try Fixture.makeContext()
        let title = Fixture.makeTitle(in: context, name: "Tout seul")

        #expect(title.filterKeys.isEmpty)
        #expect(try Fixture.results(TitleFilter(), in: context).count == 1, "Il reste visible")
    }
}
