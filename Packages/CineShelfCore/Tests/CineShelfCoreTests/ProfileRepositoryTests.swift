import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Repository des profils")
@MainActor
struct ProfileRepositoryTests {
    @Test("La création rattache le profil à la bibliothèque")
    func createAttachesToLibrary() throws {
        let (context, library) = try makeTestLibrary()
        let profile = ProfileRepository(context: context).create(name: "Cyril", in: library, isDefault: true)
        try context.save()

        #expect(profile.library?.id == library.id)
        #expect(profile.isDefault)
        #expect(library.profiles?.count == 1)
        #expect(profile.avatarSymbol == "person.crop.circle")
    }

    @Test("Renommer touche updatedAt et journalise")
    func renameTouchesUpdatedAt() throws {
        let (context, library) = try makeTestLibrary()
        let repository = ProfileRepository(context: context)
        let profile = repository.create(name: "Invite", in: library)
        let before = profile.updatedAt

        repository.rename(profile, to: "Invité")
        try context.save()

        #expect(profile.name == "Invité")
        #expect(profile.updatedAt > before)
        #expect(try activityCount(in: context, action: .update) == 1)
    }

    @Test("Supprimer un profil efface ses listes, jamais le catalogue")
    func deleteKeepsTheCatalog() throws {
        let (context, library) = try makeTestLibrary()
        let profile = ProfileRepository(context: context).create(name: "Invité", in: library)
        let title = TitleRepository(context: context).create(name: "Brazil", in: library)
        FlagRepository(context: context, profile: profile).toggleFavorite(title)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TitleFlag>()) == 1)

        ProfileRepository(context: context).delete(profile)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TitleFlag>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
        #expect(title.deletedAt == nil)
    }

    @Test("Changer de bibliothèque isole le profil de l'ancien catalogue")
    func moveChangesLibrary() throws {
        let (context, library) = try makeTestLibrary()
        let sandbox = Library(name: "Bac à sable")
        context.insert(sandbox)
        let repository = ProfileRepository(context: context)
        let profile = repository.create(name: "Test", in: library)
        try context.save()

        repository.move(profile, to: sandbox)
        try context.save()

        #expect(profile.library?.id == sandbox.id)
        #expect(library.profiles?.isEmpty == true)
        #expect(sandbox.profiles?.count == 1)
    }

    @Test("Deux profils sur la même bibliothèque partagent le catalogue")
    func twoProfilesShareOneLibrary() throws {
        let (context, library) = try makeTestLibrary()
        let repository = ProfileRepository(context: context)
        repository.create(name: "Cyril", in: library, isDefault: true)
        repository.create(name: "Invité", in: library)
        try context.save()

        #expect(library.profiles?.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Library>()) == 1)
    }
}
