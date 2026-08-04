import Foundation
import SwiftData

/// Écritures sur les personnes : acteurs, réalisateurs, comptes sociaux.
@MainActor
public struct PersonRepository {
    let context: ModelContext
    /// Synchronisée après chaque écriture — voir `TitleRepository.spotlight`.
    let spotlight: SpotlightIndexer

    public init(
        context: ModelContext,
        spotlight: SpotlightIndexer = SpotlightConfiguration.indexer
    ) {
        self.context = context
        self.spotlight = spotlight
    }

    @discardableResult
    public func create(
        firstName: String,
        lastName: String = "",
        roles: Set<PersonRole> = [.actor],
        in library: Library
    ) -> Person {
        let person = Person(firstName: firstName, lastName: lastName)
        person.roles = roles
        person.library = library
        person.refreshDerived()
        context.insert(person)
        ActivityRecorder(context: context).record(.create, person)
        spotlight.sync(person)
        return person
    }

    public func update(
        _ person: Person,
        journal: JournalPolicy = .perEntity,
        _ mutate: (Person) -> Void
    ) {
        mutate(person)
        person.refreshDerived()
        if journal == .perEntity {
            ActivityRecorder(context: context).record(.update, person)
        }
        spotlight.sync(person)
    }

    public func softDelete(_ person: Person) {
        person.deletedAt = .now
        person.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, person)
        spotlight.sync(person)
    }

    public func restore(_ person: Person) {
        person.deletedAt = nil
        person.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, person)
        spotlight.sync(person)
    }

    // MARK: Relations
    //
    // Mêmes raisons que sur `TitleRepository` : `Person.filterKeys` dénormalise la
    // bibliothèque, les genres et les rôles pour les rendre interrogeables. Une
    // relation écrite sans `refreshDerived()` rend le filtre correspondant faux en
    // silence. La règle `no_relation_write_outside_core` interdit les autres portes.

    public func setGenres(
        _ genres: [Genre],
        on person: Person,
        journal: JournalPolicy = .perEntity
    ) {
        update(person, journal: journal) { $0.genres = genres }
    }

    public func setRoles(
        _ roles: Set<PersonRole>,
        on person: Person,
        journal: JournalPolicy = .perEntity
    ) {
        update(person, journal: journal) { $0.roles = roles }
    }

    public func move(_ person: Person, to library: Library) {
        update(person) { $0.library = library }
    }
}
