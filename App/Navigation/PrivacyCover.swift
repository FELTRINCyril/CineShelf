import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V7 · Le voile de confidentialité et la porte du verrou
//
// **Le détail qu'on oublie, et `docs/02` §9.3 le nomme** : sans voile, la vignette de l'app
// dans le sélecteur montre le catalogue en clair. Elle est capturée par le système **pendant**
// `.inactive`, pas à `.background` — attendre la seconde phase laisse la capture se faire.
//
// **La décision n'est pas ici.** `LockPolicy` la calcule, hors de toute vue, et ce modificateur
// l'applique. C'est la règle « l'arithmétique ne vit jamais dans une `View` » : une décision
// écrite dans un `onChange` ne se teste pas, et celle-ci porte sur des instants.

struct LockGate: ViewModifier {
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    /// **`@AppStorage` et non un champ du profil** : `docs/02` §9.1 range le verrou d'app parmi
    /// les réglages **locaux à l'appareil**. Verrouiller sur un Mac de bureau et sur un iPhone
    /// n'a pas le même sens, donc ce réglage ne se synchronise pas.
    @AppStorage("lock.enabled") private var isEnabled = false
    @AppStorage("lock.graceSeconds") private var graceSeconds = LockGrace.oneMinute.rawValue

    @State private var backgroundedAt: Date?
    @State private var showsCover = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if showsCover { cover }
            }
            .overlay {
                if isEnabled, !appLock.isUnlocked { LockScreen() }
            }
            .onChange(of: scenePhase) { _, phase in react(to: phase) }
            .task { appLock.refreshCapability() }
    }

    private func react(to phase: ScenePhase) {
        let decision = LockPolicy.decide(
            phase: phase.lockPhase, isEnabled: isEnabled,
            grace: LockGrace(rawValue: graceSeconds) ?? .oneMinute,
            backgroundedAt: backgroundedAt, now: .now)

        showsCover = decision.showsPrivacyCover
        if decision.recordsBackgroundInstant { backgroundedAt = .now }
        if decision.locks { appLock.lock() }
    }

    /// **Un aplat opaque, pas un flou.** Un flou laisse deviner la disposition et les couleurs
    /// dominantes des affiches ; c'est exactement ce que la vignette ne doit pas montrer. Et la
    /// direction n'a de toute façon aucune translucidité d'interface.
    private var cover: some View {
        ZStack {
            Color.bgCanvas
            Text("CINESHELF")
                .displayStyle()
                .foregroundStyle(Color.accent)
        }
        .ignoresSafeArea()
    }
}

extension ScenePhase {
    /// Le passage vers le vocabulaire du cœur, qui n'importe pas SwiftUI.
    ///
    /// Un cas inconnu est traité comme `.inactive` : **le repli pose le voile**. Une phase que
    /// nous ne connaissons pas est le pire moment pour décider de montrer le catalogue.
    var lockPhase: LockPolicy.Phase {
        switch self {
        case .active: .active
        case .inactive: .inactive
        case .background: .background
        @unknown default: .inactive
        }
    }
}

extension View {
    func lockGate() -> some View { modifier(LockGate()) }
}

/// La porte du verrou, sauf si un argument de lancement demande de s'en passer.
///
/// **Existe pour une mesure, et elle est nommée.** L'arbre d'accessibilité ne montrait aucune
/// fenêtre sous XCUITest, et l'hypothèse était que le voile de confidentialité se posait parce
/// que le lanceur garde le focus — donc que l'app démarre inactive. Cet interrupteur permet de
/// trancher au lieu de raisonner.
struct OptionalLockGate: ViewModifier {
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-cineshelf-no-lock") {
            content
        } else {
            content.modifier(LockGate())
        }
    }
}

// MARK: - L'écran de déverrouillage

/// Ce qui s'affiche tant que le verrou est fermé.
///
/// **Il couvre tout, et il ne se ferme pas.** Un écran de verrouillage qu'on peut écarter n'est
/// pas un verrou ; le seul chemin est l'authentification, ou l'app en arrière-plan.
struct LockScreen: View {
    @Environment(AppLock.self) private var appLock
    @State private var isAsking = false

    var body: some View {
        ZStack {
            Color.bgCanvas.ignoresSafeArea()
            VStack(spacing: Space.s4) {
                Image(systemName: symbol)
                    // `.largeTitle` et non une taille fixe : l'écran de verrouillage est le
                    // seul que verra un utilisateur en accessibilité maximale s'il n'arrive
                    // pas à entrer.
                    .font(.largeTitle)
                    .foregroundStyle(Color.accent)
                Text("CineShelf est verrouillé")
                    .title2Style()
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .calloutStyle()
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                if appLock.canAuthenticate {
                    Button("Déverrouiller") { unlock() }
                        .buttonStyle(ActionButtonStyle(rank: .primary))
                        .disabled(isAsking)
                }
            }
            .padding(Space.s6)
        }
        .task { await first() }
    }

    /// **Une seule demande automatique, au premier affichage.** Redemander à chaque
    /// réapparition ferait clignoter Face ID dès qu'on effleure l'app, et c'est ce qui pousse à
    /// désactiver le réglage.
    private func first() async {
        guard appLock.canAuthenticate, !isAsking else { return }
        await ask()
    }

    private func unlock() { Task { await ask() } }

    private func ask() async {
        isAsking = true
        defer { isAsking = false }
        await appLock.authenticate(reason: "Déverrouiller ta bibliothèque")
    }

    /// `lockFallback` quand l'appareil n'a pas de biométrie : le symbole doit dire ce qui va
    /// être demandé — un cadenas pour un code, un visage pour Face ID.
    private var symbol: String {
        appLock.biometry == .none ? Icon.lockFallback : Icon.lockedProfile
    }

    /// **Le message dit quoi faire, jamais ce qui est faux** — la règle du bloc `11a`, et elle
    /// vaut ici plus qu'ailleurs : l'utilisateur est enfermé dehors, il lui faut une sortie.
    private var message: String {
        guard appLock.canAuthenticate else {
            return
                """
                Cet appareil n'a ni code ni biométrie. Ajoute un code dans les réglages du \
                système, ou désactive le verrou de CineShelf.
                """
        }
        return switch appLock.lastError {
        case .lockedOut: "Trop de tentatives. Saisis le code de ton appareil."
        case .unavailable: "L'authentification n'est pas disponible pour l'instant."
        case .failed: "L'authentification n'a pas abouti. Réessaie."
        case .cancelled, nil: "Authentifie-toi pour retrouver ta bibliothèque."
        }
    }
}
