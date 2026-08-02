import SwiftUI

/// Section « Ma liste ». Implémentée à un prompt ultérieur.
struct MyListView: View {
    var body: some View {
        ComingSoonView(title: "Ma liste")
    }
}

#Preview("Ma liste") {
    NavigationStack {
        MyListView()
    }
}
