import SwiftUI

/// Section « Titres ». Implémentée à un prompt ultérieur.
struct TitlesView: View {
    var body: some View {
        SectionPlaceholder(section: .titles)
    }
}

#Preview("Titres") {
    NavigationStack {
        TitlesView()
    }
}
