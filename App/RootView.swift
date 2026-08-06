import CineShelfCore
import SwiftData
import SwiftUI

/// Racine de l'app : choix du profil, puis bascule entre disposition compacte
/// et disposition large.
struct RootView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(NavigationModel.self) private var navigation

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    #if DEBUG
        @Environment(\.modelContext) private var modelContext
    #endif

    var body: some View {
        Group {
            if session.current == nil {
                ProfilePicker()
            } else {
                layout
            }
        }
        #if DEBUG
            // **L'amorçage des tests d'interface, et il n'existe qu'en DEBUG.**
            //
            // Une suite d'interface qui doit cliquer à travers le sélecteur de profil, la
            // navigation et un import pour atteindre la console teste surtout sa propre
            // patience : chaque étape est une occasion de casser pour une raison qui n'a rien à
            // voir avec ce qu'on vérifie. L'argument de lancement pose un état connu, et c'est
            // le seul moyen d'avoir une porte qui dise quelque chose de stable.
            //
            // `-cineshelf-seed <n>` peuple `n` titres ; `0` laisse la bibliothèque vide, ce qui
            // est le contre-cas de la porte.
            .task { seedForUITestsIfAsked() }
        #endif
        .task(id: profiles.map(\.id)) {
            // Les commandes de la barre de menus n'ont pas de `@Query` : c'est
            // ici que ⌃⌘1…9 apprend sur quels profils il porte.
            session.available = profiles
            openDirectlyIfPossible()
        }
        .onChange(of: session.current?.id) { _, newValue in
            // La navigation est mémorisée par profil : changer de profil change
            // d'écran de reprise, pas seulement de contenu.
            guard let newValue else { return }
            navigation.restore(profileID: newValue)
        }
        .onChange(of: navigation.section) { _, _ in saveNavigation() }
        .onChange(of: navigation.paths) { _, _ in saveNavigation() }
        .onChange(of: navigation.isInspectorPresented) { _, _ in saveNavigation() }
        .onChange(of: navigation.titleFilter) { _, _ in saveNavigation() }
    }

    @ViewBuilder
    private var layout: some View {
        #if os(iOS)
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                RegularRootView()
            }
        #else
            RegularRootView()
        #endif
    }

    /// Le sélecteur ne s'affiche que s'il y a un choix à faire.
    private func openDirectlyIfPossible() {
        guard session.current == nil,
            let profile = session.profileToOpenDirectly(among: profiles)
        else { return }
        session.open(profile)
    }

    #if DEBUG
        /// Pose un état connu quand la suite d'interface le demande.
        private func seedForUITestsIfAsked() {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-cineshelf-seed"),
                arguments.indices.contains(index + 1),
                let count = Int(arguments[index + 1])
            else { return }

            let library = Library(name: "Sonde", isDefault: true)
            modelContext.insert(library)
            let profile = Profile(name: "Sonde", isDefault: true)
            // La relation passe par le repository nulle part ici : c'est l'amorçage de test,
            // et `Profile` n'a pas de `filterKeys`. `ProfileRepository.create` fait exactement
            // ça, donc on l'appelle plutôt que d'écrire la relation à la main — la règle de lint
            // a raison même sur un chemin de DEBUG.
            modelContext.insert(profile)

            let repository = TitleRepository(context: modelContext)
            for number in 0..<count {
                let title = repository.create(name: "Titre \(number)", in: library)
                title.rating = Double(number % 10)
                title.runtimeMinutes = 90 + number
                title.refreshDerived()
            }
            try? modelContext.save()

            session.open(profile)
            navigation.section = .libraryAdmin
        }
    #endif

    private func saveNavigation() {
        guard let profileID = session.current?.id else { return }
        navigation.save(profileID: profileID)
    }
}
