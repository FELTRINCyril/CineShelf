import CineShelfCore
import SwiftData
import SwiftUI

@main
struct CineShelfApp: App {
    @State private var container: ModelContainer

    init() {
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
        }
        .modelContainer(container)
        .commands {
            CineShelfCommands()
        }

        #if os(macOS)
            Settings {
                SettingsScene()
            }
        #endif
    }
}

/// Commandes de barre de menus. Les entrées arriveront avec les fonctionnalités.
struct CineShelfCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Bibliothèque") {
            EmptyView()
        }
    }
}

#if os(macOS)
    /// Fenêtre de réglages macOS, remplie au prompt « Profils & Face ID ».
    struct SettingsScene: View {
        var body: some View {
            ComingSoonView(title: "Réglages")
                .frame(minWidth: 420, minHeight: 260)
        }
    }
#endif
