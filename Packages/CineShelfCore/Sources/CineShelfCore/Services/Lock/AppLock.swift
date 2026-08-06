import Foundation
import Observation

// MARK: - L14 · Le verrou d'interface
//
// **Un verrou d'interface, pas du chiffrement**, et `docs/02` §9.4 le dit sans détour : le
// magasin sur disque est protégé par la protection de fichiers du système, pas par Face ID. Ce
// que ça empêche est qu'on fouille dans un appareil déverrouillé posé sur une table. Écrire
// ici « données protégées » serait une promesse fausse.
//
// **L'authentification passe par un protocole**, comme la fiche l'exige : aucun test ne peut
// invoquer Face ID, donc l'évaluateur est injecté. Le vrai vit dans `LocalAuthenticationEvaluator`.

/// Le type de biométrie disponible sur l'appareil.
public enum BiometryKind: String, Sendable, Equatable {
    case faceID, touchID, opticID, none
}

/// Pourquoi une authentification n'a pas abouti.
public enum AuthError: Error, Sendable, Equatable {
    /// L'utilisateur a annulé. **Pas une erreur à signaler** : il a répondu, et sa réponse est
    /// non. Un message d'échec ici accuserait l'utilisateur d'un geste délibéré.
    case cancelled
    /// Ni biométrie ni code sur l'appareil. Le réglage doit alors se désactiver en le disant,
    /// pas laisser croire à une protection.
    case unavailable
    /// Trop d'échecs : le système exige le code de l'appareil.
    case lockedOut
    case failed(String)
}

/// Ce qu'un évaluateur d'authentification sait faire.
///
/// **Trois méthodes et pas une de plus.** La frontière est étroite exprès : tout ce qui n'est
/// pas « l'appareil peut-il authentifier » et « authentifie » appartient à `AppLock`, donc est
/// testable sans dépendance système.
public protocol BiometricEvaluating: Sendable {
    /// L'appareil peut-il authentifier, biométrie **ou** code ?
    func canEvaluate() -> Bool
    /// Le type de biométrie, quand il y en a une.
    func biometryKind() -> BiometryKind
    /// Demande l'authentification. Lève une `AuthError`.
    func evaluate(reason: String) async throws
}

/// Le délai avant qu'un retour d'arrière-plan reverrouille.
///
/// **Configurable, et c'est une exigence de la fiche, pas un confort.** Sans délai, l'app
/// redemande Face ID chaque fois qu'on change d'app deux secondes — et le réglage finit
/// désactivé, donc la protection avec lui. Un verrou qu'on désactive protège moins qu'un
/// verrou tolérant.
public enum LockGrace: Int, Sendable, CaseIterable, Codable, Identifiable {
    case immediate = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue) }

    public var label: String {
        switch self {
        case .immediate: "Immédiat"
        case .oneMinute: "Après 1 minute"
        case .fiveMinutes: "Après 5 minutes"
        case .fifteenMinutes: "Après 15 minutes"
        }
    }
}

/// Ce que l'app doit faire d'un changement de phase de scène.
///
/// **Un type pur et nonisolé, hors de toute vue.** `View` est `@MainActor`, donc une décision
/// écrite dans un `onChange` ne se teste pas — et c'est exactement l'arithmétique qu'on veut
/// assener sur des instants quelconques. `AppLock` l'applique, `LockPolicy` la calcule.
public enum LockPolicy {

    /// Les phases de scène, redéclarées ici parce que `CineShelfCore` n'importe pas SwiftUI.
    public enum Phase: Sendable, Equatable { case active, inactive, background }

    /// Ce qu'il faut faire.
    public struct Decision: Sendable, Equatable {
        /// Poser l'écran de confidentialité par-dessus l'interface.
        public let showsPrivacyCover: Bool
        /// Reverrouiller.
        public let locks: Bool
        /// Mémoriser l'instant de mise en arrière-plan, pour le prochain retour.
        public let recordsBackgroundInstant: Bool
    }

