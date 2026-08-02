import Foundation
import SwiftData

/// Écritures sur les profils.
@MainActor
public struct ProfileRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(name: String, in library: Library, isDefault: Bool = false) -> Profile {
        let profile = Profile(name: name, isDefault: isDefault)
        profile.library = library
        context.insert(profile)
        ActivityRecorder(context: context).record(.create, profile)
        return profile
    }

    public func rename(_ profile: Profile, to name: String) {
        profile.name = name
        profile.updatedAt = .now
        ActivityRecorder(context: context).record(.update, profile)
    }

    /// Supprime le profil et ses listes, jamais le catalogue : `Library.profiles`
    /// est en `.nullify`, `Profile.titleFlags` en `.cascade`.
    public func delete(_ profile: Profile) {
        ActivityRecorder(context: context).record(.delete, profile)
        context.delete(profile)
    }

    /// Bascule le profil sur un autre catalogue. Ses listes le suivent, mais
    /// elles pointent vers des titres restés dans l'ancienne bibliothèque : au
    /// transfert d'entités (v1) de décider ce qu'il advient d'elles.
    public func move(_ profile: Profile, to library: Library) {
        profile.library = library
        profile.updatedAt = .now
        ActivityRecorder(context: context).record(.update, profile)
    }
}
