import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V4 · La grille des personnes
//
// Relevée sur la planche 3 bloc `4c`. **Le même découpage que `TitlesGrid`, et pour la même
// raison** : un `@Query` à prédicat dynamique ne se réévalue qu'à la reconstruction de la vue
// qui le déclare. `PeopleView` porte l'en-tête et les réglages, cette vue porte la requête.
//
// **Ce qui change par rapport aux titres tient en deux points, et aucun n'est mécanique :**
//
// 1. **La tuile porte son nom.** `PersonTile` (`I2`) affiche le nom et le rôle sous un
//    disque, là où `PosterTile` ne met rien sous l'affiche. Ce n'est pas une incohérence :
//    une affiche se reconnaît, un visage rarement — et le §11 du handoff dit qu'aucun
//    portrait n'existe, donc le repli est les initiales.
// 2. **Le tri par crédits se termine en mémoire.** SwiftData ne trie pas sur le compte d'une
//    relation ; `PersonSortField.sortsInMemory` le dit, et la vue finit le travail sur la
//    page qu'elle a déjà en main.
//
// **Ce qui ne peut pas être rendu** : « 41 doublons possibles », que le bloc `4c` écrit dans
// son en-tête. Le compte vient de la détection de doublons de `L8`, reportée en v1.1 — et
// l'écran de fusion de `V4` est reporté avec elle, la fiche du report le nomme.

struct PeopleGrid: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    @Query private var people: [Person]

    private let filter: PersonFilter
    private let setting: PosterSetting
    private let onCreate: () -> Void

    init(
        filter: PersonFilter,
        hidingPrivate: Bool,
        libraryID: UUID?,
        setting: PosterSetting,
        onCreate: @escaping () -> Void
    ) {
        self.filter = filter
        self.setting = setting
        self.onCreate = onCreate
        _people = Query(
            filter: filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID),
            sort: filter.descriptors
        )
    }

    var body: some View {
        Group {
            if sorted.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                AdaptiveTileGrid(cards, cardWidth: setting.scale(in: .people).width) { card in
                    PersonTile(card, scale: setting.scale(in: .people)) {
                        open(card)
                    }
                    .contextMenu { menu(for: card) }
                }
            }
        }
        .task(id: filter.genreID) { discardFilterOnMissingGenre() }
    }

    /// Les deux états vides, comme sur la grille des titres.
    ///
    /// La copie appartient à l'écran, jamais au composant : `EmptyState` prend des paramètres
    /// et non des cas, précisément pour que « aucune personne » et « le filtre ne laisse rien
    /// passer » puissent dire deux choses différentes.
    @ViewBuilder private var emptyState: some View {
        if filter.isActive {
            EmptyState(
                title: "Aucune personne ne correspond",
                message:
                    "Les filtres actifs ne laissent rien passer. Retires-en un pour voir plus large.",
                primary: .init("Réinitialiser les filtres") { navigation.personFilter.clear() })
        } else {
            EmptyState(
                title: "Aucune personne pour l'instant",
                message:
                    "Les personnes arrivent avec le casting de tes titres, ou s'ajoutent à la main.",
                primary: .init("Nouvelle personne") { onCreate() })
        }
    }

    /// La page, triée une dernière fois quand le magasin ne sait pas le faire.
    ///
    /// **Le tri en mémoire ne porte que sur la page rendue**, et c'est une limite qu'il faut
    /// dire plutôt que masquer : sur une bibliothèque paginée, « la personne la plus créditée »
    /// serait celle de la page, pas du catalogue. Ici la requête n'est pas paginée — la grille
    /// rend tout ce que le filtre laisse passer — donc l'ordre est complet.
    private var sorted: [Person] {
        guard filter.sort.sortsInMemory else { return people }
        let ascending = filter.ascending
        return people.sorted { left, right in
            let leftCount = left.credits?.count ?? 0
            let rightCount = right.credits?.count ?? 0
            // À compte égal, `sortName` départage — sans quoi deux personnes à quatre crédits
            // s'échangeraient de place à chaque réévaluation, et la grille scintillerait.
            guard leftCount != rightCount else { return left.sortName < right.sortName }
            return ascending ? leftCount < rightCount : leftCount > rightCount
        }
    }

    private var cards: [PosterCardModel] {
        sorted.map(PosterCardModel.init)
    }

    private var byID: [UUID: Person] {
        Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Ouverture et actions

    private func open(_ card: PosterCardModel) {
        guard let id = UUID(uuidString: card.id) else { return }
        navigation.open(.person(id), within: sorted.map { AppRoute.person($0.id) })
    }

    @ViewBuilder
    private func menu(for card: PosterCardModel) -> some View {
        if let id = UUID(uuidString: card.id), let person = byID[id] {
            Button("Ouvrir") { open(card) }
            Divider()
            Button(person.isArchived ? "Désarchiver" : "Archiver") {
                PersonRepository(context: modelContext)
                    .update(person, journal: .perEntity) { $0.isArchived.toggle() }
            }
            Button("Supprimer", role: .destructive) {
                PersonRepository(context: modelContext).softDelete(person)
            }
        }
    }

    /// Même assainissement que sur la grille des titres : un filtre porte un `UUID`, pas une
    /// référence, donc il continue de restreindre pour de bon quand son genre disparaît — et
    /// l'incohérence survit au redémarrage, puisque le filtre est persisté.
    private func discardFilterOnMissingGenre() {
        guard let id = filter.genreID else { return }
        guard let found = try? modelContext.fetch(FetchDescriptor<Genre>()) else { return }
        if !found.contains(where: { $0.id == id }) { navigation.personFilter.genreID = nil }
    }
}
