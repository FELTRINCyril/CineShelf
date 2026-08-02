import SwiftUI

/// Écran d'attente affiché tant qu'une section n'est pas implémentée.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("À venir.")
        )
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("À venir") {
    NavigationStack {
        ComingSoonView(title: "Titres")
    }
}
