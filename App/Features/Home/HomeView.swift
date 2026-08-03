import SwiftUI

/// Section « Accueil ». Implémentée à un prompt ultérieur.
struct HomeView: View {
    var body: some View {
        SectionPlaceholder(section: .home)
    }
}

#Preview("Accueil") {
    NavigationStack {
        HomeView()
    }
}
