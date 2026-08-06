import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V5b · Collections et genres épinglés
//
// Planche 3 bloc `4e`. **Son en-tête décide de ce que cet écran possède** : « 38 rayons ·
// 14 genres épinglés ». Un écran qui compte des objets dans son sous-titre les possède, et
// c'est la seule mention d'épinglage de tout le paquet de design — vérifié, une occurrence
// dans les onze planches.
//
// **C'est ce qui tranche la lacune ouverte depuis `V0`.** L'accueil affiche des rails « Mes
// genres · Drame » depuis `V5a`, et **aucun écran ne permettait d'épingler** : `Genre.isPinned`
// et `pinIndex` étaient posés à la fermeture du schéma, lus par `HomeView`, et jamais écrits.
// `GenreRepository.setPinned` est écrit par cette tâche, la section ci-dessous l'appelle.
//
// **Pourquoi ici et pas ailleurs**, en une ligne : un genre épinglé n'est pas une entrée de
// navigation — `V5a` l'a établi — c'est **la configuration de l'accueil**. Il vit donc à côté
// des rayons, qui sont l'autre façon dont l'utilisateur organise sa bibliothèque. Les deux
// candidats écartés : la barre de navigation n'a pas de section « Genres », et la console les
// liste comme entité (« Genres 62 ») sans rien y épingler.

