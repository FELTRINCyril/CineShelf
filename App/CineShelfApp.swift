import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

@main
struct CineShelfApp: App {
    @State private var container: ModelContainer
    @State private var navigation = NavigationModel()
    @State private var session = ProfileSession()

    init() {
        // Archivo vit dans le bundle de ressources du package DesignSystem, que
        // `UIAppFonts` ne sait pas atteindre : l'enregistrement est explicite.
        // `FontResolutionTests` échoue si une police cesse de se résoudre.
        DesignSystemFonts.register()

        do {
            let container = try Persistence.makeContainer(cloudKit: FeatureFlags.cloudKitEnabled)
            try Bootstrap.ensureDefaults(in: container.mainContext)
            self.container = container
        } catch {
            // Sans magasin, il n'y a pas d'app. Les états de synchronisation
            // auront leur propre interface au prompt « Synchronisation ».
            fatalError("Impossible d'ouvrir la bibliothèque : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .environment(session)
                .tint(session.accentColor)
        }
        .modelContainer(container)
        .commands {
            CineShelfCommands(navigation: navigation, session: session)
        }

        #if os(macOS)
            Settings {
                SettingsScene()
                    .environment(navigation)
                    .environment(session)
                    .modelContainer(container)
            }

            // Fenêtre dédiée plutôt que section : `docs/04` §2. La console de
            // gestion se consulte à côté de la bibliothèque, pas à sa place.
            Window("Gestion", id: Self.managementWindowID) {
                AppSection.libraryAdmin.destination
                    .frame(minWidth: 720, minHeight: 480)
                    .environment(navigation)
                    .environment(session)
                    .modelContainer(container)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        #endif
    }

    #if os(macOS)
        static let managementWindowID = "library-admin"
    #endif
}

#if os(macOS)
    /// Fenêtre de réglages macOS, remplie au prompt « Profils & Face ID ».
    struct SettingsScene: View {
        var body: some View {
            AppSection.settings.destination
                .frame(minWidth: 420, minHeight: 260)
        }
    }
#endif
