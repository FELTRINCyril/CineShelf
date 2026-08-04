import Foundation
import SwiftData

/// Les portées de la recherche — `docs/03` §9.
public enum SearchScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case titles
    case people
    case collections
    case savedLinks

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: "Tout"
        case .titles: "Titres"
        case .people: "Personnes"
        case .collections: "Collections"
        case .savedLinks: "Signets"
        }
    }

    /// Cette portée interroge-t-elle ce type ?
    func includes(_ other: SearchScope) -> Bool {
        self == .all || self == other
    }
}

/// Ce qu'une recherche peut rendre. **Deux états, et c'est volontaire.**
///
/// `idle` n'est pas « zéro résultat » : c'est « aucun terme saisi ». La distinction
/// n'est pas cosmétique, elle commande deux interfaces différentes — un champ vide
/// doit montrer les recherches récentes, un champ rempli sans correspondance doit
/// afficher « aucun résultat ». Les confondre donne soit un écran vide inexplicable,
/// soit le catalogue entier affiché sous un champ vide.
///
/// **Pourquoi un `enum` et non une convention.** Une convention du genre
/// « `SearchResults` vide signifie qu'on n'a rien saisi » se perd : quelqu'un écrit
/// `if results.isEmpty` et confond les deux cas, sans que rien ne le signale. Ici le
/// compilateur force l'appelant à écrire les deux branches.
///
/// **Et pourquoi deux états et non trois.** « Aucune correspondance » ne mérite pas
/// son propre cas : il se déduit de `SearchResults.isEmpty`. Un troisième état serait
/// une seconde source de vérité pour le même fait, donc quelque chose à
/// désynchroniser.
///
/// La décision appartient au service et non à l'appelant : la règle — terme vide, ou
/// réduit à des espaces, donne `idle` — vit à un seul endroit, et `V1` ne peut pas
/// l'oublier.
@MainActor
public enum SearchOutcome {
    /// Aucun terme saisi, ou rien que des espaces.
    case idle
    /// Un terme a été saisi. Les groupes peuvent être vides.
    case results(SearchResults)
}

/// Les résultats d'une recherche, groupés par type.
@MainActor
public struct SearchResults {

    /// Un groupe de résultats : une tranche affichable, et le compte complet.
    ///
    /// Les deux sont nécessaires et ne se déduisent pas l'un de l'autre — c'est ce qui
    /// permet d'écrire « 12 titres » sous une liste qui n'en montre que cinq, et de
    /// proposer « tout voir ». Le compte vient d'un `fetchCount`, qui ne matérialise
    /// aucun objet.
    public struct Group<Item> {
        public let items: [Item]
        public let total: Int

        public var isEmpty: Bool { total == 0 }
        /// `true` si la tranche ne montre pas tout.
        public var isTruncated: Bool { total > items.count }

        init(items: [Item] = [], total: Int = 0) {
            self.items = items
            self.total = total
        }
    }

    public let titles: Group<Title>
    public let people: Group<Person>
    public let collections: Group<TitleCollection>
    public let savedLinks: Group<SavedLink>

    /// Le nombre total de correspondances, toutes portées confondues.
    public var total: Int {
        titles.total + people.total + collections.total + savedLinks.total
    }

    /// `true` quand le terme saisi ne correspond à rien. À ne pas confondre avec
    /// `SearchOutcome.idle`, qui dit qu'aucun terme n'a été saisi.
    public var isEmpty: Bool { total == 0 }
}

/// La recherche : « texte + portée → résultats groupés », sans `.searchable`.
///
/// **Ce que ce service ne fait pas.** Il n'a pas d'anti-rebond : c'est une fonction,
/// appelable à chaque frappe, et c'est la vue qui décide quand l'appeler. Mettre le
/// rebond ici le rendrait intestable et imposerait un rythme à des appelants qui n'ont
/// pas les mêmes contraintes — un `App Intent` de `L19` n'a pas de frappe à amortir.
///
/// **La visibilité n'est pas réimplémentée** : les titres passent par `TitleFilter`,
/// les personnes par `PersonFilter`, exactement ceux que la grille et la liste
/// utilisent. Un second chemin de visibilité finirait par divergerdu premier, et ce
/// jour-là la recherche montrerait un contenu privé que la grille masque.
@MainActor
public struct SearchService {