struct CollectionsView: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TitleCollection.name) private var allCollections: [TitleCollection]
    @Query(filter: GenreQuery.living, sort: \Genre.name) private var allGenres: [Genre]

    @State private var setting = PosterContext.collections.defaultSetting
    @State private var sort: CollectionSort = .name
    @State private var ascending = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            ScreenHeader(section: .collections, count: countLabel) { actions }
            shelves
            genreSection
        }
        .padding(.bottom, Space.s7)
        .task(id: session.current?.id) { setting = storedSetting }
        .onChange(of: setting) { _, new in
            PosterSettingStore.save(new, profileID: session.current?.id, context: .collections)
        }
    }

    /// « 38 rayons · 14 genres épinglés », littéralement le sous-titre du bloc `4e`.
    private var countLabel: String {
        let shelfCount = collections.count
        let pinnedCount = allGenres.count { $0.isPinned && !$0.isArchived }
        let shelves = shelfCount == 1 ? "1 rayon" : "\(shelfCount) rayons"
        let pinned = pinnedCount == 1 ? "1 genre épinglé" : "\(pinnedCount) genres épinglés"
        return "\(shelves) · \(pinned)"
    }

    // MARK: Les actions — bloc `4e` : Trier · Affichage · ＋ Nouvelle collection
    //
    // **Pas de « Filtres ».** Le bloc `4e` n'en montre pas, contrairement au `4c` des
    // personnes : trente-huit rayons se parcourent des yeux. Ne pas en ajouter est une lecture
    // du prototype, pas un manque.

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: Space.s5) {
            sortMenu
            displayMenu
            Button("Nouvelle collection", action: createCollection)
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Trier par", selection: $sort) {
                ForEach(CollectionSort.allCases) { field in
                    Label(field.label, systemImage: field.symbol).tag(field)
                }
            }
            Divider()
            Picker("Ordre", selection: $ascending) {
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

    // MARK: Les rayons

    @ViewBuilder
    private var shelves: some View {
        if collections.isEmpty {
            EmptyState(
                title: "Aucun rayon pour l'instant",
                message:
                    "Un rayon regroupe des titres : une saga, un réalisateur, une étagère réelle.",
                primary: .init("Nouvelle collection") { createCollection() }
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            AdaptiveTileGrid(
                collections.map(CollectionTileModel.init),
                cardWidth: setting.scale(in: .collections).width
            ) { model in
                CollectionTile(model, scale: setting.scale(in: .collections)) {
                    open(model)
                }
                .contextMenu { menu(for: model) }
            }
        }
    }

    /// Les rayons visibles, triés selon le menu.
    ///
    /// **Le tri par nombre de titres se fait en mémoire**, comme celui des personnes par
    /// crédits, et pour la même raison : SwiftData ne trie pas sur le compte d'une relation.
    private var collections: [TitleCollection] {
        let hidesPrivate = session.current?.hidesPrivateContent ?? false
        let libraryID = session.current?.library?.id
        let visible = allCollections.filter { collection in
            guard collection.deletedAt == nil else { return false }
            if hidesPrivate, collection.isPrivate { return false }
            if let libraryID, collection.library?.id != libraryID { return false }
            return true
        }
        return visible.sorted { left, right in
            switch sort {
            case .name:
                return ascending ? left.name < right.name : left.name > right.name
            case .count:
                let leftCount = left.titles?.count ?? 0
                let rightCount = right.titles?.count ?? 0
                // À compte égal, le nom départage — sinon deux rayons de neuf titres
                // s'échangeraient de place à chaque rendu.
                if leftCount == rightCount { return left.name < right.name }
                return ascending ? leftCount < rightCount : leftCount > rightCount
            case .added:
                return ascending
                    ? left.createdAt < right.createdAt : left.createdAt > right.createdAt
            }
        }
    }

    // MARK: La section des genres — c'est ici qu'on épingle

    /// Tous les genres de titres, avec leur bascule d'épinglage.
    ///
    /// **Les genres épinglés remontent en tête, dans leur ordre de `pinIndex`**, et c'est ce
    /// qui rend la section lisible : l'utilisateur voit d'abord la configuration de son
    /// accueil, telle qu'elle apparaîtra. Le reste suit par ordre alphabétique.
    @ViewBuilder
    private var genreSection: some View {
        if !visibleGenres.isEmpty {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
                    Text("Genres")
                        .title2Style()
                        .foregroundStyle(Color.textPrimary)
                    Text("\(visibleGenres.count)")
                        .numericStyle()
                        .foregroundStyle(Color.textTertiary)
                    Spacer(minLength: Space.s4)
                }

                Text("Un genre épinglé devient un rail de l'accueil.")
                    .calloutStyle()
                    .foregroundStyle(Color.textTertiary)

                ForEach(orderedGenres, id: \.persistentModelID) { genre in
                    genreRow(genre)
                }
            }
            .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        }
    }

    private func genreRow(_ genre: Genre) -> some View {
        HStack(spacing: Space.s3) {
            Button {
                navigation.titleFilter.genreID = genre.id
                navigation.section = .titles
            } label: {
                Text(genre.name)
                    .calloutStyle()
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Text(titleCountLabel(of: genre))
                .numericStyle()
                .foregroundStyle(Color.textTertiary)

            // **La bascule dit son état, pas une action.** « Épinglé » allumé se lit comme
            // une propriété du genre ; « Épingler » se lirait comme un bouton dont on ne sait
            // pas s'il a déjà été pressé.
            Toggle("Épinglé", isOn: pinBinding(for: genre))
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("Épingler \(genre.name) à l'accueil")
        }
        .frame(minHeight: Space.minHitTarget)
    }

    private func pinBinding(for genre: Genre) -> Binding<Bool> {
        Binding(
            get: { genre.isPinned },
            // L'écriture passe par le repository : c'est lui qui tient `pinIndex` et qui
            // journalise. Une vue qui écrirait `genre.isPinned` directement laisserait le rang
            // à zéro, et tous les rails de l'accueil se retrouveraient au même.
            set: { GenreRepository(context: modelContext).setPinned(genre, $0) }
        )
    }

    /// Les genres ciblant les **titres**, vivants et non archivés.
    ///
    /// Ceux des personnes et des signets n'ont rien à faire ici : l'accueil n'en fait pas de
    /// rails, donc les épingler ne produirait rien de visible.
    private var visibleGenres: [Genre] {
        allGenres.filter { genre in
            guard genre.target == .title, !genre.isArchived else { return false }
            #if DEBUG
                if genre.name == DemoCatalog.markerGenreName { return false }
            #endif
            return true
        }
    }

    private var orderedGenres: [Genre] {
        let pinned = visibleGenres.filter(\.isPinned).sorted { $0.pinIndex < $1.pinIndex }
        let rest = visibleGenres.filter { !$0.isPinned }.sorted { $0.name < $1.name }
        return pinned + rest
    }

    private func titleCountLabel(of genre: Genre) -> String {
        let count = (genre.titles ?? []).count { $0.deletedAt == nil }
        return count == 1 ? "1 titre" : "\(count) titres"
    }

    // MARK: Actions et liaisons

    private func open(_ model: CollectionTileModel) {
        guard let id = UUID(uuidString: model.id) else { return }
        navigation.open(.collection(id), within: collections.map { AppRoute.collection($0.id) })
    }

    @ViewBuilder
    private func menu(for model: CollectionTileModel) -> some View {
        if let collection = collection(for: model) {
            Button("Ouvrir") { open(model) }
            Divider()
            Button("Supprimer", role: .destructive) {
                CollectionRepository(context: modelContext).softDelete(collection)
            }
        }
    }

    private func collection(for model: CollectionTileModel) -> TitleCollection? {
        guard let id = UUID(uuidString: model.id) else { return nil }
        return collections.first { $0.id == id }
    }

    private func createCollection() {
        guard let library = session.current?.library else { return }
        let created = CollectionRepository(context: modelContext)
            .create(name: "Nouveau rayon", in: library)
        navigation.open(.collection(created.id))
    }

    private var layoutBinding: Binding<CardLayout> {
        Binding(get: { setting.layout }, set: { setting.layout = $0 })
    }

    private var sizeBinding: Binding<CardSize> {
        Binding(get: { setting.size }, set: { setting.size = $0 })
    }

    private var storedSetting: PosterSetting {
        PosterSettingStore.setting(profileID: session.current?.id, context: .collections)
    }
}

/// Les critères de tri des rayons — bloc `4e`, « Trier ▾ ».
///
/// **Ici et non dans `CineShelfCore`**, contrairement à `PersonSortField` : il n'existe pas de
/// `CollectionFilter`, l'écran n'a pas de prédicat dynamique, et rien d'autre que cet écran
/// n'a besoin de trier des rayons. Le descendre serait du code « au cas où ».
enum CollectionSort: String, CaseIterable, Identifiable {
    case name
    case count
    case added

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "Nom"
        case .count: "Nombre de titres"
        case .added: "Ajout"
        }
    }

    var symbol: String {
        switch self {
        case .name: "textformat"
        case .count: "film.stack"
        case .added: "clock"
        }
    }
}
