import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Disposition compacte (iPhone) : cinq onglets — `docs/01` partie C.
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

    /// Chaque onglet a sa pile. « Catalogue » suit son segment, « Plus » a la
    /// sienne : les lier à la section courante ferait partager un même tableau
    /// entre plusieurs `NavigationStack` vivants, puisque `TabView` évalue le
    /// corps de tous les onglets.
    private func stackBinding(for tab: CompactTab) -> Binding<[AppRoute]> {
        switch tab {
        case .catalogue: navigation.pathBinding(for: .section(navigation.catalogueSegment.section))
        case .more: navigation.pathBinding(for: .more)
        default: navigation.pathBinding(for: .section(tab.section ?? navigation.section))
        }
    }

    @ViewBuilder
    private func content(for tab: CompactTab) -> some View {
        switch tab {
        case .catalogue: CatalogueTab()
        case .more: MoreTab()
        default:
            if let section = tab.section {
                section.destination
            }
        }
    }
}

/// L'onglet « Catalogue » : un sélecteur segmenté au-dessus du contenu.
private struct CatalogueTab: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var navigation = navigation

        navigation.catalogueSegment.section.destination
            .safeAreaInset(edge: .top) {
                segmentPicker(selection: $navigation.catalogueSegment)
                    .padding(.horizontal, Space.pageMargin(compact: true))
                    .padding(.bottom, Space.sm)
                    .background(.bar)
            }
            .navigationTitle("Catalogue")
    }

    /// Trois segments ne tiennent pas sur une largeur d'iPhone en taille
    /// d'accessibilité : `docs/01` §B.2 impose de basculer en liste au-delà
    /// d'`.accessibility1` plutôt que de tronquer.
    @ViewBuilder
    private func segmentPicker(selection: Binding<CatalogueSegment>) -> some View {
        let picker = Picker("Catalogue", selection: selection) {
            ForEach(CatalogueSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }

        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }
}

/// L'onglet « Plus » : les sections qui ne tiennent pas dans la barre d'onglets,
/// et le profil actif.
private struct MoreTab: View {
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
                                        ? Color.accentText : Color.textPrimary)
                        }
                        .frame(minHeight: Space.minHitTarget)
                        // La teinte seule ne dit rien à VoiceOver.
                        .accessibilityAddTraits(
                            profile.id == session.current?.id ? .isSelected : [])
                    }
                }
            }

            Section {
                ForEach(AppSection.utility) { section in
                    NavigationLink {
                        section.destination
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                    }
                    .frame(minHeight: Space.minHitTarget)
                }
            }
        }
        .navigationTitle("Plus")
    }
}
