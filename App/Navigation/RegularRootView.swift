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
                InspectorPlaceholder()
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

/// Le panneau d'édition latéral — ⌥⌘I.
private struct InspectorPlaceholder: View {
    var body: some View {
        StateView(
            .empty(
                symbol: "slider.horizontal.3",
                title: "Inspecteur.",
                message: "L'édition de l'élément sélectionné se fera ici, sans quitter la liste."
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgSurface)
        .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
    }
}
