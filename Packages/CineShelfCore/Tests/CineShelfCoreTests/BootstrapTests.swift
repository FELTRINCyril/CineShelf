import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Amorçage au premier lancement")
@MainActor
struct BootstrapTests {
    @Test("Sur une base vide, une bibliothèque et un profil sont créés")
    func emptyStoreGetsDefaults() throws {
        let context = ModelContext(try makeTestContainer())
        let profile = try Bootstrap.ensureDefaults(in: context)

        #expect(profile.name == Bootstrap.defaultProfileName)
        #expect(profile.isDefault)
        #expect(profile.library?.isDefault == true)
        #expect(try context.fetchCount(FetchDescriptor<Library>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 1)
        #expect(context.hasChanges == false)
    }

    @Test("Deux appels de suite ne créent rien de plus")
    func secondCallIsIdempotent() throws {
        let context = ModelContext(try makeTestContainer())
        let first = try Bootstrap.ensureDefaults(in: context)
        let second = try Bootstrap.ensureDefaults(in: context)

        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<Library>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 1)
    }

    @Test("Une bibliothèque existante est réutilisée, pas doublée")
    func existingLibraryIsReused() throws {
        let (context, library) = try makeTestLibrary()
        let profile = try Bootstrap.ensureDefaults(in: context)

        #expect(profile.library?.id == library.id)
        #expect(try context.fetchCount(FetchDescriptor<Library>()) == 1)
    }

    @Test("Une bibliothèque sans profil reçoit le profil manquant")
    func libraryWithoutProfileGetsOne() throws {
        let (context, library) = try makeTestLibrary()
        TitleRepository(context: context).create(name: "Playtime", in: library)
        try context.save()

        let profile = try Bootstrap.ensureDefaults(in: context)

        #expect(profile.library?.id == library.id)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
    }

    @Test("Un profil existant est conservé, avec son nom")
    func existingProfileIsKept() throws {
        let (context, library) = try makeTestLibrary()
        let existing = ProfileRepository(context: context).create(name: "Cyril", in: library, isDefault: true)
        try context.save()

        let profile = try Bootstrap.ensureDefaults(in: context)

        #expect(profile.id == existing.id)
        #expect(profile.name == "Cyril")
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 1)
    }

    @Test("Une bibliothèque non marquée par défaut est adoptée telle quelle")
    func nonDefaultLibraryIsAdopted() throws {
        let context = ModelContext(try makeTestContainer())
        let library = Library(name: "Importée", isDefault: false)
        context.insert(library)
        try context.save()

        let profile = try Bootstrap.ensureDefaults(in: context)

        #expect(profile.library?.id == library.id)
        #expect(try context.fetchCount(FetchDescriptor<Library>()) == 1)
    }
}
