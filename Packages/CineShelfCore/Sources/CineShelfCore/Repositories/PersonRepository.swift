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
}
