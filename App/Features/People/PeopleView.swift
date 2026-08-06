import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// L'écran « Personnes » — planche 3 bloc `4c`.
///
/// **Le patron de `V0 bis`, repris tel quel.** L'en-tête et les réglages ici, la requête dans
/// `PeopleGrid` : c'est la seule façon qu'un `@Query` à prédicat dynamique se réévalue. Ce qui
/// change d'un écran à l'autre est le contenu — le filtre, la tuile, le menu — pas la
/// mécanique, et c'est ce que `V0 bis` avait pour but d'établir.
///
/// Les actions vivent dans `ScreenHeader`, jamais dans une `.toolbar` : une barre SwiftUI
/// s'ajouterait **au-dessus** de celle du chrome, ce que le bloc `4c` ne montre pas.
struct PeopleView: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext

    @State private var isFilterSheetPresented = false
    @State private var editedPerson: Person?
    @State private var setting = PosterContext.people.defaultSetting

    var body: some View {
        @Bindable var navigation = navigation

        VStack(alignment: .leading, spacing: Space.s4) {
            ScreenHeader(section: .people) { actions }
            activeFilters
            PeopleGrid(
                filter: navigation.personFilter,
                hidingPrivate: appLock.scope(for: session.current).hidesPrivateContent,
                libraryID: session.current?.library?.id,
                setting: setting,
                onCreate: createPerson
            )
        }
        .searchable(text: $navigation.personFilter.searchText, prompt: "Rechercher une personne")
        .task(id: session.current?.id) { setting = storedSetting }
        .onChange(of: setting) { _, new in
            PosterSettingStore.save(new, profileID: session.current?.id, context: .people)
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            PersonFilterSheet(filter: $navigation.personFilter)
        }
        .sheet(item: $editedPerson) { person in
            PersonEditor(person: person)
                // Même garde que sur les titres : fermer la feuille par glissement n'appelle
                // pas « Annuler », donc une personne créée puis abandonnée resterait dans la
                // bibliothèque, sans nom, en tête du tri alphabétique.
                .onDisappear { discardIfUnnamed(person) }
        }
    }

    // MARK: Les actions de l'en-tête — bloc `4c` : Trier · Filtres · Affichage · ＋ Nouvelle

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: Space.s5) {
            sortMenu
            filterButton
            displayMenu
            Button("Nouvelle", action: createPerson)
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Trier par", selection: sortBinding) {
                ForEach(PersonSortField.allCases) { field in
                    Label(field.label, systemImage: field.symbol).tag(field)
                }
            }
            Divider()
            Picker("Ordre", selection: ascendingBinding) {
                Text("Croissant").tag(true)
                Text("Décroissant").tag(false)
            }
        } label: {
            Text("Trier").actionStyle().foregroundStyle(Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    private var filterButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            Text(navigation.personFilter.isActive ? "Filtres · actifs" : "Filtres")
                .actionStyle()
                .foregroundStyle(navigation.personFilter.isActive ? Color.accent : Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

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
            Text("Affichage").actionStyle().foregroundStyle(Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    /// La rangée de filtres actifs, en **jetons de `I5`**.
    ///
    /// **Différence assumée avec la grille des titres**, qui pose encore un `StateBadge` : ce
    /// contournement datait de l'absence de `FilterChip`, livré depuis. L'écart inscrit dit
    /// « les deux écrans qui contournaient restent à reprendre » — celui-ci naît après le
    /// composant, donc il n'a aucune raison de naître avec la dette.
    @ViewBuilder
    private var activeFilters: some View {
        if navigation.personFilter.isActive {
            HStack(spacing: Space.s2) {
                ForEach(activeChips) { chip in
                    // `isOn: true` — la rangée ne montre que les filtres **actifs**, donc
                    // chaque jeton y est retenu par construction. La croix est le geste utile ;
                    // l'action de bascule fait la même chose, pour que le jeton entier reste
                    // une cible de 44 pt.
                    FilterChip(
                        LocalizedStringKey(chip.label), isOn: true, onRemove: chip.remove,
                        action: chip.remove)
                }
                Button("Tout effacer") { navigation.personFilter.clear() }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textTertiary)
                    .frame(minHeight: Space.minHitTarget)
                Spacer(minLength: Space.s4)
            }
            .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        }
    }

    /// Un jeton par critère actif, avec sa croix de retrait.
    ///
    /// Le genre n'y figure pas sous son nom : la vue n'a que son `UUID`, et résoudre le nom
    /// demanderait un `fetch` par rendu. « Genre » suffit à dire qu'un filtre porte, et la
    /// croix le retire — c'est ce que le jeton doit faire.
    private var activeChips: [ActiveChip] {
        var chips: [ActiveChip] = []
        if let role = navigation.personFilter.role {
            chips.append(
                .init(id: "role", label: roleLabel(role)) {
                    navigation.personFilter.role = nil
                })
        }
        if let band = navigation.personFilter.ageBand {
            chips.append(
                .init(id: "age", label: band.label) {
                    navigation.personFilter.ageBand = nil
                })
        }
        if navigation.personFilter.genreID != nil {
            chips.append(
                .init(id: "genre", label: "Genre") {
                    navigation.personFilter.genreID = nil
                })
        }
        if navigation.personFilter.showsArchived {
            chips.append(
                .init(id: "archived", label: "Archivées") {
                    navigation.personFilter.showsArchived = false
                })
        }
        return chips
    }

    /// Un jeton de filtre actif. **Un type nommé plutôt qu'un tuple** : à trois membres, un
    /// tuple se lit `chip.1` et `chip.2` sur le site d'appel, et `large_tuple` a raison de le
    /// refuser — on ne sait plus lequel est le libellé.
    private struct ActiveChip: Identifiable {
        let id: String
        let label: String
        let remove: () -> Void
    }

    private func roleLabel(_ role: PersonRole) -> String {
        switch role {
        case .actor: "Interprétation"
        case .director: "Réalisation"
        case .writer: "Écriture"
        case .crew: "Équipe"
        case .social: "Compte"
        }
    }

    // MARK: Liaisons

    private var sortBinding: Binding<PersonSortField> {
        Binding(
            get: { navigation.personFilter.sort }, set: { navigation.personFilter.sort = $0 })
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(
            get: { navigation.personFilter.ascending },
            set: { navigation.personFilter.ascending = $0 })
    }

    private var layoutBinding: Binding<CardLayout> {
        Binding(get: { setting.layout }, set: { setting.layout = $0 })
    }

    private var sizeBinding: Binding<CardSize> {
        Binding(get: { setting.size }, set: { setting.size = $0 })
    }

    private var storedSetting: PosterSetting {
        PosterSettingStore.setting(profileID: session.current?.id, context: .people)
    }

    private func discardIfUnnamed(_ person: Person) {
        guard person.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            person.deletedAt == nil
        else { return }
        PersonRepository(context: modelContext).softDelete(person)
    }

    private func createPerson() {
        guard let library = session.current?.library else { return }
        editedPerson = PersonRepository(context: modelContext).create(firstName: "", in: library)
    }
}
