import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// La liste des titres — `docs/03` §4.
///
/// Découpée en deux : cette vue porte le chrome (barre d'outils, filtres,
/// recherche), `TitlesGrid` porte la requête. C'est nécessaire, pas cosmétique :
/// un `@Query` à prédicat dynamique ne se réévalue qu'à la reconstruction de la
/// vue qui le déclare, donc la grille est recréée à chaque changement de filtre.
struct TitlesView: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var isFilterSheetPresented = false
    @State private var editedTitle: Title?

    /// L'affichage est tenu en `@State` **et** persisté : lu depuis
    /// `UserDefaults` à chaque accès, il persistait bien mais ne redessinait
    /// rien — `UserDefaults` n'invalide aucune vue SwiftUI.
    @State private var display = CardDisplaySetting.default

    var body: some View {
        @Bindable var navigation = navigation

        TitlesGrid(
            filter: navigation.titleFilter,
            hidingPrivate: session.current?.hidesPrivateContent ?? false,
            libraryID: session.current?.library?.id,
            display: display,
            onEdit: { editedTitle = $0 },
            onCreate: createTitle
        )
        .navigationTitle("Titres")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $navigation.titleFilter.searchText, prompt: "Rechercher un titre")
        .task(id: session.current?.id) { display = storedDisplay }
        .onChange(of: display) { _, new in
            CardDisplayStore.save(new, profileID: session.current?.id, context: .titles)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $isFilterSheetPresented) {
            TitleFilterSheet(filter: $navigation.titleFilter)
        }
        .sheet(item: $editedTitle) { title in
            TitleEditor(title: title)
                // Fermer la feuille par glissement n'appelle pas « Annuler » :
                // sans ça, un titre créé puis abandonné reste dans la
                // bibliothèque, sans nom, en tête du tri alphabétique.
                .onDisappear { discardIfUnnamed(title) }
        }
        // `onChange` seul ne suffit pas : ⌘N depuis une autre section lève le
        // drapeau *avant* que cette vue existe, et l'événement est manqué.
        .onChange(of: navigation.wantsNewTitle) { _, _ in consumeCreationRequest() }
        .onAppear { consumeCreationRequest() }
    }

    // MARK: Barre d'outils — `docs/01` partie C : tri, filtres, affichage

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
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
                Label("Trier", systemImage: Icon.sort)
            }
        }

        ToolbarItem {
            Button {
                isFilterSheetPresented = true
            } label: {
                // Un filtre actif doit se voir sans ouvrir la feuille.
                Label("Filtrer", systemImage: filterSymbol)
            }
        }

        ToolbarItem {
            DisplayMenu(setting: $display, context: .titles)
        }

        ToolbarItem {
            // `docs/03` §3 : bascule dans la barre d'outils, pas enterrée dans
            // la feuille de filtres. Elle y reste aussi, les deux sont liées.
            Toggle(isOn: showsArchivedBinding) {
                Label("Afficher les archivés", systemImage: Icon.archived)
            }
            .toggleStyle(.button)
            .help("Afficher les archivés")
        }

        ToolbarItem {
            Button {
                createTitle()
            } label: {
                Label("Nouveau titre", systemImage: "plus")
            }
        }
    }

    private var filterSymbol: String {
        navigation.titleFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : Icon.filter
    }

    // MARK: Liaisons

    private var sortBinding: Binding<TitleSortField> {
        Binding(
            get: { navigation.titleFilter.sort },
            set: { navigation.titleFilter.sort = $0 }
        )
    }

    private var showsArchivedBinding: Binding<Bool> {
        Binding(
            get: { navigation.titleFilter.showsArchived },
            set: { navigation.titleFilter.showsArchived = $0 }
        )
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(
            get: { navigation.titleFilter.ascending },
            set: { navigation.titleFilter.ascending = $0 }
        )
    }

    /// L'affichage est persisté par profil **et** par contexte : la grille des
    /// titres et celle de la galerie n'ont pas la même densité utile.
    /// `docs/02` §3.10 le range hors du modèle — c'est une préférence
    /// d'appareil, pas une donnée à synchroniser.
    private var storedDisplay: CardDisplaySetting {
        CardDisplayStore.setting(profileID: session.current?.id, context: .titles)
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

/// La persistance de `CardDisplaySetting`, par profil et par contexte.
enum CardDisplayStore {

    static func setting(profileID: UUID?, context: CardDisplayContext) -> CardDisplaySetting {
        guard let data = UserDefaults.standard.data(forKey: key(profileID, context)),
            let decoded = try? JSONDecoder().decode(CardDisplaySetting.self, from: data)
        else { return .default }
        return decoded
    }

    static func save(_ setting: CardDisplaySetting, profileID: UUID?, context: CardDisplayContext) {
        guard let data = try? JSONEncoder().encode(setting) else { return }
        UserDefaults.standard.set(data, forKey: key(profileID, context))
    }

    private static func key(_ profileID: UUID?, _ context: CardDisplayContext) -> String {
        "display.\(profileID?.uuidString ?? "none").\(context.rawValue)"
    }
}
