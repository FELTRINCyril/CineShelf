import Foundation
import Testing

@testable import CineShelfCore

// MARK: - L14 · Le verrou, et la portée qu'il décide
//
// **Deux crans de rigueur dans un seul fichier, et le classement le dit** : `L14` est légère
// **sauf la portée du déverrouillage**. Les tests de `PrivacyScope` sont donc les plus assenés
// du lot — un contenu privé visible dans un profil qui ne devrait pas le voir est la seule
// erreur non réparable ici. On ne peut pas défaire le fait que quelqu'un l'a vu.

/// Un évaluateur factice : la frontière que la fiche exige, parce qu'aucun test ne peut
/// invoquer Face ID.
private struct FakeEvaluator: BiometricEvaluating {
    var available = true
    var kind: BiometryKind = .faceID
    var outcome: Result<Void, AuthError> = .success(())

    func canEvaluate() -> Bool { available }
    func biometryKind() -> BiometryKind { kind }
    func evaluate(reason: String) async throws {
        if case .failure(let error) = outcome { throw error }
    }
}

// MARK: - La portée — la partie à rigueur maximale

@Suite("Portée de confidentialité")
@MainActor
struct PrivacyScopeTests {

    private func profile(
        requiresBiometry: Bool = false, hidesPrivate: Bool = false
    ) -> Profile {
        let profile = Profile(name: "Sonde")
        profile.requiresBiometry = requiresBiometry
        profile.hidesPrivateContent = hidesPrivate
        return profile
    }

    /// **Le repli, et il masque.** Neuf écrans écrivaient
    /// `session.current?.hidesPrivateContent ?? false` : en l'absence de profil, ils
    /// **montraient** le contenu privé. Ce n'est pas atteignable aujourd'hui — `RootView` pose
    /// le sélecteur tant que `current` est `nil` — mais c'est un invariant tenu à distance, par
    /// un `if` dans un autre fichier, que rien ne rappelle au prochain écran.
    @Test("Aucun profil actif masque le contenu privé")
    func noProfileMasks() {
        #expect(PrivacyScope.resolve(profile: nil, isUnlocked: false).hidesPrivateContent)
        // **Et même déverrouillé** : le verrou dit qui est devant l'appareil, pas qui a choisi
        // un profil. Les deux questions sont indépendantes.
        #expect(PrivacyScope.resolve(profile: nil, isUnlocked: true).hidesPrivateContent)
        #expect(PrivacyScope.masked.hidesPrivateContent)
    }

    /// **L'écart que la fiche nomme se ferme ici** : « `requiresBiometry` est affiché mais
    /// jamais appliqué aujourd'hui ». Un réglage qui ne fait rien est pire qu'un réglage absent.
    @Test("Un profil qui exige l'authentification masque tant que l'app est verrouillée")
    func biometryProfileMasksWhileLocked() {
        let guarded = profile(requiresBiometry: true, hidesPrivate: false)
        #expect(PrivacyScope.resolve(profile: guarded, isUnlocked: false).hidesPrivateContent)
        #expect(PrivacyScope.resolve(profile: guarded, isUnlocked: true).hidesPrivateContent == false)
    }

    /// Le réglage explicite est **indépendant du verrou** : un profil « Invité » masque même
    /// dans une app déverrouillée. Sans ce test, on pourrait croire que déverrouiller ouvre
    /// tout.
    @Test("Un profil qui masque le privé masque même déverrouillé")
    func hidingProfileMasksEvenUnlocked() {
        let guest = profile(requiresBiometry: false, hidesPrivate: true)
        #expect(PrivacyScope.resolve(profile: guest, isUnlocked: true).hidesPrivateContent)
        #expect(PrivacyScope.resolve(profile: guest, isUnlocked: false).hidesPrivateContent)
    }

    /// **La seule combinaison qui montre**, et il faut la nommer : sans elle, un test qui
    /// vérifie « ça masque » passerait avec une implémentation qui masque **toujours**.
    @Test("Un profil permissif dans une app déverrouillée est la seule combinaison qui montre")
    func onlyOneCombinationShows() {
        let open = profile(requiresBiometry: false, hidesPrivate: false)
        #expect(PrivacyScope.resolve(profile: open, isUnlocked: true).hidesPrivateContent == false)
    }

