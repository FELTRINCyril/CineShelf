import SwiftUI

/// Section « Recherche ». Implémentée à un prompt ultérieur.
struct SearchView: View {
    var body: some View {
        SectionPlaceholder(section: .search)
    }
}

#Preview("Recherche") {
    NavigationStack {
        SearchView()
    }
}
