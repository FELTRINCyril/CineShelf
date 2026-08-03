import SwiftUI

/// Section « Réglages ». Implémentée à un prompt ultérieur.
struct SettingsView: View {
    var body: some View {
        SectionPlaceholder(section: .settings)
    }
}

#Preview("Réglages") {
    NavigationStack {
        SettingsView()
    }
}
