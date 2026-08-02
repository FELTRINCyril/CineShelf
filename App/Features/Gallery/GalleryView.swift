import SwiftUI

/// Section « Galerie ». Implémentée à un prompt ultérieur.
struct GalleryView: View {
    var body: some View {
        ComingSoonView(title: "Galerie")
    }
}

#Preview("Galerie") {
    NavigationStack {
        GalleryView()
    }
}
