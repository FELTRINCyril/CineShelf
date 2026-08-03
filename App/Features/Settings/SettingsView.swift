import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Section « Réglages ». Le contenu réel arrive au prompt 18 ; en DEBUG, elle
/// donne déjà accès au catalogue de démonstration.
struct SettingsView: View {
    var body: some View {
        #if DEBUG
            Form {
                DemoCatalogSection()
            }
            .formStyle(.grouped)
            .navigationTitle("Réglages")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        #else
            SectionPlaceholder(section: .settings)
        #endif
    }
}

#if DEBUG

    /// Le catalogue de démonstration — DEBUG uniquement.
    private struct DemoCatalogSection: View {
        @Environment(\.modelContext) private var modelContext
        @Environment(ProfileSession.self) private var session

        @State private var isWorking = false
        @State private var failure: String?

        var body: some View {
            Section("Développement") {
                Button {
                    run { context, library in
                        try DemoCatalog.populate(in: context, library: library)
                    }
                } label: {
                    Label(
                        "Générer un catalogue d'exemple",
                        systemImage: "wand.and.stars"
                    )
                }
                .disabled(isWorking || session.current?.library == nil)

                Button(role: .destructive) {
                    run { context, library in try DemoCatalog.clear(in: context, library: library) }
                } label: {
                    Label("Vider le catalogue d'exemple", systemImage: "trash")
                }
                .disabled(isWorking)

                Text(
                    """
                    \(DemoCatalog.titleCount) titres, \(DemoCatalog.personCount) personnes, \
                    \(DemoCatalog.collectionCount) collections. Les jaquettes sont dessinées \
                    par le code : rien n'est embarqué dans l'app.
                    """
                )
                .font(Typo.caption)
                .foregroundStyle(.textTertiary)

                if let failure {
                    Text(failure)
                        .font(Typo.caption)
                        .foregroundStyle(.statusDanger)
                }
            }
        }

        private func run(_ work: @escaping (ModelContext, Library) throws -> Void) {
            guard let library = session.current?.library else { return }
            isWorking = true
            failure = nil
            do {
                try work(modelContext, library)
            } catch {
                failure = "Échec : \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

#endif

#Preview("Réglages") {
    NavigationStack {
        SettingsView()
    }
}
