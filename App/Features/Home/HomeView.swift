import SwiftUI

/// Section « Accueil ». Implémentée à un prompt ultérieur.
struct HomeView: View {
    var body: some View {
        ComingSoonView(title: "Accueil")
    }
}

#Preview("Accueil") {
    NavigationStack {
        HomeView()
    }
}
