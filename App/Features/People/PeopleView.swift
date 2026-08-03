import SwiftUI

/// Section « Personnes ». Implémentée à un prompt ultérieur.
struct PeopleView: View {
    var body: some View {
        SectionPlaceholder(section: .people)
    }
}

#Preview("Personnes") {
    NavigationStack {
        PeopleView()
    }
}
