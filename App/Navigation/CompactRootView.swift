import SwiftUI

/// Disposition compacte (iPhone) : barre d'onglets.
struct CompactRootView: View {
    @State private var selection: AppSection = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.compactTabs) { section in
                Tab(section.title, systemImage: section.symbol, value: section) {
                    NavigationStack {
                        section.destination
                    }
                }
            }
        }
    }
}

#Preview("Compact") {
    CompactRootView()
}
