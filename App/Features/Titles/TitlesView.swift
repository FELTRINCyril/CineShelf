import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// L'écran « Titres » — planche 3 bloc `4a`.
///
/// Découpé en deux, et c'est nécessaire, pas cosmétique : un `@Query` à prédicat dynamique
/// ne se réévalue qu'à la reconstruction de la vue qui le déclare. Cette vue porte
/// l'en-tête et les réglages, `TitlesGrid` porte la requête et se fait recréer.
///
/// **Les actions vivent dans `ScreenHeader`, pas dans une barre à part.** `V0` a livré
/// l'en-tête d'écran en laissant son emplacement d'actions vide ; `V0 bis` le remplit. Une
/// `.toolbar` SwiftUI aurait donné une seconde barre au-dessus de celle du chrome, ce que
/// le bloc `4a` ne montre pas.
struct TitlesView: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext

    @State private var isFilterSheetPresented = false
    @State private var editedTitle: Title?

    /// Tenu en `@State` **et** persisté : lu depuis `UserDefaults` à chaque accès, il
    /// persistait bien mais ne redessinait rien — `UserDefaults` n'invalide aucune vue.
    @State private var setting = PosterContext.titles.defaultSetting

    var body: some View {
        @Bindable var navigation = navigation

        VStack(alignment: .leading, spacing: Space.s4) {
            ScreenHeader(section: .titles) { actions }
            activeFilters
            TitlesGrid(
                filter: navigation.titleFilter,
                hidingPrivate: appLock.scope(for: session.current).hidesPrivateContent,
                libraryID: session.current?.library?.id,
                setting: setting,
                onCreate: createTitle
            )
        }
        .searchable(text: $navigation.titleFilter.searchText, prompt: "Rechercher un titre")
        .task(id: session.current?.id) { setting = storedSetting }
        .onChange(of: setting) { _, new in
            PosterSettingStore.save(new, profileID: session.current?.id, context: .titles)
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            TitleFilterSheet(filter: $navigation.titleFilter)
        }
        .sheet(item: $editedTitle) { title in
            TitleEditor(title: title)
                // Fermer la feuille par glissement n'appelle pas « Annuler » : sans ça, un
                // titre créé puis abandonné reste dans la bibliothèque, sans nom, en tête
                // du tri alphabétique.
                .onDisappear { discardIfUnnamed(title) }
        }
        // `onChange` seul ne suffit pas : ⌘N depuis une autre section lève le drapeau
        // *avant* que cette vue existe, et l'événement est manqué.
        .onChange(of: navigation.wantsNewTitle) { _, _ in consumeCreationRequest() }
        .onAppear { consumeCreationRequest() }
    }

    // MARK: Les actions de l'en-tête — bloc `4a` : Trier · Filtres · Affichage · ＋ Nouveau

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: Space.s5) {
            sortMenu
            filterButton
            displayMenu
            Button("Nouveau", action: createTitle)
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Trier par", selection: sortBinding) {
                ForEach(TitleSortField.allCases) { field in
                    Label(field.label, systemImage: field.symbol).tag(field)
                }
            }
            Divider()
            Picker("Ordre", selection: ascendingBinding) {
                Text("Croissant").tag(true)
                Text("Décroissant").tag(false)
            }
        } label: {
            Text("Trier")
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    /// Le libellé porte le compte de filtres actifs et passe en ambre — bloc `4a`,
    /// « Filtres · 2 ». C'est le seul signal : la direction n'a pas de pastille.
    private var filterButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            Text(navigation.titleFilter.isActive ? "Filtres · actifs" : "Filtres")
                .actionStyle()
                .foregroundStyle(filterTint)
                .frame(minHeight: Space.minHitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var filterTint: Color {
        navigation.titleFilter.isActive ? Color.accent : Color.textSecondary
    }

    /// La matrice `disposition × taille`, qui est une **fonctionnalité** mémorisée par
    /// contexte et non un réglage d'apparence — voir `PosterContext`.
    private var displayMenu: some View {
        Menu {
            Picker("Disposition", selection: layoutBinding) {
                ForEach(CardLayout.allCases) { layout in
                    Label(layout.label, systemImage: layout.symbol).tag(layout)
                }
            }
            Divider()
            Picker("Taille", selection: sizeBinding) {
                ForEach(CardSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
        } label: {
            Text("Affichage")
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    /// La rangée de filtres actifs — bloc `4a`, « Drame ✕ · Note ≥ 4 ✕ ».
    ///
    /// **Rendue en `StateBadge` et non en jeton interactif.** Le jeton de filtre avec sa
    /// croix est un composant de `I5`, qui n'est pas fait (palier 3) ; en écrire une
    /// version ici la ferait exister en double le jour où `I5` arrive. La rangée dit donc
    /// ce qui filtre, et on l'enlève par la feuille — moins direct que le prototype, et
    /// inscrit comme tel.
    @ViewBuilder
    private var activeFilters: some View {
        if navigation.titleFilter.isActive {
            HStack(spacing: Space.s2) {
                StateBadge("Filtres actifs", tone: .accent)
                Button("Tout effacer") { navigation.titleFilter.clear() }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textTertiary)
                    .frame(minHeight: Space.minHitTarget)
                Spacer(minLength: Space.s4)
                Text("\(setting.layout.label) · \(setting.size.label)")
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        }
    }

    // MARK: Liaisons

    private var sortBinding: Binding<TitleSortField> {
        Binding(
            get: { navigation.titleFilter.sort },
            set: { navigation.titleFilter.sort = $0 }
        )
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(
            get: { navigation.titleFilter.ascending },
            set: { navigation.titleFilter.ascending = $0 }
        )
    }

    private var layoutBinding: Binding<CardLayout> {
        Binding(get: { setting.layout }, set: { setting.layout = $0 })
    }

    private var sizeBinding: Binding<CardSize> {
        Binding(get: { setting.size }, set: { setting.size = $0 })
    }

    private var storedSetting: PosterSetting {
        PosterSettingStore.setting(profileID: session.current?.id, context: .titles)
    }

    private func consumeCreationRequest() {
        guard navigation.wantsNewTitle else { return }
        navigation.wantsNewTitle = false
        createTitle()
    }

    private func discardIfUnnamed(_ title: Title) {
        guard title.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            title.deletedAt == nil
        else { return }
        TitleRepository(context: modelContext).softDelete(title)
    }

    private func createTitle() {
        guard let library = session.current?.library else { return }
        editedTitle = TitleRepository(context: modelContext).create(name: "", in: library)
    }
}
