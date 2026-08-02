import Foundation
import SwiftData

/// Amorçage au premier lancement : une bibliothèque et un profil, sinon l'app
/// s'ouvre sur un catalogue qui n'existe pas.
@MainActor
public enum Bootstrap {
    public static let defaultProfileName = "Moi"

    /// Garantit une bibliothèque par défaut et un profil qui la consulte.
    ///
    /// Idempotent : cherche l'existant avant d'insérer, donc appelable à chaque
    /// lancement.
    ///
    /// - Returns: le profil par défaut de la bibliothèque par défaut.
    /// - Throws: l'erreur de lecture ou de sauvegarde de SwiftData.
    @discardableResult
    public static func ensureDefaults(
        in context: ModelContext,
        profileName: String = defaultProfileName
    ) throws -> Profile {
        let library = try existingLibrary(in: context) ?? insertDefaultLibrary(in: context)

        if let profile = try existingProfile(of: library, in: context) {
            if context.hasChanges { try context.save() }
            return profile
        }

        let profile = ProfileRepository(context: context).create(name: profileName, in: library, isDefault: true)
        try context.save()
        return profile
    }

    /// La bibliothèque par défaut, à défaut la plus ancienne : sur un appareil
    /// où la sync a déjà rapatrié un catalogue, il n'y a rien à créer.
    private static func existingLibrary(in context: ModelContext) throws -> Library? {
        var byDefault = FetchDescriptor<Library>(predicate: #Predicate { $0.isDefault })
        byDefault.fetchLimit = 1
        if let library = try context.fetch(byDefault).first { return library }

        var anyLibrary = FetchDescriptor<Library>(sortBy: [SortDescriptor(\.createdAt)])
        anyLibrary.fetchLimit = 1
        return try context.fetch(anyLibrary).first
    }

    private static func insertDefaultLibrary(in context: ModelContext) -> Library {
        let library = Library(isDefault: true)
        context.insert(library)
        ActivityRecorder(context: context).record(.create, library)
        return library
    }

    private static func existingProfile(of library: Library, in context: ModelContext) throws -> Profile? {
        if let profile = library.profiles?.min(by: { $0.sortIndex < $1.sortIndex }) {
            return profile
        }
        let libraryID = library.id
        var descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.library?.id == libraryID },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
