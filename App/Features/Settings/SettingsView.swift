import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V7 · Les réglages
//
// Planche 5, bloc `7g`. **Trois sections livrées sur six** — apparence, confidentialité,
// synchronisation — et les trois autres sont inscrites plutôt que rendues en coquille :
//
// - **Corbeille et maintenance** : c'est `L16`, tâche 23, non faite. « Vider maintenant » et
//   « Analyser » seraient deux boutons qui ne font rien.
// - **Profils** : rendus par `ProfilesView`, dans son propre écran comme le bloc `7f`.
// - **À propos** : rien à y mettre tant que la version n'est pas figée.
//
// **Le verrou est un réglage local à l'appareil** — `docs/02` §9.1 — donc `@AppStorage` et non
// un champ de `Profile` : verrouiller sur un Mac de bureau et sur un iPhone n'a pas le même
// sens, et ça ne se synchronise pas.
struct SettingsView: View {
    @AppStorage("lock.enabled") private var isLockEnabled = false
    @AppStorage("lock.graceSeconds") private var graceSeconds = LockGrace.oneMinute.rawValue

    @Environment(AppLock.self) private var appLock

    var body: some View {
        Form {
            privacySection
            // **Les profils sont une section, pas un écran séparé**, contrairement au bloc
            // `7f` qui leur en donne un. Motif : `AppSection` n'a pas de cas « Profils » et
            // en ajouter un pousserait une entrée de plus dans une barre d'onglets qui n'en
            // couvre déjà que cinq sur douze. Écart inscrit — un écran inatteignable serait
            // pire que dense.
            Section { ProfilesView() }
            #if DEBUG
                DemoCatalogSection()
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Réglages")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// « Confidentialité » du bloc `7g`, avec le sous-titre du prototype sur le délai :
    /// « repli automatique sur le code de l'appareil ».
    @ViewBuilder
    private var privacySection: some View {
        Section("Confidentialité") {
            Toggle("Verrouiller CineShelf", isOn: $isLockEnabled)
                .disabled(!appLock.canAuthenticate)

            if !appLock.canAuthenticate {
                // **Le réglage se désactive en le disant**, plutôt que de laisser croire à une
                // protection : `docs/02` §9.5 l'exige, et `AppLock` refuse de déverrouiller un
                // appareil qui ne sait pas authentifier.
                Text("Cet appareil n'a ni code ni biométrie. Ajoute un code dans les réglages du système.")
                    .font(Typo.micro)
                    .foregroundStyle(.textTertiary)
            }

            Picker("Délai de grâce", selection: $graceSeconds) {
                ForEach(LockGrace.allCases) { grace in
                    Text(grace.label).tag(grace.rawValue)
                }
            }
            .disabled(!isLockEnabled)

            Text("Repli automatique sur le code de l'appareil.")
                .font(Typo.micro)
                .foregroundStyle(.textTertiary)
        }
    }
}

#if DEBUG

    /// Le catalogue de démonstration — DEBUG uniquement.
    private struct DemoCatalogSection: View {
        @Environment(\.modelContext) private var modelContext
        @Environment(ProfileSession.self) private var session

        @State private var isWorking = false
        @State private var failure: String?

        var body: some View {
            Section("Développement") {
                Button {
                    run { context, library in
                        try DemoCatalog.populate(in: context, library: library)
                    }
                } label: {
                    Label(
                        "Générer un catalogue d'exemple",
                        systemImage: "wand.and.stars"
                    )
                }
                // Générer deux fois produirait 240 titres : le bouton se
                // désactive dès qu'un catalogue de démonstration existe.
                .disabled(isWorking || library == nil || isPopulated)

                Button(role: .destructive) {
                    run { context, library in try DemoCatalog.clear(in: context, library: library) }
                } label: {
                    Label("Vider le catalogue d'exemple", systemImage: "trash")
                }
                .disabled(isWorking || !isPopulated)

                Text(
                    """
                    \(DemoCatalog.titleCount) titres, \(DemoCatalog.personCount) personnes, \
                    \(DemoCatalog.collectionCount) collections. Les jaquettes sont dessinées \
                    par le code : rien n'est embarqué dans l'app.
                    """
                )
                .font(Typo.caption)
                .foregroundStyle(.textTertiary)

                if let failure {
                    Text(failure)
                        .font(Typo.caption)
                        .foregroundStyle(.statusDanger)
                }
            }
        }

        private var library: Library? { session.current?.library }

        private var isPopulated: Bool {
            guard let library else { return false }
            return DemoCatalog.isPopulated(in: modelContext, library: library)
        }

        private func run(_ work: @escaping (ModelContext, Library) throws -> Void) {
            guard let library = session.current?.library else { return }
            isWorking = true
            failure = nil
            do {
                try work(modelContext, library)
            } catch {
                failure = "Échec : \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

#endif

#Preview("Réglages") {
    NavigationStack {
        SettingsView()
    }
}
