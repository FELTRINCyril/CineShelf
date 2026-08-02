import SwiftUI

/// Racine de l'app : bascule entre disposition compacte et disposition large.
struct RootView: View {
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                RegularRootView()
            }
        #else
            RegularRootView()
        #endif
    }
}

#Preview("Racine") {
    RootView()
}
