import Foundation
import SwiftData

/// Écritures sur les personnes : acteurs, réalisateurs, comptes sociaux.
@MainActor
public struct PersonRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
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
        return person
    }

    public func update(_ person: Person, _ mutate: (Person) -> Void) {
        mutate(person)
        person.refreshDerived()
        ActivityRecorder(context: context).record(.update, person)
    }

    public func softDelete(_ person: Person) {
        person.deletedAt = .now
        person.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, person)
    }

    public func restore(_ person: Person) {
        person.deletedAt = nil
        person.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, person)
    }

    // MARK: Relations
    //
    // Mêmes raisons que sur `TitleRepository` : `Person.filterKeys` dénormalise la
    // bibliothèque, les genres et les rôles pour les rendre interrogeables. Une
    // relation écrite sans `refreshDerived()` rend le filtre correspondant faux en
    // silence. La règle `no_relation_write_outside_core` interdit les autres portes.

    public func setGenres(_ genres: [Genre], on person: Person) {
        update(person) { $0.genres = genres }
    }

    public func setRoles(_ roles: Set<PersonRole>, on person: Person) {
        update(person) { $0.roles = roles }
    }

    public func move(_ person: Person, to library: Library) {
        update(person) { $0.library = library }
    }
}
