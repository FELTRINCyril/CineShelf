import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les filtres de personnes : rôle, genre, tranche d'âge.
//
// Comme pour les titres, tout passe par `save()` puis `fetch` : sur du pending,
// SwiftData évalue le prédicat en Swift et sa traduction SQL n'est jamais exercée.
//
// La tranche d'âge a sa propre section, parce qu'elle est le seul critère du projet
// dont la réponse **dépend du jour où on la pose**. Les tests fixent donc l'instant
// de référence — sinon ils changeraient de sens à chaque anniversaire de leurs
// fixtures.

@MainActor
struct PersonFilterTests {

    /// Instant de référence fixe. Toute date de naissance en dérive.
    private static let reference: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        return Calendar.current.date(from: components) ?? .distantPast
    }()

    private func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        return (container, ModelContext(container))
    }

    /// Une date de naissance qui donne exactement cet âge à la date de référence.
    private func birthDate(forAge age: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: -age, to: Self.reference) ?? .distantPast
    }

    @discardableResult
    private func makePerson(
        in context: ModelContext,
        name: String,
        age: Int? = nil,
        ageAtDeath: Int? = nil,
        roles: Set<PersonRole> = [.actor],
        library: Library? = nil,
        genres: [Genre] = [],
        isArchived: Bool = false,
        isPrivate: Bool = false
    ) -> Person {
        let person = Person(firstName: name, lastName: "Test")
        person.roles = roles
        person.library = library
        person.genres = genres
        person.isArchived = isArchived
        person.isPrivate = isPrivate

        // Un défunt : on pose l'âge au décès, et une naissance assez ancienne pour
        // qu'un filtre calculé sur les vivants ne puisse pas le retenir par hasard.
        if let ageAtDeath {
            person.birthDate = birthDate(forAge: ageAtDeath + 30)
            person.deathDate = Calendar.current.date(
                byAdding: .year, value: ageAtDeath, to: person.birthDate ?? Self.reference)
        } else if let age {
            person.birthDate = birthDate(forAge: age)
        }

        person.refreshDerived()
        context.insert(person)
        return person
    }

    private func results(
        _ filter: PersonFilter,
        in context: ModelContext,
        hidingPrivate: Bool = false,
        libraryID: UUID? = nil,
        now: Date? = nil
    ) throws -> [Person] {
        try context.save()
        return try context.fetch(
            FetchDescriptor<Person>(
                predicate: filter.predicate(
                    hidingPrivate: hidingPrivate, libraryID: libraryID, now: now ?? Self.reference),
                sortBy: [SortDescriptor(\.sortName)]
            )
        )
    }

    // MARK: Visibilité

    @Test("Corbeille, archivage et contenu privé se comportent comme sur les titres")
    func visibilityMatchesTitles() throws {
        let context = try makeStore().context
        makePerson(in: context, name: "Visible")
        let trashed = makePerson(in: context, name: "Corbeille")
        trashed.deletedAt = .now
        makePerson(in: context, name: "Archivee", isArchived: true)
        makePerson(in: context, name: "Privee", isPrivate: true)

        #expect(try results(PersonFilter(), in: context, hidingPrivate: true).map(\.firstName) == ["Visible"])

        var filter = PersonFilter()
        filter.showsArchived = true
        let withArchived = try results(filter, in: context, hidingPrivate: true)
        #expect(withArchived.count == 2)
    }

    // MARK: Rôle et genre

    @Test("Le filtre par rôle passe par les clés, pas par le tableau")
    func roleFilterUsesFilterKeys() throws {
        // `roleValues` est un tableau de `String` : SwiftData le persiste en binaire
        // et un `contains` dessus n'est pas traduisible en SQL de façon fiable.
        // C'est toute la raison d'être du jeton de rôle dans `filterKeys`.
        let context = try makeStore().context
        makePerson(in: context, name: "Actrice", roles: [.actor])
        makePerson(in: context, name: "Realisateur", roles: [.director])
        makePerson(in: context, name: "Les deux", roles: [.actor, .director])

        var filter = PersonFilter()
        filter.role = .director
        #expect(try results(filter, in: context).map(\.firstName) == ["Les deux", "Realisateur"])

        filter.role = .social
        #expect(try results(filter, in: context).isEmpty)
    }

    @Test("Le filtre par genre s'applique")
    func genreFilterIsApplied() throws {
        let context = try makeStore().context
        let library = Library(name: "Principale")
        context.insert(library)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Voix", target: .person, in: library)

        makePerson(in: context, name: "Avec", genres: [genre])
        makePerson(in: context, name: "Sans")

        var filter = PersonFilter()
        filter.genreID = genre.id
        #expect(try results(filter, in: context).map(\.firstName) == ["Avec"])
    }

    @Test("La bibliothèque restreint la liste")
    func libraryScopes() throws {
        let context = try makeStore().context
        let mine = Library(name: "La mienne")
        let other = Library(name: "L'autre")
        context.insert(mine)
        context.insert(other)

        makePerson(in: context, name: "Chez moi", library: mine)
        makePerson(in: context, name: "Ailleurs", library: other)

        #expect(try results(PersonFilter(), in: context, libraryID: mine.id).map(\.firstName) == ["Chez moi"])
        #expect(try results(PersonFilter(), in: context, libraryID: nil).count == 2)
    }

    @Test("La recherche ignore les accents et la casse")
    func searchFolds() throws {
        let context = try makeStore().context
        makePerson(in: context, name: "Amélie")

        var filter = PersonFilter()
        filter.searchText = "amelie"
        #expect(try results(filter, in: context).count == 1)
    }

    // MARK: Tranches d'âge

    @Test("Les trois tranches retiennent les vivants attendus")
    func ageBandsSelectLivingPeople() throws {
        let context = try makeStore().context
        makePerson(in: context, name: "Jeune", age: 28)
        makePerson(in: context, name: "Moyen", age: 45)
        makePerson(in: context, name: "Senior", age: 70)

        for (band, expected) in [
            (AgeBand.young, "Jeune"), (.middle, "Moyen"), (.senior, "Senior")
        ] {
            var filter = PersonFilter()
            filter.ageBand = band
            #expect(try results(filter, in: context).map(\.firstName) == [expected], "\(band.label)")
        }
    }

    @Test("Les bornes exactes tombent du bon côté")
    func ageBandBoundaries() throws {
        // 34 et 35 encadrent la frontière jeune/moyen, 55 et 56 celle de moyen/senior.
        // Un décalage d'un an dans le calcul des bornes de naissance ne se verrait
        // nulle part ailleurs.
        let context = try makeStore().context
        makePerson(in: context, name: "A34", age: 34)
        makePerson(in: context, name: "B35", age: 35)
        makePerson(in: context, name: "C55", age: 55)
        makePerson(in: context, name: "D56", age: 56)

        var filter = PersonFilter()
        filter.ageBand = .young
        #expect(try results(filter, in: context).map(\.firstName) == ["A34"])

        filter.ageBand = .middle
        #expect(try results(filter, in: context).map(\.firstName) == ["B35", "C55"])

        filter.ageBand = .senior
        #expect(try results(filter, in: context).map(\.firstName) == ["D56"])
    }

    @Test("Un défunt est classé sur son âge au décès, pas sur celui qu'il aurait")
    func deceasedUseAgeAtDeath() throws {
        // Le cœur de la décision : quelqu'un mort jeune il y a longtemps aurait
        // aujourd'hui l'âge d'un senior. Le filtrer par bornes de naissance le
        // rangerait dans la mauvaise tranche.
        let context = try makeStore().context
        makePerson(in: context, name: "Mort jeune", ageAtDeath: 30)

        var filter = PersonFilter()
        filter.ageBand = .young
        #expect(try results(filter, in: context).map(\.firstName) == ["Mort jeune"])

        // Et il n'apparaît pas chez les seniors, alors que sa date de naissance
        // remonte à assez longtemps pour l'y placer.
        filter.ageBand = .senior
        #expect(try results(filter, in: context).isEmpty)
    }

    @Test("Une tranche demandée exclut les personnes sans date de naissance")
    func ageBandExcludesUnknownBirthDate() throws {
        // Même règle que les bornes de durée sur `Title` : « moins de 35 ans » ne
        // veut pas dire « âge inconnu ».
        let context = try makeStore().context
        makePerson(in: context, name: "Sans date")
        makePerson(in: context, name: "Avec date", age: 28)

        var filter = PersonFilter()
        filter.ageBand = .young
        #expect(try results(filter, in: context).map(\.firstName) == ["Avec date"])

        // Sans tranche demandée, elle réapparaît.
        filter.ageBand = nil
        #expect(try results(filter, in: context).count == 2)
    }

    @Test("Un vivant change de tranche avec le temps, sans une seule écriture")
    func livingPeopleAgeWithoutBeingRewritten() throws {
        // La justification du refus de dénormaliser l'âge, rendue vérifiable.
        //
        // La même personne, la même ligne en base, jamais réécrite : elle est
        // « jeune » à la date de référence et « moyen » douze ans plus tard. Un âge
        // dénormalisé aurait figé la première réponse, et la seconde serait fausse
        // sans que rien ne le signale.
        let context = try makeStore().context
        let person = makePerson(in: context, name: "Vieillissant", age: 30)
        let keysBefore = person.filterKeys
        let updatedBefore = person.updatedAt

        var filter = PersonFilter()
        filter.ageBand = .young
        #expect(try results(filter, in: context).count == 1)

        let twelveYearsLater =
            Calendar.current.date(byAdding: .year, value: 12, to: Self.reference) ?? Self.reference

        #expect(try results(filter, in: context, now: twelveYearsLater).isEmpty)

        filter.ageBand = .middle
        #expect(try results(filter, in: context, now: twelveYearsLater).count == 1)

        // Et rien n'a été réécrit pour ça.
        #expect(person.filterKeys == keysBefore)
        #expect(person.updatedAt == updatedBefore)
    }

    // MARK: Dérivés

    @Test("Les clés couvrent bibliothèque, genres et rôles")
    func filterKeysCoverEverything() throws {
        let context = try makeStore().context
        let library = Library(name: "Principale")
        context.insert(library)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Voix", target: .person, in: library)

        let person = makePerson(
            in: context, name: "Complete", roles: [.actor, .social], library: library, genres: [genre])

        for token in [
            FilterKey.library(library.id), FilterKey.genre(genre.id),
            FilterKey.role(.actor), FilterKey.role(.social)
        ] {
            #expect(person.filterKeys.contains(FilterKey.pattern(token)), "Clé manquante : \(token)")
        }
        #expect(person.filterKeys.contains(FilterKey.pattern(FilterKey.role(.director))) == false)
    }

    @Test("ageAtDeath n'existe que pour les défunts avec une date de naissance")
    func ageAtDeathIsMaintained() throws {
        let context = try makeStore().context

        let living = makePerson(in: context, name: "Vivant", age: 40)
        #expect(living.ageAtDeath == nil)

        let dead = makePerson(in: context, name: "Defunt", ageAtDeath: 62)
        #expect(dead.ageAtDeath == 62)

        // Décès connu, naissance inconnue : l'âge au décès n'est pas calculable, et
        // ne doit pas être inventé.
        let unknownBirth = Person(firstName: "Sans", lastName: "Naissance")
        unknownBirth.deathDate = Self.reference
        unknownBirth.refreshDerived()
        context.insert(unknownBirth)
        #expect(unknownBirth.ageAtDeath == nil)
    }

    @Test("Le prédicat complet est bien traduit en SQL")
    func predicateIsEvaluatedByTheStore() throws {
        // Même garde-fou que pour les titres : un `ModelContext` neuf n'a aucun objet
        // en attente, donc le fetch passe forcément par SQLite. La disjonction
        // vivant/défunt de la tranche d'âge est la construction la plus exotique du
        // projet — c'est ici qu'on vérifie que SwiftData la traduit.
        let store = try makeStore()
        let library = Library(name: "Principale")
        store.context.insert(library)

        makePerson(in: store.context, name: "Retenue", age: 40, roles: [.actor], library: library)
        makePerson(in: store.context, name: "Ecartee", age: 70, roles: [.actor], library: library)
        try store.context.save()

        var filter = PersonFilter()
        filter.ageBand = .middle
        filter.role = .actor
        filter.searchText = "test"

        let fresh = ModelContext(store.container)
        let found = try fresh.fetch(
            FetchDescriptor<Person>(
                predicate: filter.predicate(
                    hidingPrivate: true, libraryID: library.id, now: Self.reference),
                sortBy: [SortDescriptor(\.sortName)]
            )
        )

        #expect(found.map(\.firstName) == ["Retenue"])
    }

    @Test("isActive et clear se comportent comme sur les titres")
    func activeAndClear() {
        var filter = PersonFilter()
        #expect(filter.isActive == false)

        filter.ageBand = .senior
        #expect(filter.isActive)

        filter.clear()
        #expect(filter.isActive == false)
    }
}
