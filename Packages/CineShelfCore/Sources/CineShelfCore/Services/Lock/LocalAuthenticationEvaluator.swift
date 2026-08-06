import Foundation
import LocalAuthentication

/// L'évaluateur réel, adossé à `LocalAuthentication`.
///
/// **`.deviceOwnerAuthentication` et non `...WithBiometrics`**, et c'est la seule ligne de ce
/// fichier qui compte vraiment : la première retombe automatiquement sur le code de l'appareil,
/// la seconde non. Avec `...WithBiometrics`, un utilisateur masqué, gants aux mains, ou dont le
/// Face ID s'est verrouillé après trois échecs se retrouve **enfermé dehors** sans recours —
/// et la seule issue serait de désactiver le réglage, ce qu'il ne peut pas faire puisqu'il ne
/// peut pas entrer. Ne pas « simplifier » vers la variante biométrique.
///
/// **Un `LAContext` neuf par appel.** Un contexte réutilisé garde le résultat de son
/// authentification précédente pendant `touchIDAuthenticationAllowableReuseDuration` : le
/// second appel réussirait sans rien demander, ce qui ferait du verrou une formalité. Le coût
/// d'un contexte neuf est nul comparé à ça.
public struct LocalAuthenticationEvaluator: BiometricEvaluating {

    public init() {}

    public func canEvaluate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    public func biometryKind() -> BiometryKind {
        let context = LAContext()
        var error: NSError?
        // `biometryType` n'est renseigné qu'**après** un `canEvaluatePolicy` : sans cet appel,
        // il vaut `.none` sur un appareil parfaitement équipé.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .none
        }
        return switch context.biometryType {
        case .faceID: .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        default: .none
        }
    }

    public func evaluate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw AuthError.unavailable
        }
        do {
            let granted = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: reason)
            guard granted else { throw AuthError.failed("Authentification refusée") }
        } catch let error as LAError {
            throw Self.mapped(error)
        }
    }

    /// La traduction des erreurs système.
    ///
    /// **`.userFallback` compte comme une annulation.** Il signifie « je veux saisir le code »,
    /// et avec `.deviceOwnerAuthentication` le système enchaîne lui-même sur le clavier : le
    /// traiter comme un échec afficherait un message d'erreur par-dessus une saisie en cours.
    static func mapped(_ error: LAError) -> AuthError {
        switch error.code {
        case .userCancel, .appCancel, .systemCancel, .userFallback: .cancelled
        case .biometryLockout: .lockedOut
        case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet: .unavailable
        default: .failed(error.localizedDescription)
        }
    }
}
