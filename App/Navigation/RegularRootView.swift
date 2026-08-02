import SwiftUI

/// Disposition large (iPad, Mac) : barre latérale et détail.
struct RegularRootView: View {
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.symbol)
                }
            }
            .navigationTitle("CineShelf")
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            #endif
        } detail: {
            NavigationStack {
                if let selection {
                    selection.destination
                } else {
                    ComingSoonView(title: "Sélectionne une section")
                }
            }
        }
    }
}

#Preview("Large") {
    RegularRootView()
}