    /// - Parameters:
    ///   - phase: la phase atteinte.
    ///   - isEnabled: le verrou d'app est-il activé (réglage local à l'appareil).
    ///   - grace: le délai de grâce configuré.
    ///   - backgroundedAt: quand l'app est passée en arrière-plan, si elle y est passée.
    ///   - now: l'instant du retour.
    /// - Returns: ce qu'il faut faire — poser le voile, reverrouiller, mémoriser l'instant.
    ///
    /// **L'écran de confidentialité se pose dès `.inactive`, pas à `.background`**, et c'est le
    /// détail qu'on oublie : iOS prend la vignette du sélecteur d'apps **pendant** `.inactive`.
    /// Attendre `.background` la laisse capturer le catalogue en clair, et la vignette reste
    /// visible ensuite à qui ouvre le sélecteur.
    public static func decide(
        phase: Phase,
        isEnabled: Bool,
        grace: LockGrace,
        backgroundedAt: Date?,
        now: Date
    ) -> Decision {
        switch phase {
        case .inactive:
            return Decision(
                showsPrivacyCover: isEnabled, locks: false, recordsBackgroundInstant: false)
        case .background:
            // Le voile reste posé : on revient toujours par `.inactive`, mais compter dessus
            // ferait clignoter l'interface si l'ordre changeait.
            return Decision(
                showsPrivacyCover: isEnabled, locks: false, recordsBackgroundInstant: true)
        case .active:
            guard isEnabled, let backgroundedAt else {
                return Decision(
                    showsPrivacyCover: false, locks: false, recordsBackgroundInstant: false)
            }
            // **`>=` et non `>`.** Sur « immédiat », le délai vaut zéro : avec `>`, un retour
            // instantané donnerait un écart de zéro seconde, qui n'est pas strictement
            // supérieur — et « immédiat » ne verrouillerait jamais. Le cas dégénéré est
            // précisément celui que le réglage nomme.
            let elapsed = now.timeIntervalSince(backgroundedAt)
            return Decision(
                showsPrivacyCover: false, locks: elapsed >= grace.seconds,
                recordsBackgroundInstant: false)
        }
    }
}

/// L'état du verrou, et le seul objet qui décide s'il est ouvert.
@MainActor
@Observable
public final class AppLock {

    /// L'app a-t-elle été déverrouillée dans cette session.
    ///
    /// **`false` au démarrage, toujours.** Un verrou qui s'ouvre tout seul au lancement n'est
    /// pas un verrou ; c'est `isEnabled` qui décide si on demande, pas cet état.
    public private(set) var isUnlocked = false

    /// Ce que l'appareil sait faire. `.none` tant que `refreshCapability()` n'a pas été appelé.
    public private(set) var biometry: BiometryKind = .none

    /// L'appareil peut-il authentifier du tout — biométrie ou code.
    public private(set) var canAuthenticate = false

    /// Le dernier échec, pour que l'écran de `V7` puisse le dire.
    public private(set) var lastError: AuthError?

    private let evaluator: any BiometricEvaluating

    public init(evaluator: any BiometricEvaluating) {
        self.evaluator = evaluator
    }

    /// Relit ce que l'appareil sait faire.
    ///
    /// À appeler au lancement et à chaque retour au premier plan : la biométrie peut devenir
    /// indisponible entre deux — code retiré, verrouillage après échecs.
    public func refreshCapability() {
        canAuthenticate = evaluator.canEvaluate()
        biometry = canAuthenticate ? evaluator.biometryKind() : .none
    }

    /// Demande l'authentification.
    ///
    /// **Ne lève pas, et c'est délibéré** : l'appelant est une vue, et le seul état qui
    /// l'intéresse est « ouvert ou pas ». Le motif d'échec vit dans `lastError`, où l'écran
    /// peut le lire sans écrire un `do/catch` par bouton.
    ///
    /// - Returns: `true` si l'app est désormais déverrouillée.
    @discardableResult
    public func authenticate(reason: String) async -> Bool {
        lastError = nil
        guard evaluator.canEvaluate() else {
            // **On ne déverrouille pas quand l'appareil ne sait pas authentifier.** La tentation
            // inverse — « pas de biométrie, donc on laisse passer » — transformerait un appareil
            // sans code en passe-partout. Le réglage doit se désactiver en le disant ; c'est
            // `canAuthenticate` qui le porte, et l'écran de `V7` qui le montre.
            lastError = .unavailable
            canAuthenticate = false
            return false
        }
        do {
            try await evaluator.evaluate(reason: reason)
            isUnlocked = true
            return true
        } catch let error as AuthError {
            lastError = error
            return false
        } catch {
            lastError = .failed(error.localizedDescription)
            return false
        }
    }

    public func lock() {
        isUnlocked = false
    }

    /// La portée de confidentialité du profil donné, **à l'état de verrou courant**.
    ///
    /// C'est le point d'entrée unique que `PrivacyScope` existe pour offrir : un écran demande
    /// ici, jamais à `Profile` directement.
    public func scope(for profile: Profile?) -> PrivacyScope {
        PrivacyScope.resolve(profile: profile, isUnlocked: isUnlocked)
    }
}
