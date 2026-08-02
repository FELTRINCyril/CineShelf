import SwiftUI

/// Section « Titres ». Implémentée à un prompt ultérieur.
struct TitlesView: View {
    var body: some View {
        ComingSoonView(title: "Titres")
    }
}

#Preview("Titres") {
    NavigationStack {
        TitlesView()
    }
}
