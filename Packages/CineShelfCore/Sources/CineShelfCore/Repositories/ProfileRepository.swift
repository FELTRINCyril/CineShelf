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

    /// Une écriture quelconque sur un profil, journalisée.
    ///
    /// **Écrit par `V7`, et il manquait — c'est la classe de défaut de `V4`/`V5b`.**
    /// `requiresBiometry`, `hidesPrivateContent` et `accentRaw` étaient **lus** — le premier par
    /// `PrivacyScope` depuis `L14`, le troisième cinquante-trois fois par le chrome — et
    /// **aucun chemin ne les écrivait**. Trois réglages que l'utilisateur ne pouvait pas
    /// changer, dont deux qui décident de ce qu'il voit.
    public func update(_ profile: Profile, _ mutate: (Profile) -> Void) {
        mutate(profile)
        // **Pas de `refreshDerived()` ici, et ce n'est pas un oubli** : `Profile` n'a aucune
        // valeur dénormalisée — ni `sortName`, ni `searchText`, ni `filterKeys`. Il n'en porte
        // pas parce qu'on ne cherche pas un profil, on le choisit dans une liste de trois.
        ActivityRecorder(context: context).record(.update, profile)
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