    /// La table complète des huit combinaisons — profil présent ou non, deux drapeaux, deux
    /// états de verrou. **Exhaustive exprès** : c'est la porte du privé, et une combinaison
    /// oubliée est une fuite qui ne se répare pas.
    @Test("Les huit combinaisons, en toutes lettres")
    func fullTruthTable() {
        var shown: [String] = []
        for requires in [false, true] {
            for hides in [false, true] {
                for unlocked in [false, true] {
                    let scope = PrivacyScope.resolve(
                        profile: profile(requiresBiometry: requires, hidesPrivate: hides),
                        isUnlocked: unlocked)
                    let expected = hides || (requires && !unlocked)
                    #expect(
                        scope.hidesPrivateContent == expected,
                        "requires=\(requires) hides=\(hides) unlocked=\(unlocked)")
                    if !scope.hidesPrivateContent {
                        shown.append("requires=\(requires) hides=\(hides) unlocked=\(unlocked)")
                    }
                }
            }
        }
        // **Trois cas sur huit montrent**, et ils sont énumérés plutôt que comptés : la
        // première rédaction de ce test annonçait deux, par erreur de ma part, et le test a
        // attrapé le compte faux. C'est un bon signe — l'assertion travaille — mais un nombre
        // nu ne dit pas *lesquels*, donc le prochain qui la verrait rougir ne saurait pas si
        // c'est le code ou le compte qui a bougé.
        #expect(
            shown == [
                "requires=false hides=false unlocked=false",
                "requires=false hides=false unlocked=true",
                "requires=true hides=false unlocked=true"
            ])
    }
}

// MARK: - Le verrou

@Suite("Verrou d'application")
@MainActor
struct AppLockTests {

    @Test("Le verrou est fermé au démarrage")
    func startsLocked() {
        #expect(AppLock(evaluator: FakeEvaluator()).isUnlocked == false)
    }

    @Test("Une authentification acceptée ouvre le verrou")
    func successUnlocks() async {
        let lock = AppLock(evaluator: FakeEvaluator())
        #expect(await lock.authenticate(reason: "Déverrouiller") == true)
        #expect(lock.isUnlocked)
        #expect(lock.lastError == nil)
    }

    @Test("Une annulation ne déverrouille pas, et n'est pas un échec à afficher")
    func cancellationDoesNotUnlock() async {
        let lock = AppLock(
            evaluator: FakeEvaluator(outcome: .failure(.cancelled)))
        #expect(await lock.authenticate(reason: "Déverrouiller") == false)
        #expect(lock.isUnlocked == false)
        #expect(lock.lastError == .cancelled)
    }

    /// **Le cas qui décide de la sûreté du type.** La tentation est de laisser passer quand
    /// l'appareil ne sait pas authentifier — « pas de biométrie, donc pas de verrou ». Ça ferait
    /// d'un appareil sans code un passe-partout.
    @Test("Un appareil sans authentification ne déverrouille pas")
    func unavailableDoesNotUnlock() async {
        let lock = AppLock(evaluator: FakeEvaluator(available: false))
        #expect(await lock.authenticate(reason: "Déverrouiller") == false)
        #expect(lock.isUnlocked == false)
        #expect(lock.lastError == .unavailable)
        #expect(lock.canAuthenticate == false)
    }

    @Test("Le verrouillage après échecs répétés se distingue d'un refus")
    func lockoutIsItsOwnCase() async {
        let lock = AppLock(evaluator: FakeEvaluator(outcome: .failure(.lockedOut)))
        #expect(await lock.authenticate(reason: "Déverrouiller") == false)
        #expect(lock.lastError == .lockedOut)
    }

    @Test("La capacité se relit, et retombe à zéro quand l'appareil ne peut plus")
    func capabilityRefreshes() {
        let lock = AppLock(evaluator: FakeEvaluator(available: true, kind: .touchID))
        lock.refreshCapability()
        #expect(lock.canAuthenticate)
        #expect(lock.biometry == .touchID)

        let unavailable = AppLock(evaluator: FakeEvaluator(available: false, kind: .faceID))
        unavailable.refreshCapability()
        #expect(unavailable.canAuthenticate == false)
        // **`.none` et non `.faceID`** : l'évaluateur factice annonce Face ID, mais un appareil
        // qui ne peut pas authentifier n'a pas de biométrie utilisable — afficher « Face ID »
        // dans le réglage promettrait une protection indisponible.
        #expect(unavailable.biometry == .none)
    }

