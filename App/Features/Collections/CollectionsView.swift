import SwiftUI

/// Section « Collections ». Implémentée à un prompt ultérieur.
struct CollectionsView: View {
    var body: some View {
        SectionPlaceholder(section: .collections)
    }
}

#Preview("Collections") {
    NavigationStack {
        CollectionsView()
    }
}
