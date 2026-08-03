import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// La colonne de gauche en disposition large — `docs/01` partie C : les
/// sections, un bloc « Genres épinglés », un bloc « Bibliothèques », et le
/// menu de profil en pied.
struct Sidebar: View {
    @Environment(NavigationModel.self) private var navigation

    // `docs/04` §3 autorise les requêtes déclaratives dans la vue : ce sont des
    // listes affichées telles quelles, sans règle métier à appliquer.
    @Query(filter: #Predicate<Genre> { $0.isPinned }, sort: \Genre.pinIndex)
    private var pinnedGenres: [Genre]

    @Query(sort: \Library.name)
    private var libraries: [Library]

    /// iOS n'expose que la variante à sélection optionnelle de `List(selection:)`.
    /// On fait le pont sans rendre la section du modèle optionnelle : un
    /// désélection (`nil`) laisse simplement la section courante en place.
    private var selection: Binding<AppSection?> {
        Binding(
            get: { navigation.section },
            set: { if let section = $0 { navigation.section = section } }
        )
    }

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(AppSection.sidebar) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }

            if !pinnedGenres.isEmpty {
                Section("Genres épinglés") {
                    ForEach(pinnedGenres) { genre in
                        Button {
                            navigation.section = .titles
                            navigation.open(.genre(genre.id))
                        } label: {
                            Label(genre.name, systemImage: Icon.genres)
                                .frame(maxWidth: .infinity, minHeight: Space.minHitTarget, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if libraries.count > 1 {
                Section("Bibliothèques") {
                    ForEach(libraries) { library in
                        Label(library.name, systemImage: Icon.library)
                    }
                }
            }
        }
        .navigationTitle("CineShelf")
        .safeAreaInset(edge: .bottom) {
            ProfileMenu()
                .padding(Space.sm)
                .background(.bar)
        }
        #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        #endif
    }
}