    @Test("Verrouiller referme, et la portée suit")
    func lockingClosesTheScope() async {
        let lock = AppLock(evaluator: FakeEvaluator())
        let guarded = Profile(name: "Protégé")
        guarded.requiresBiometry = true

        #expect(lock.scope(for: guarded).hidesPrivateContent)
        _ = await lock.authenticate(reason: "Déverrouiller")
        #expect(lock.scope(for: guarded).hidesPrivateContent == false)
        lock.lock()
        #expect(lock.scope(for: guarded).hidesPrivateContent)
    }
}

// MARK: - La politique de phase

@Suite("Politique de reverrouillage")
struct LockPolicyTests {

    /// **Un instant quelconque**, pas minuit : 14 h 37 min 12 s, un mardi de septembre.
    private let backgrounded = Date(timeIntervalSince1970: 1_757_421_432)

    private func decide(
        _ phase: LockPolicy.Phase,
        enabled: Bool = true,
        grace: LockGrace = .oneMinute,
        after seconds: TimeInterval = 0,
        backgrounded hasBackground: Bool = true
    ) -> LockPolicy.Decision {
        LockPolicy.decide(
            phase: phase, isEnabled: enabled, grace: grace,
            backgroundedAt: hasBackground ? backgrounded : nil,
            now: backgrounded.addingTimeInterval(seconds))
    }

    /// **Le détail qu'on oublie**, et `docs/02` §9.3 le dit : iOS prend la vignette du
    /// sélecteur d'apps pendant `.inactive`. Attendre `.background` la laisse capturer le
    /// catalogue en clair — et la vignette reste visible ensuite.
    @Test("Le voile se pose dès inactive, pas à background")
    func coverAppearsOnInactive() {
        #expect(decide(.inactive).showsPrivacyCover)
        #expect(decide(.inactive).locks == false)
        // Désactivé, pas de voile : l'app n'a rien à cacher et le voile serait un clignotement.
        #expect(decide(.inactive, enabled: false).showsPrivacyCover == false)
    }

    @Test("Le passage en arrière-plan mémorise l'instant")
    func backgroundRecordsTheInstant() {
        #expect(decide(.background).recordsBackgroundInstant)
        #expect(decide(.background).showsPrivacyCover)
    }

    /// **La borne, et c'est le cas dégénéré que le réglage nomme.** Avec `>` au lieu de `>=`,
    /// un retour instantané sur « immédiat » donne un écart de zéro seconde, qui n'est pas
    /// strictement supérieur à zéro — et « immédiat » ne verrouillerait **jamais**.
    @Test("Immédiat verrouille au retour, même instantané")
    func immediateLocksAtOnce() {
        #expect(decide(.active, grace: .immediate, after: 0).locks)
        #expect(decide(.active, grace: .immediate, after: 0.5).locks)
    }

    @Test("Un retour dans le délai de grâce ne reverrouille pas")
    func withinGraceDoesNotLock() {
        // 43 s sur un délai de 60 : ni zéro, ni la borne, ni la moitié ronde.
        #expect(decide(.active, grace: .oneMinute, after: 43).locks == false)
        #expect(decide(.active, grace: .fiveMinutes, after: 187).locks == false)
    }

    @Test("Un retour au-delà du délai reverrouille")
    func beyondGraceLocks() {
        #expect(decide(.active, grace: .oneMinute, after: 61).locks)
        #expect(decide(.active, grace: .fifteenMinutes, after: 901).locks)
    }

    @Test("Le voile se lève au retour, et un lancement sans arrière-plan ne verrouille pas")
    func activeLiftsTheCover() {
        #expect(decide(.active, after: 900).showsPrivacyCover == false)
        // Premier lancement : aucun instant mémorisé. Reverrouiller ici n'aurait aucun sens —
        // le verrou est déjà fermé, `isUnlocked` valant `false` au démarrage.
        #expect(decide(.active, backgrounded: false).locks == false)
    }

    @Test("Verrou désactivé : rien ne se passe")
    func disabledDoesNothing() {
        let decision = decide(.active, enabled: false, grace: .immediate, after: 10_000)
        #expect(decision.locks == false)
        #expect(decision.showsPrivacyCover == false)
    }

    @Test("Les quatre délais sont ceux de la fiche")
    func graceValuesMatchTheBrief() {
        #expect(LockGrace.allCases.map(\.rawValue) == [0, 60, 300, 900])
    }
}
