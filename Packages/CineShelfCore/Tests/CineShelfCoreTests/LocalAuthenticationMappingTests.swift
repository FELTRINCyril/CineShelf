import Foundation
import LocalAuthentication
import Testing

@testable import CineShelfCore

// MARK: - L14 · La traduction des erreurs du système
//
// **C'est la surface de risque réelle de `L14`** : une erreur mal traduite enferme dehors un
// utilisateur légitime, ou en laisse entrer un autre. Elle était jusqu'ici écrite contre la
// documentation d'Apple, jamais contre le système.
//
// **Ce que le simulateur a permis de vérifier, et ce qu'il n'a pas permis.** Mesuré le
// 2026-08-06 sur iPhone 17, iOS 26.5, biométrie inscrite par
// `notifyutil -s com.apple.BiometricKit.enrollmentChanged 1` :
//
// | Ce qui a été joué | Résultat réel |
// |---|---|
// | `canEvaluate()` | ✅ `true` — le vrai `LAContext`, pas un factice |
// | `biometryKind()` | ✅ `.faceID` — et ça **valide le détail non évident** : `biometryType` n'est renseigné qu'après `canEvaluatePolicy`, sans lui il vaut `.none` sur un appareil équipé |
// | `evaluate` sans réponse | ✅ `.cancelled` |
// | `evaluate` + `fingerTouch.nomatch` | ✅ `.failed("Échec d'authentification.")` |
// | `evaluate` + `pearl.match` | ✅ `.failed("L'authentification a expiré.")` |
// | **un succès** | ❌ **non reproductible sans app hôte** — le dialogue attend indéfiniment, la commande a été tuée à 170 s. Il faudra l'écran de `V7` et une app au premier plan |
// | `.lockedOut` | ❌ non atteint — demande cinq échecs consécutifs pilotés |
//
// Les trois lignes vertes prouvent que le chemin **atteint le système** et que la traduction
// rend des `AuthError` et non des erreurs brutes. Ce qu'elles ne prouvent pas est la
// correspondance code par code : c'est ce que ce fichier assène, sur de **vrais `LAError`**.

@Suite("Traduction des erreurs d'authentification")
struct LocalAuthenticationMappingTests {

    /// **Une annulation n'est pas un échec**, et les quatre codes qui la disent doivent tomber
    /// au même endroit. `.userFallback` en fait partie et c'est le moins évident : il signifie
    /// « je veux saisir le code », et avec `.deviceOwnerAuthentication` le système enchaîne
    /// lui-même sur le clavier. Le traiter en échec afficherait une erreur par-dessus une
    /// saisie en cours.
    @Test("Les quatre formes d'annulation donnent .cancelled")
    func cancellations() {
        for code in [
            LAError.Code.userCancel, .appCancel, .systemCancel, .userFallback
        ] {
            #expect(
                LocalAuthenticationEvaluator.mapped(LAError(code)) == .cancelled,
                "\(code)")
        }
    }

    /// **`.lockedOut` doit rester distinct d'un simple échec.** L'écran de `V7` en dépend : sur
    /// un verrouillage, le message utile est « saisis ton code », pas « réessaie » — réessayer
    /// ne peut plus rien donner.
    @Test("Le verrouillage biométrique a son propre cas")
    func lockout() {
        #expect(LocalAuthenticationEvaluator.mapped(LAError(.biometryLockout)) == .lockedOut)
    }

    /// **Trois codes disent « cet appareil ne peut pas », et ils ne sont pas interchangeables
    /// avec un échec.** `passcodeNotSet` est le plus important : sans code d'appareil, il n'y a
    /// aucune protection à offrir, et le réglage doit se désactiver en le disant plutôt que de
    /// laisser croire à un verrou.
    @Test("L'indisponibilité couvre les trois codes du système")
    func unavailable() {
        for code in [
            LAError.Code.biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet
        ] {
            #expect(
                LocalAuthenticationEvaluator.mapped(LAError(code)) == .unavailable,
                "\(code)")
        }
    }

    /// Le reste retombe sur `.failed`, en **conservant le message du système**.
    ///
    /// **Vérifié sur un code non traité explicitement** : `authenticationFailed`, celui que le
    /// simulateur rend sur une non-correspondance. Sans cette branche, il tomberait dans un des
    /// cas ci-dessus et l'utilisateur verrait « appareil incompatible » sur une simple erreur
    /// de visage.
    @Test("Les autres codes deviennent .failed, avec le message du système")
    func otherCodesKeepTheirMessage() {
        let error = LAError(.authenticationFailed)
        let mapped = LocalAuthenticationEvaluator.mapped(error)
        guard case .failed(let message) = mapped else {
            Issue.record("Attendu .failed, obtenu \(mapped)")
            return
        }
        #expect(message.isEmpty == false)
        #expect(message == error.localizedDescription)
    }

    /// **Aucun code ne doit tomber dans un cas qui ouvrirait le verrou.** Le balayage exhaustif
    /// existe pour ça : une future version d'iOS peut ajouter un code, et le seul comportement
    /// acceptable par défaut est « ça n'ouvre pas ».
    @Test("Aucun code du système ne se traduit en succès")
    func noCodeUnlocks() {
        let codes: [LAError.Code] = [
            .authenticationFailed, .userCancel, .userFallback, .systemCancel, .passcodeNotSet,
            .appCancel, .invalidContext, .notInteractive, .biometryNotAvailable,
            .biometryNotEnrolled, .biometryLockout
        ]
        // `mapped` rend toujours une `AuthError` : il n'existe aucun chemin par lequel une
        // erreur devienne une réussite. Le test le dit en toutes lettres pour que l'ajout d'un
        // cas « on laisse passer » se voie en revue.
        for code in codes {
            let mapped = LocalAuthenticationEvaluator.mapped(LAError(code))
            #expect(
                [.cancelled, .lockedOut, .unavailable].contains(mapped)
                    || {
                        guard case .failed = mapped else { return false }
                        return true
                    }(),
                "\(code) tombe hors des cas connus")
        }
    }
}
