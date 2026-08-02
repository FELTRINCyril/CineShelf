import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Flags par profil")
@MainActor
struct FlagRepositoryTests {
    /// Bibliothèque, profil et titre insérés dans un magasin volatil.
    @MainActor
    private struct Fixture {
        let context: ModelContext
        let profile: Profile
        let title: Title

        var repository: FlagRepository {
            FlagRepository(context: context, profile: profile)
        }

        func flagCount() throws -> Int {
            try context.fetchCount(FetchDescriptor<TitleFlag>())
        }
    }

    private func makeFixture() throws -> Fixture {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let library = Library(name: "Principal", isDefault: true)
        let profile = Profile(name: "Cyril", isDefault: true)
        profile.library = library
        let title = Title(name: "Solaris")
        title.library = library

        context.insert(library)
        context.insert(profile)
        context.insert(title)
        try context.save()

        return Fixture(context: context, profile: profile, title: title)
    }

    @Test("Aucun flag n'est créé tant qu'on ne le demande pas")
    func flagIsNotCreatedByDefault() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository

        #expect(repository.flag(for: fixture.title) == nil)
        #expect(try fixture.flagCount() == 0)
    }

    @Test("Mettre en favori crée le flag du profil")
    func togglingFavoriteCreatesTheFlag() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository

        repository.toggleFavorite(fixture.title)
        try fixture.context.save()

        let flag = repository.flag(for: fixture.title)
        #expect(flag?.isFavorite == true)
        #expect(flag?.profile?.id == fixture.profile.id)
        #expect(try fixture.flagCount() == 1)
    }

    @Test("Un flag repassé à isEmpty est supprimé")
    func emptyFlagIsDeleted() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository

        repository.toggleFavorite(fixture.title)
        try fixture.context.save()
        #expect(try fixture.flagCount() == 1)

        repository.toggleFavorite(fixture.title)
        try fixture.context.save()

        #expect(try fixture.flagCount() == 0)
        #expect(repository.flag(for: fixture.title) == nil)
    }

    @Test("Un flag qui porte encore une information survit au retrait du favori")
    func flagSurvivesWhenItStillCarriesInformation() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository

        repository.toggleFavorite(fixture.title)
        let flag = try #require(repository.flag(for: fixture.title))
        flag.isInWatchlist = true
        try fixture.context.save()

        repository.toggleFavorite(fixture.title)
        try fixture.context.save()

        #expect(try fixture.flagCount() == 1)
        #expect(repository.flag(for: fixture.title)?.isFavorite == false)
        #expect(repository.flag(for: fixture.title)?.isInWatchlist == true)
    }

    @Test("Deux profils sur la même bibliothèque ont des listes séparées")
    func twoProfilesKeepSeparateLists() throws {
        let fixture = try makeFixture()
        let guest = Profile(name: "Invité")
        guest.library = fixture.profile.library
        fixture.context.insert(guest)
        try fixture.context.save()

        fixture.repository.toggleFavorite(fixture.title)
        try fixture.context.save()

        #expect(fixture.repository.flag(for: fixture.title)?.isFavorite == true)
        #expect(FlagRepository(context: fixture.context, profile: guest).flag(for: fixture.title) == nil)
        #expect(try fixture.flagCount() == 1)
    }
}
