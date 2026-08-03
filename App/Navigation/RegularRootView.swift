import DesignSystem
import SwiftUI

/// Disposition large (iPad, Mac) : trois colonnes — `docs/01` partie C.
///
/// Barre latérale, liste, détail. La colonne du milieu n'a pas encore de
/// contenu réel : elle affiche l'écran vide de la section, ce qui suffit à
/// valider la géométrie sur les trois plateformes.
struct RegularRootView: View {
    @Environment(NavigationModel.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        NavigationSplitView {
            Sidebar()
        } content: {
            navigation.section.destination
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        } detail: {
            NavigationStack(path: navigation.pathBinding(for: .section(navigation.section))) {
                DetailPlaceholder(section: navigation.section)
                    .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
            }
            .inspector(isPresented: $navigation.isInspectorPresented) {
                RouteInspector(route: navigation.path(for: navigation.section).last)
            }
        }
    }
}

/// La colonne de détail quand rien n'est sélectionné.
private struct DetailPlaceholder: View {
    let section: AppSection

    var body: some View {
        StateView(
            .empty(
                symbol: "sidebar.right",
                title: "Rien de sélectionné.",
                message: "Choisis un élément dans la liste pour l'afficher ici."
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
        .navigationTitle(section.title)
    }
}
