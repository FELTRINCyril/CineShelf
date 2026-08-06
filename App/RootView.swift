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

    var body: some View {
        Group {
            if session.current == nil {
                ProfilePicker()
            } else {
                layout
            }
        }
        .accessibilityIdentifier("root.content")
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

    private func saveNavigation() {
        guard let profileID = session.current?.id else { return }
        navigation.save(profileID: profileID)
    }
}
