import SwiftUI

/// Section « Signets ». Implémentée à un prompt ultérieur.
struct SavedLinksView: View {
    var body: some View {
        SectionPlaceholder(section: .savedLinks)
    }
}

#Preview("Signets") {
    NavigationStack {
        SavedLinksView()
    }
}
