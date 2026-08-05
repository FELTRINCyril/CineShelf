import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V0 bis · La grille des titres
//
// Relevée sur la planche 3 bloc `4a` :
//
//     <div style="display:grid;grid-template-columns:repeat(7,minmax(0,1fr));
//                 gap:18px;padding:0 36px;align-items:start">
//       <div style="min-width:0;aspect-ratio:2/3;background:oklch(0.16 0 0);
//                   overflow:hidden" style-hover="transform:scale(1.06)">…</div>
//
// **Rien sous les affiches.** Ni titre, ni note, ni bandeau au repos — c'est une décision
// arrêtée du §10, et c'est ce qui distingue cette grille de celle du banc d'essai, qui
// posait une légende sous chaque carte. La tuile de `I2` la tient déjà ; la grille n'a
// donc rien à ajouter, seulement à ne rien ajouter.
//
// **Le compte de colonnes n'est pas ici.** `AdaptiveTileGrid` (`I4`) le calcule à largeur
// de carte constante. Le `repeat(7, …)` du prototype est une largeur de rendu, pas une
// règle — la règle est celle de l'addendum 2 bloc `13c`.
//
// **Ce qui remplace quoi.** `CatalogGrid`, `PosterCard` et `DisplayMenu` — les trois
// composants du banc d'essai que cette vue utilisait — ne sont plus appelés. Ils restent
// dans `Legacy/` et `Components/` jusqu'à `V12`, mais plus rien de vivant ne les lit
// depuis cet écran.

struct TitlesGrid: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query private var titles: [Title]

    private let filter: TitleFilter
    private let setting: PosterSetting
    private let onCreate: () -> Void

    init(
        filter: TitleFilter,
        hidingPrivate: Bool,
        libraryID: UUID?,
        setting: PosterSetting,
        onCreate: @escaping () -> Void
    ) {
        self.filter = filter
        self.setting = setting
        self.onCreate = onCreate
        _titles = Query(
            filter: filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID),
            sort: filter.descriptors
        )
    }

    var body: some View {
        Group {
            if titles.isEmpty {
                // `EmptyState` (`I10`) remplace `StateView`, de l'ancienne direction, dont
                // les `case` portaient leur texte en dur dans `DesignSystem`. La copie
                // appartient a l'ecran : lui seul sait qu'un filtre est actif, et lequel.
                // C'etait l'ecart « l'etat vide de la grille utilise encore StateView ».
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                AdaptiveTileGrid(cards, cardWidth: setting.scale(in: .titles).width) { card in
                    PosterTile(card, layout: setting.layout, scale: setting.scale(in: .titles)) {
                        open(card)
                    }
                    .contextMenu { menu(for: card) }
                }
            }
        }
        .task(id: filter.genreID) { discardFilterOnMissingGenre() }
        .task(id: filter.collectionID) { discardFilterOnMissingCollection() }
    }

    /// L'état vide, et il en existe deux : « rien du tout » et « rien ne correspond ».
    ///
    /// Le bloc `9a` les rend séparément, avec deux messages et deux actions différentes —
    /// « Importe un CSV » n'a aucun sens quand la collection compte 1 284 titres dont aucun
    /// ne passe le filtre. C'est exactement ce qu'un composant à `case` fermés ne savait pas
    /// exprimer.
    @ViewBuilder private var emptyState: some View {
        if filter.isActive {
            EmptyState(
                title: "Aucun titre ne correspond",
                message: "Les filtres actifs ne laissent rien passer. Retires-en un pour voir plus large.",
                primary: .init("Réinitialiser les filtres") { clearFilter() })
        } else {
            EmptyState(
                title: "Aucun titre pour l'instant",
                message: "Ta collection est vide. Ajoute un premier film, ou importe un CSV.",
                primary: .init("Nouveau titre") { onCreate() },
                hint: "⇧⌘I pour l'import")
        }
    }

    /// Les cartes, et la correspondance identifiant → titre.
    ///
    /// Construites **une fois** par passe de rendu : une propriété calculée les
    /// reconstruirait pour le corps, puis une fois par carte visible. Sur les 2 000
    /// jaquettes du budget de `docs/04` §4, cela faisait des dizaines de milliers
    /// d'itérations par image, sur le thread principal.
    private var cards: [PosterCardModel] {
        titles.map { PosterCardModel($0, flag: flag(for: $0)) }
    }

    private var byID: [UUID: Title] {
        Dictionary(titles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Ouverture et actions

    /// Ouvre une fiche **en passant la liste visible** : c'est ce qui donne à ⌥↑ / ⌥↓
    /// quelque chose à parcourir, et c'est pour cela que la collection respecte les
    /// filtres et le tri en cours.
    private func open(_ card: PosterCardModel) {
        guard let id = UUID(uuidString: card.id) else { return }
        navigation.open(.title(id), within: titles.map { AppRoute.title($0.id) })
    }

    /// Les actions au menu contextuel.
    ///
    /// **Elles ne sont plus des pastilles posées sur la carte.** Le banc d'essai en
    /// affichait trois au survol ; la direction retenue ne met rien sur l'affiche au repos,
    /// et `PosterTileDetail` — la carte qui les porte — n'est pas ce que le bloc `4a`
    /// montre en grille. Le menu contextuel garde les gestes sans rien dessiner.
    @ViewBuilder
    private func menu(for card: PosterCardModel) -> some View {
        if let id = UUID(uuidString: card.id), let title = byID[id] {
            Button("Ouvrir") { open(card) }
            Divider()
            Button(card.isWatched ? "Marquer non vu" : "Marquer vu") {
                flags?.toggleWatched(title)
            }
            Button(card.isInWatchlist ? "Retirer de ma liste" : "Ajouter à ma liste") {
                flags?.toggleWatchlist(title)
            }
            Button(card.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris") {
                flags?.toggleFavorite(title)
            }
            Divider()
            Button(card.isArchived ? "Désarchiver" : "Archiver") {
                TitleRepository(context: modelContext)
                    .update(title, journal: .perEntity) { $0.isArchived.toggle() }
            }
            Button("Supprimer", role: .destructive) {
                TitleRepository(context: modelContext).softDelete(title)
            }
        }
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

    // MARK: Assainissement des filtres
    //
    // Un filtre porte un `UUID`, pas une référence. Si l'entité visée disparaît — mise à
    // la corbeille, supprimée depuis un autre appareil — le filtre continue de restreindre
    // la liste pour de bon, alors que le sélecteur ne propose plus l'entrée
    // correspondante : la grille est vide, le filtre est allumé, et rien ne l'explique.
    // Le filtre étant persisté, l'incohérence survit au redémarrage.

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

    private func entityExists<T: PersistentModel & Identifiable>(
        _ descriptor: FetchDescriptor<T>, matching id: UUID
    ) -> Bool where T.ID == UUID {
        guard let found = try? modelContext.fetch(descriptor) else { return true }
        return found.contains { $0.id == id }
    }
}
