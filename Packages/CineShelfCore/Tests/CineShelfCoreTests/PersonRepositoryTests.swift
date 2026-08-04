import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des personnes")
@MainActor
struct PersonRepositoryTests {
    @Test("La création calcule displayName, sortName et searchText")
    func createDerivesNames() throws {
        let (context, library) = try makeTestLibrary()
        let person = PersonRepository(context: context).create(
            firstName: "Agnès",
            lastName: "Varda",
            in: library
        )
        try context.save()

        #expect(person.library?.id == library.id)
        #expect(person.displayName == "Agnès Varda")
        #expect(person.sortName == "varda agnes")
        #expect(person.searchText == "agnes varda")
        #expect(person.roles == [.actor])
    }

    @Test("Les rôles demandés sont posés à la création")
    func createAcceptsRoles() throws {
        let (context, library) = try makeTestLibrary()
        let person = PersonRepository(context: context).create(
            firstName: "Greta",
            lastName: "Gerwig",
            roles: [.director, .writer],
            in: library
        )
        try context.save()

        #expect(person.roleValues == ["director", "writer"])
        #expect(person.isActor == false)
    }

    @Test("La mise à jour rafraîchit les dérivés")
    func updateRefreshesDerivedValues() throws {
        let (context, library) = try makeTestLibrary()
        let repository = PersonRepository(context: context)
        let person = repository.create(firstName: "Jean", lastName: "Renoir", in: library)

        repository.update(person, journal: .perEntity) { updated in
            updated.lastName = "Renoîr"
            updated.bio = "Cinéaste FRANÇAIS"
        }
        try context.save()

        #expect(person.displayName == "Jean Renoîr")
        #expect(person.sortName == "renoir jean")
        #expect(person.searchText == "jean renoir cineaste francais")
    }

    @Test("La suppression est douce, et la restauration la défait")
    func softDeleteAndRestore() throws {
        let (context, library) = try makeTestLibrary()
        let repository = PersonRepository(context: context)
        let person = repository.create(firstName: "Toshiro", lastName: "Mifune", in: library)

        repository.softDelete(person)
        try context.save()
        #expect(person.deletedAt != nil)

        repository.restore(person)
        try context.save()
        #expect(person.deletedAt == nil)
        #expect(try activityCount(in: context, action: .restore) == 1)
    }

    @Test("Ajouter le rôle social ne crée pas une deuxième personne")
    func socialRoleStaysOnTheSamePerson() throws {
        let (context, library) = try makeTestLibrary()
        let repository = PersonRepository(context: context)
        let person = repository.create(firstName: "Zendaya", in: library)

        repository.update(person, journal: .perEntity) { updated in
            updated.roles = updated.roles.union([.social])
        }
        let handle = SocialHandle(platform: "instagram", handle: "zendaya")
        handle.person = person
        context.insert(handle)
        try context.save()

        #expect(person.isActor)
        #expect(person.isSocial)
        #expect(person.handles?.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 1)
    }
}