    /// La limite par groupe. Dix suffit à remplir une section de suggestions, et le
    /// compte complet reste disponible dans `Group.total`.
    public static let defaultLimitPerGroup = 10

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Cherche `text` dans la portée demandée.
    ///
    /// - Parameters:
    ///   - text: le terme brut, tel que saisi. Il est replié ici — sans accents, sans
    ///     casse — pour correspondre à `searchText`, qui l'est à l'écriture.
    ///   - scope: la portée. `.all` interroge les quatre types.
    ///   - hidingPrivate: le profil actif masque les entités privées.
    ///   - libraryID: la bibliothèque du profil actif. `nil` ne filtre pas.
    ///   - limitPerGroup: la taille de la tranche rendue par groupe.
    /// - Returns: `.idle` si le terme est vide ou ne contient que des espaces, sinon
    ///   `.results`, dont les groupes hors portée sont vides.
    /// - Throws: ce que remonte `ModelContext.fetch`.
    public func search(
        _ text: String,
        scope: SearchScope = .all,
        hidingPrivate: Bool,
        libraryID: UUID?,
        limitPerGroup: Int = defaultLimitPerGroup
    ) throws -> SearchOutcome {
        // Le repliage vient **après** le retrait des espaces : un terme réduit à des
        // espaces est `idle`, pas une recherche de chaîne vide qui ne matcherait
        // aucune ligne en SQL.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .idle }

        let term = trimmed.foldedForMatching

        // Une portée hors périmètre rend un groupe vide **sans requête** : c'est ce qui
        // fait que `.titles` coûte moins que `.all`, et non un filtrage après coup.
        let titles =
            scope.includes(.titles)
            ? try titles(
                term: text, hidingPrivate: hidingPrivate, libraryID: libraryID, limit: limitPerGroup)
            : SearchResults.Group<Title>()
        let people =
            scope.includes(.people)
            ? try people(
                term: text, hidingPrivate: hidingPrivate, libraryID: libraryID, limit: limitPerGroup)
            : SearchResults.Group<Person>()
        let collections =
            scope.includes(.collections)
            ? try collections(
                term: term, hidingPrivate: hidingPrivate, libraryID: libraryID, limit: limitPerGroup)
            : SearchResults.Group<TitleCollection>()
        let savedLinks =
            scope.includes(.savedLinks)
            ? try savedLinks(
                term: term, hidingPrivate: hidingPrivate, libraryID: libraryID, limit: limitPerGroup)
            : SearchResults.Group<SavedLink>()

        return .results(
            SearchResults(
                titles: titles, people: people, collections: collections, savedLinks: savedLinks)
        )
    }

    // MARK: Une portée par type
    //
    // Les titres et les personnes reçoivent le terme **brut** : leurs filtres le
    // replient eux-mêmes, et le replier deux fois serait sans effet mais trompeur sur
    // qui porte la responsabilité. Les collections et les signets reçoivent le terme
    // déjà replié, parce que leurs prédicats de `EntityQueries` ne le font pas.

    private func titles(
        term: String, hidingPrivate: Bool, libraryID: UUID?, limit: Int
    ) throws -> SearchResults.Group<Title> {
        var filter = TitleFilter()
        filter.searchText = term
        let predicate = filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID)

        var descriptor = FetchDescriptor<Title>(
            predicate: predicate, sortBy: [SortDescriptor(\.sortName)])
        descriptor.fetchLimit = limit

        return .init(
            items: try context.fetch(descriptor),
            total: try context.fetchCount(FetchDescriptor<Title>(predicate: predicate))
        )
    }

    private func people(
        term: String, hidingPrivate: Bool, libraryID: UUID?, limit: Int
    ) throws -> SearchResults.Group<Person> {
        var filter = PersonFilter()
        filter.searchText = term
        let predicate = filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID)

        var descriptor = FetchDescriptor<Person>(
            predicate: predicate, sortBy: [SortDescriptor(\.sortName)])
        descriptor.fetchLimit = limit

        return .init(
            items: try context.fetch(descriptor),
            total: try context.fetchCount(FetchDescriptor<Person>(predicate: predicate))
        )
    }

    private func collections(
        term: String, hidingPrivate: Bool, libraryID: UUID?, limit: Int
    ) throws -> SearchResults.Group<TitleCollection> {
        let predicate = CollectionQuery.matching(
            term: term, hidingPrivate: hidingPrivate, libraryID: libraryID)

        var descriptor = FetchDescriptor<TitleCollection>(
            predicate: predicate, sortBy: [SortDescriptor(\.sortName)])
        descriptor.fetchLimit = limit

        return .init(
            items: try context.fetch(descriptor),
            total: try context.fetchCount(FetchDescriptor<TitleCollection>(predicate: predicate))
        )
    }

    private func savedLinks(
        term: String, hidingPrivate: Bool, libraryID: UUID?, limit: Int
    ) throws -> SearchResults.Group<SavedLink> {
        let predicate = SavedLinkQuery.matching(
            term: term, hidingPrivate: hidingPrivate, libraryID: libraryID)

        var descriptor = FetchDescriptor<SavedLink>(
            predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit

        return .init(
            items: try context.fetch(descriptor),
            total: try context.fetchCount(FetchDescriptor<SavedLink>(predicate: predicate))
        )
    }
}
