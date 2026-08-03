import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// La grille elle-même : une requête, une conversion, un `CatalogGrid`.
///
/// Le `@Query` est construit dans l'`init` à partir du filtre — c'est la seule
/// façon d'avoir un prédicat dynamique en SwiftData. La vue est donc recréée
/// quand le filtre change, ce dont `TitlesView` se charge.
struct TitlesGrid: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query private var titles: [Title]

    private let filter: TitleFilter
    private let display: CardDisplaySetting
    private let onEdit: (Title) -> Void
    private let onCreate: () -> Void

    @Namespace private var namespace

    init(
        filter: TitleFilter,
        hidingPrivate: Bool,
        display: CardDisplaySetting,
        onEdit: @escaping (Title) -> Void,
        onCreate: @escaping () -> Void
    ) {
        self.filter = filter
        self.display = display
        self.onEdit = onEdit
        self.onCreate = onCreate
        _titles = Query(
            filter: filter.predicate(hidingPrivate: hidingPrivate),
            sort: filter.descriptors
        )
    }

    /// Ce que le `#Predicate` ne sait pas exprimer, appliqué après le fetch.
    ///
    /// Calculé **une fois** par passe de rendu et non à chaque accès : une
    /// propriété calculée referait le filtrage deux fois pour le corps, puis une
    /// fois par carte visible via `actions(for:)`. Sur les 2 000 jaquettes du
    /// budget de `docs/04` §4, cela faisait des dizaines de milliers
    /// d'itérations par image, sur le thread principal.
    private struct Visible {
        let titles: [Title]
        let byID: [UUID: Title]

        init(_ titles: [Title], filter: TitleFilter) {
            let filtered = titles.filter(filter.matches)
            self.titles = filtered
            byID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        }
    }

    var body: some View {
        let visible = Visible(titles, filter: filter)

        return Group {
            if visible.titles.isEmpty {
                // `noTitles` porte un bouton « Ajouter un film » : sans action,
                // c'est le premier écran de l'app qui ne répond pas.
                StateView(filter.isActive ? .noResults : .noTitles) {
                    if filter.isActive { clearFilter() } else { onCreate() }
                }
            } else {
                ScrollView {
                    CatalogGrid(
                        items: visible.titles.map { PosterCardModel($0, flag: flag(for: $0)) },
                        setting: display,
                        in: namespace,
                        actions: { actions(for: $0, in: visible) },
                        onOpen: { open($0, in: visible) }
                    )
                    .padding(.horizontal, Space.pageMargin(compact: isCompact))
                    .padding(.vertical, Space.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
        .task(id: filter.genreID) { discardFilterOnMissingGenre() }
        .task(id: filter.collectionID) { discardFilterOnMissingCollection() }
    }

    // MARK: Assainissement des filtres
    //
    // Un filtre porte un `UUID`, pas une référence. Si l'entité visée disparaît
    // — mise à la corbeille, supprimée depuis un autre appareil — le filtre
    // continue de restreindre la liste pour de bon, alors que le sélecteur ne
    // propose plus l'entrée correspondante : la grille est vide, l'icône de
    // filtre est allumée, et rien n'explique pourquoi. Le filtre étant persisté,
    // l'incohérence survit même au redémarrage.

    private func discardFilterOnMissingGenre() {
        guard let id = filter.genreID, !entityExists(FetchDescriptor<Genre>(), matching: id) else {
            return
        }
        navigation.titleFilter.genreID = nil
    }

    private func discardFilterOnMissingCollection() {
        guard let id = filter.collectionID,
            !entityExists(FetchDescriptor<TitleCollection>(), matching: id)
        else { return }
        navigation.titleFilter.collectionID = nil
    }

    /// Une entité visible porte-t-elle cet identifiant ?
    ///
    /// Le filtre en mémoire plutôt qu'un prédicat par type : deux entités, deux
    /// prédicats à écrire, pour une requête qui ne rend au plus que quelques
    /// dizaines de lignes.
    private func entityExists<T: PersistentModel & Identifiable>(
        _ descriptor: FetchDescriptor<T>, matching id: UUID
    ) -> Bool where T.ID == UUID {
        guard let found = try? modelContext.fetch(descriptor) else { return true }
        return found.contains { $0.id == id }
    }

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        private var isCompact: Bool { horizontalSizeClass == .compact }
    #else
        private var isCompact: Bool { false }
    #endif

    // MARK: Ouverture

    /// Ouvre une fiche **en passant la liste visible** : c'est ce qui donne à
    /// ⌥↑ / ⌥↓ quelque chose à parcourir, et c'est pour cela que la collection
    /// respecte les filtres et le tri en cours.
    private func open(_ card: PosterCardModel, in visible: Visible) {
        guard let id = UUID(uuidString: card.id) else { return }
        navigation.open(.title(id), within: visible.titles.map { AppRoute.title($0.id) })
    }

    // MARK: Actions de carte
    //
    // Toutes les écritures passent par un repository : `docs/04` §3 impose
    // qu'aucune ne contourne `refreshDerived()`.

    private func actions(for card: PosterCardModel, in visible: Visible) -> PosterCardActions {
        guard let id = UUID(uuidString: card.id), let title = visible.byID[id] else { return .init() }

        return PosterCardActions(
            toggleFavorite: { flags?.toggleFavorite(title) },
            toggleWatchlist: { flags?.toggleWatchlist(title) },
            toggleWatched: { flags?.toggleWatched(title) },
            edit: { onEdit(title) },
            archive: {
                TitleRepository(context: modelContext).update(title) {
                    $0.isArchived.toggle()
                }
            },
            delete: { TitleRepository(context: modelContext).softDelete(title) }
        )
    }

    private func flag(for title: Title) -> TitleFlag? {
        guard let profileID = session.current?.id else { return nil }
        return title.flags?.first { $0.profile?.id == profileID }
    }

    private var flags: FlagRepository? {
        session.current.map { FlagRepository(context: modelContext, profile: $0) }
    }

    private func clearFilter() {
        navigation.titleFilter.clear()
    }
}
