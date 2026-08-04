import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Disposition compacte (iPhone) : cinq onglets — planche 2 bloc `3c`.
///
/// **Accueil · Titres · Recherche · Ma liste · Gérer.** Le sélecteur segmenté
/// « Catalogue » de l'ancienne coquille disparaît : le prototype ne le montre pas, et
/// `CatalogueSegment` a été supprimé avec lui.
struct CompactRootView: View {
    @Environment(NavigationModel.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.compactTab) {
            ForEach(CompactTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) {
                    NavigationStack(path: stackBinding(for: tab)) {
                        content(for: tab)
                            .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                    }
                }
            }
        }
    }

    /// Chaque onglet a sa pile. « Gérer » a la sienne : la lier à la section courante
    /// ferait partager un même tableau entre plusieurs `NavigationStack` vivants, puisque
    /// `TabView` évalue le corps de tous les onglets.
    private func stackBinding(for tab: CompactTab) -> Binding<[AppRoute]> {
        switch tab {
        case .manage: navigation.pathBinding(for: .more)
        default: navigation.pathBinding(for: .section(tab.section ?? navigation.section))
        }
    }

    @ViewBuilder
    private func content(for tab: CompactTab) -> some View {
        if let section = tab.section {
            section.destination
        } else {
            ManageTab()
        }
    }
}

/// L'onglet « Gérer » : les sections que la barre d'onglets ne couvre pas, les sections de
/// service, et le profil actif.
///
/// Personnes, Collections et Galerie y sont **par défaut de mieux** : le prototype ne leur
/// donne pas d'onglet et ne dit pas où on les atteint sur iPhone. Voir la note de
/// `CompactTab` et l'écart inscrit dans `docs/PROMPTS.md`.
private struct ManageTab: View {
    @Environment(ProfileSession.self) private var session

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]

    var body: some View {
        List {
            if profiles.count > 1 {
                Section("Profil") {
                    ForEach(profiles) { profile in
                        Button {
                            session.open(profile)
                        } label: {
                            Label(profile.name, systemImage: profile.avatarSymbol)
                                .foregroundStyle(
                                    profile.id == session.current?.id
                                        ? Color.accent : Color.textPrimary)
                        }
                        .frame(minHeight: Space.minHitTarget)
                        // La teinte seule ne dit rien à VoiceOver.
                        .accessibilityAddTraits(
                            profile.id == session.current?.id ? .isSelected : [])
                    }
                }
            }

            Section {
                ForEach(CompactTab.managed) { section in
                    NavigationLink {
                        section.destination
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                    }
                    .frame(minHeight: Space.minHitTarget)
                }
            }
        }
        .navigationTitle(CompactTab.manage.title)
    }
}
