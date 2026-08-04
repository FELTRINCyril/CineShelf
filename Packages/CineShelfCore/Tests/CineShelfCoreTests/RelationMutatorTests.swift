import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les mutateurs de relations des repositories.
//
// Ils existent pour une raison précise : `refreshDerived()` compose `filterKeys` à
// partir des relations, donc une relation écrite sans rafraîchissement rend le filtre
// correspondant faux **en silence**. La règle SwiftLint
// `no_relation_write_outside_core` interdit les autres portes ; ces tests vérifient
// que celles-ci tiennent leur promesse.
//
// Chaque cas passe par le magasin : c'est la seule façon d'exercer la traduction SQL
// du prédicat, et donc de prouver que la clé est vraiment retrouvable.

@MainActor
struct RelationMutatorTests {

    private func filtered(_ context: ModelContext, _ pattern: String) throws -> [Title] {
        try context.save()
        return try context.fetch(
            FetchDescriptor<Title>(predicate: #Predicate<Title> { $0.filterKeys.contains(pattern) })
        )
    }

    @Test("setCollection rend le titre retrouvable par sa collection")
    func setCollectionMaintainsKeys() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Un titre", in: library)
        let saga = CollectionRepository(context: context).create(name: "Saga", in: library)

        let pattern = FilterKey.pattern(FilterKey.collection(saga.id))
        #expect(try filtered(context, pattern).isEmpty)

        repository.setCollection(saga, on: title, journal: .perEntity)
        #expect(try filtered(context, pattern).map(\.name) == ["Un titre"])

        // Et le retrait nettoie la clé.
        repository.setCollection(nil, on: title, journal: .perEntity)
        #expect(try filtered(context, pattern).isEmpty)
    }

    @Test("setGenres rend le titre retrouvable par chacun de ses genres")
    func setGenresMaintainsKeys() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let genres = GenreRepository(context: context)
        let title = repository.create(name: "Un polar", in: library)
        let first = try genres.findOrCreate(name: "Policier", in: library)
        let second = try genres.findOrCreate(name: "Comédie", in: library)

        repository.setGenres([first, second], on: title, journal: .perEntity)
        for genre in [first, second] {
            #expect(try filtered(context, FilterKey.pattern(FilterKey.genre(genre.id))).count == 1)
        }

        // Remplacer la liste retire les clés des genres sortants.
        repository.setGenres([second], on: title, journal: .perEntity)
        #expect(try filtered(context, FilterKey.pattern(FilterKey.genre(first.id))).isEmpty)
        #expect(try filtered(context, FilterKey.pattern(FilterKey.genre(second.id))).count == 1)
    }

    @Test("addCredit et removeCredit maintiennent la clé de personne")
    func creditMutatorsMaintainKeys() throws {
        // Le chemin le plus exposé : un `Credit` a deux extrémités, et rien
        // n'obligeait l'appelant à passer par le titre.
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Avec Ana", in: library)
        let person = PersonRepository(context: context)
            .create(firstName: "Ana", lastName: "Novak", in: library)

        let pattern = FilterKey.pattern(FilterKey.person(person.id))
        #expect(try filtered(context, pattern).isEmpty)

        let credit = repository.addCredit(person: person, to: title)
        #expect(try filtered(context, pattern).map(\.name) == ["Avec Ana"])

        repository.removeCredit(credit, from: title)
        #expect(try filtered(context, pattern).isEmpty)
    }

    @Test("addCredit place le nouveau crédit en fin de casting")
    func addCreditAppends() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Un film", in: library)
        let people = PersonRepository(context: context)
        let first = people.create(firstName: "Ana", in: library)
        let second = people.create(firstName: "Bo", in: library)

        let one = repository.addCredit(person: first, to: title)
        let two = repository.addCredit(person: second, to: title)

        #expect(one.orderIndex == 0)
        #expect(two.orderIndex == 1)
    }

    @Test("move change la bibliothèque et la clé qui la porte")
    func moveMaintainsKeys() throws {
        let (context, library) = try makeTestLibrary()
        let elsewhere = Library(name: "Ailleurs")
        context.insert(elsewhere)
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Nomade", in: library)

        repository.move(title, to: elsewhere)

        #expect(try filtered(context, FilterKey.pattern(FilterKey.library(library.id))).isEmpty)
        #expect(try filtered(context, FilterKey.pattern(FilterKey.library(elsewhere.id))).count == 1)
    }

    @Test("Les mutateurs de personne maintiennent ses clés")
    func personMutatorsMaintainKeys() throws {
        let (context, library) = try makeTestLibrary()
        let repository = PersonRepository(context: context)
        let person = repository.create(firstName: "Ana", lastName: "Novak", in: library)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Voix", target: .person, in: library)

        repository.setGenres([genre], on: person, journal: .perEntity)
        repository.setRoles([.actor, .director], on: person, journal: .perEntity)
        try context.save()

        for token in [
            FilterKey.genre(genre.id), FilterKey.role(.actor), FilterKey.role(.director)
        ] {
            #expect(person.filterKeys.contains(FilterKey.pattern(token)), "Clé manquante : \(token)")
        }
        #expect(person.filterKeys.contains(FilterKey.pattern(FilterKey.role(.social))) == false)

        let elsewhere = Library(name: "Ailleurs")
        context.insert(elsewhere)
        repository.move(person, to: elsewhere)
        #expect(person.filterKeys.contains(FilterKey.pattern(FilterKey.library(elsewhere.id))))
        #expect(person.filterKeys.contains(FilterKey.pattern(FilterKey.library(library.id))) == false)
    }

    @Test("Chaque mutation de relation est journalisée")
    func mutationsAreRecorded() throws {
        // Les mutateurs délèguent à `update(_:_:)`, qui journalise. Un lot d'édition
        // en masse voudra une entrée pour le lot et non une par ligne : c'est le
        // sujet de `L10`, et ce test dit ce qui se passe avant elle.
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let title = repository.create(name: "Un titre", in: library)
        let saga = CollectionRepository(context: context).create(name: "Saga", in: library)

        let before = try activityCount(in: context, action: .update)
        repository.setCollection(saga, on: title, journal: .perEntity)

        #expect(try activityCount(in: context, action: .update) == before + 1)
    }
}
