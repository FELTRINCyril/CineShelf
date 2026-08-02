import SwiftUI

@main
struct CineShelfApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
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
