import CineShelfCore
import DesignSystem
import Observation
import SwiftUI

/// Le profil actif et la mémoire du dernier profil ouvert.
///
/// Séparé de `NavigationModel` : la navigation change à chaque écran, le profil
/// une fois par session. Les mélanger obligerait à réécrire l'état de
/// navigation à chaque bascule de profil.
///
/// Vit dans `App/Navigation/` et non dans `Features/Settings/` : la barre
/// latérale et l'onglet « Plus » s'en servent tous les deux, et `docs/04` §1
/// interdit qu'une feature en importe une autre.
@MainActor
@Observable
final class ProfileSession {

    /// Le profil actif. `nil` tant que le sélecteur n'a pas tranché.
    private(set) var current: Profile?

    /// Mémorisé hors SwiftData : on doit pouvoir le lire avant d'ouvrir quoi
    /// que ce soit, et il est propre à cette machine — deux Mac synchronisés
    /// n'ont pas à rouvrir le même profil.
    private let defaults: UserDefaults
    private static let lastProfileKey = "profile.last"
    private static let opensLastKey = "profile.opensLastDirectly"

    /// Les profils disponibles, alimentés par `RootView` qui a le `@Query`.
    /// Les commandes de la barre de menus n'ont pas accès à SwiftData : c'est
    /// par ici qu'elles apprennent sur quoi porte ⌃⌘1…9.
    var available: [Profile] = []

    /// « Ouvrir directement le dernier profil » — le réglage du sélecteur.
    ///
    /// Propriété **stockée**, pas calculée sur `UserDefaults` : `@Observable`
    /// n'instrumente que les propriétés stockées, et un `Toggle` lié à une
    /// propriété calculée écrirait bien la valeur sans jamais rafraîchir la vue.
    var opensLastProfileDirectly: Bool {
        didSet { defaults.set(opensLastProfileDirectly, forKey: Self.opensLastKey) }
    }

    private(set) var lastProfileID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.opensLastProfileDirectly = defaults.bool(forKey: Self.opensLastKey)
        self.lastProfileID = defaults.string(forKey: Self.lastProfileKey).flatMap(UUID.init(uuidString:))
    }

    /// La teinte de l'app suit le profil : `Profile.accentToken` porte un nom de
    /// jeu sémantique, résolu par le design system. Repli sur l'accent par
    /// défaut si le jeu n'existe pas — un profil ne doit pas casser l'app.
    var accentColor: Color {
        guard let token = current?.accentToken,
            let color = ColorTokens.typedAccessor(for: token)
        else { return .accentText }
        return color
    }

    // MARK: Ouverture

    func open(_ profile: Profile) {
        current = profile
        lastProfileID = profile.id
        defaults.set(profile.id.uuidString, forKey: Self.lastProfileKey)
    }

    /// Le profil à ouvrir sans rien demander, s'il y en a un.
    ///
    /// Un seul profil : pas de sélecteur, il n'y a rien à choisir. Sinon, le
    /// dernier ouvert, à condition que l'utilisateur l'ait demandé.
    func profileToOpenDirectly(among profiles: [Profile]) -> Profile? {
        if profiles.count == 1 { return profiles.first }
        guard opensLastProfileDirectly, let lastProfileID else { return nil }
        return profiles.first { $0.id == lastProfileID }
    }

    /// Les profils dans l'ordre d'affichage — celui de ⌃⌘1…9.
    var ordered: [Profile] {
        available.sorted { $0.sortIndex < $1.sortIndex }
    }
}
