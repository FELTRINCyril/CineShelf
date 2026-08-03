import SwiftUI

/// Section « Ma liste ». Implémentée à un prompt ultérieur.
struct MyListView: View {
    var body: some View {
        SectionPlaceholder(section: .myList)
    }
}

#Preview("Ma liste") {
    NavigationStack {
        MyListView()
    }
}
