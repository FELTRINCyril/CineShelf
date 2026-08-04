import Foundation
import SwiftData

// L'état de filtre et de tri de la liste des titres.
//
// **Il a vécu dans `App/Navigation/`**, parce que le prompt 11 exigeait qu'il soit
// restauré au lancement : c'est `NavigationModel` qui le porte et le sérialise, et le
// mettre dans `Features/Titles/` aurait créé un cycle. Il est descendu dans
// `CineShelfCore` avec `L2`, pour une raison qui l'emporte : le service de recherche
// en a besoin, et `CineShelfCore` ne peut pas dépendre de `App`.
//
// L'enjeu n'est pas le rangement. La recherche doit masquer exactement ce que la
// grille masque — corbeille, archivés, contenu privé, hors-bibliothèque — et un
// second chemin de visibilité finirait par divergerdu premier. Le seul moyen d'avoir
// une règle unique est que les deux appellent le même code.
//
// Conséquence assumée : `TitleSortField.symbol` rend des noms de SF Symbols depuis
// `CineShelfCore`. Même motif que `ProfileAccent`, dont le `rawValue` est un nom de
// jeu de couleurs — le paquet désigne une ressource du design system sans importer
// ni SwiftUI ni `DesignSystem`.

/// Les critères de tri de la liste des titres — `docs/03` §4.
public enum TitleSortField: String, CaseIterable, Identifiable, Codable, Sendable {
    case added
    case name
    case rating
    case release
    case runtime

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .added: "Ajout"
        case .name: "Titre"
        case .rating: "Note"
        case .release: "Sortie"
        case .runtime: "Durée"
        }
    }

    public var symbol: String {
        switch self {
        case .added: "clock"
        case .name: "textformat"
        case .rating: "star"
        case .release: "calendar"
        case .runtime: "timer"
        }
    }

    /// Les descripteurs SwiftData correspondants.
    ///
    /// Le tri secondaire sur `sortName` n'est pas cosmétique : sans lui, deux
    /// titres de même note ou de même année s'échangent de place à chaque
    /// réévaluation de la requête, et la grille scintille.
    public func descriptors(ascending: Bool) -> [SortDescriptor<Title>] {
        let order: SortOrder = ascending ? .forward : .reverse
        let byName = SortDescriptor(\Title.sortName, order: .forward)

        return switch self {
        case .added: [SortDescriptor(\Title.createdAt, order: order), byName]
        case .name: [SortDescriptor(\Title.sortName, order: order)]
        case .rating: [SortDescriptor(\Title.rating, order: order), byName]
        case .release: [SortDescriptor(\Title.releaseDate, order: order), byName]
        case .runtime: [SortDescriptor(\Title.runtimeMinutes, order: order), byName]
        }
    }
}

/// Les tranches de durée pré-réglées — `docs/03` §4.
public enum RuntimeBand: String, CaseIterable, Identifiable, Codable, Sendable {
    case short
    case medium
    case long

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .short: "Court (< 1 h 30)"
        case .medium: "Moyen (1 h 30 – 2 h)"
        case .long: "Long (> 2 h)"
        }
    }

    public var range: ClosedRange<Int> {
        switch self {
        case .short: 1...89
        case .medium: 90...120
        case .long: 121...10_000
        }
    }
}

/// Tout ce qui restreint la liste des titres.
///
/// `Codable` pour la restauration, `Equatable` pour que les vues sachent quand
/// reconstruire leur requête.
public struct TitleFilter: Codable, Equatable, Sendable {
    public var searchText: String = ""
    public var collectionID: UUID?
    public var genreID: UUID?
    public var personID: UUID?
    public var runtimeBand: RuntimeBand?
    public var minimumRuntime: Int?
    public var maximumRuntime: Int?
    public var minimumRating: Double?
    public var maximumRating: Double?
    public var showsArchived: Bool = false

    public var sort: TitleSortField = .added
    public var ascending: Bool = false

    /// L'initialiseur ne prend que le tri, et c'est ce qui fait marcher `isActive`
    /// et `clear()` : « aucun critère actif » se dit `TitleFilter(sort:ascending:)`,
    /// donc un critère ajouté à la structure entre automatiquement dans la
    /// comparaison. Un initialiseur exhaustif obligerait à penser à l'y ajouter.
    public init(sort: TitleSortField = .added, ascending: Bool = false) {
        self.sort = sort
        self.ascending = ascending
    }

    /// `true` dès qu'un critère restreint la liste. Le tri n'en fait pas partie :
    /// trier ne cache rien.
    public var isActive: Bool {
        self != TitleFilter(sort: sort, ascending: ascending)
    }

    /// Les bornes de durée effectives : la tranche pré-réglée l'emporte sur les
    /// bornes libres, parce que c'est elle que l'utilisateur vient de toucher.
    public var effectiveRuntime: (minimum: Int?, maximum: Int?) {
        if let band = runtimeBand {
            return (band.range.lowerBound, band.range.upperBound)
        }
        return (minimumRuntime, maximumRuntime)
    }

    public mutating func clear() {
        self = TitleFilter(sort: sort, ascending: ascending)
    }
}

// MARK: - Traduction en requête

extension TitleFilter {

    /// Le prédicat SwiftData correspondant. **Il porte tous les critères** :
    /// rien n'est plus filtré en mémoire.
    ///
    /// ### Pourquoi ce prédicat est construit à la main et non par `#Predicate`
    ///
    /// Parce que `#Predicate` ne sait pas en porter douze. Le plafond mesuré sur
    /// `Title` est de **cinq clauses**, et cinq coûtent déjà 1,3 s de
    /// vérification de types ; six échouent. Le détail des mesures et des deux
    /// hypothèses écartées en route est dans `predicateClause(active:_:)`, avec
    /// la façon de les reproduire.
    ///
    /// L'arbre ci-dessous est exactement celui que `#Predicate` aurait expansé —
    /// mêmes nœuds `build_*` — mais coupé par des `let` intermédiaires, ce qu'une
    /// macro d'expression ne peut pas faire. Chaque clause devient un problème
    /// d'inférence indépendant, et les douze passent sous les 200 ms.
    ///
    /// C'est verbeux, et c'est le prix du filtrage en SQL. La seule alternative
    /// était de continuer à rapatrier le catalogue entier pour le filtrer en
    /// Swift, ce que `L1` avait précisément pour objet de supprimer.
    ///
    /// > **Avant de toucher à cet arbre, lire le pari documenté dans
    /// > `predicateClause(active:_:)`.** En résumé : une rupture d'API de
    /// > `PredicateExpressions` ne compilerait pas, donc elle se verrait ; le vrai
    /// > risque est que SwiftData cesse de reconnaître la forme et retombe en
    /// > mémoire, ce qui laisserait **tous les tests de critères verts**. Le seul
    /// > garde-fou est
    /// > `TitleFilterPerformanceTests.selectiveFilterDoesNotScanEverything`.
    ///
    /// ### Les deux limites qui restent vraies
    ///
    /// - Les propriétés calculées (`kind`, `releaseYear`) ne sont pas utilisables
    ///   dans un prédicat : on filtre sur les colonnes brutes.
    /// - Les **traversées de relation optionnelle** (`title.collection?.id`)
    ///   restent à éviter — non par budget, mais parce qu'elles imposent une
    ///   jointure là où `Title.filterKeys` offre un `contains` sur une colonne.
    ///   Voir `FilterKey`.
    ///
    /// ### Le piège de la clause vide, et pourquoi il ne peut plus se produire
    ///
    /// `String.contains("")` est vrai en Swift mais `CONTAINS ''` ne matche
    /// **aucune** ligne en SQL : c'est ce qui avait vidé la grille en permanence
    /// derrière 42 tests verts. Chaque critère optionnel est donc gardé par
    /// `predicateClause(active:)`, qui neutralise la clause côté SQL quand le
    /// critère est inactif. Aucune clause ne s'applique jamais avec un opérande
    /// vide.
    ///
    /// - Parameters:
    ///   - hidingPrivate: le profil actif masque les entités privées.
    ///   - libraryID: la bibliothèque du profil actif. `nil` ne filtre pas, et
    ///     recouvre deux cas : aucun profil ouvert (le sélecteur n'a pas encore
    ///     tranché), ou un profil sans bibliothèque — théorique aujourd'hui,
    ///     `ProfileRepository.create` en affecte toujours une, mais la relation
    ///     est optionnelle et `move(_:to:)` existe. Dans les deux cas, mieux vaut
    ///     tout montrer que rien.
    /// - Returns: le prédicat à passer à un `@Query` ou un `FetchDescriptor`.
    public func predicate(hidingPrivate: Bool, libraryID: UUID?) -> Predicate<Title> {
        let showsArchived = showsArchived

        // `Title.searchText` est replié par `refreshDerived()` (sans accents, sans
        // casse) : le terme cherché doit l'être aussi, sinon « Âme » ne trouve rien
        // alors que « ame » trouve tout.
        let term =
            searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .foldedForMatching

        let keys = KeyPatterns(
            library: libraryID.map(FilterKey.library),
            collection: collectionID.map(FilterKey.collection),
            genre: genreID.map(FilterKey.genre),
            person: personID.map(FilterKey.person)
        )
        let (low, high) = effectiveRuntime
        let bounds = Bounds(
            minimumRuntime: low, maximumRuntime: high,
            minimumRating: minimumRating, maximumRating: maximumRating
        )

        // Les quatre sous-arbres sont assemblés séparément, chacun sous le plafond
        // de cinq clauses. La recomposition ne fait que combiner des types déjà
        // connus, donc elle est gratuite.
        return Predicate<Title> { title in
            PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Conjunction(
                    lhs: Self.visibilityClauses(
                        title, showsArchived: showsArchived, hidingPrivate: hidingPrivate),
                    rhs: Self.scopeClauses(title, keys)
                ),
                rhs: PredicateExpressions.build_Conjunction(
                    lhs: Self.searchClause(title, term: term),
                    rhs: Self.boundsClauses(title, bounds)
                )
            )
        }
    }

    /// Les motifs de `filterKeys` à chercher, `nil` quand le critère est inactif.
    private struct KeyPatterns: Sendable {
        let library: String?
        let collection: String?
        let genre: String?
        let person: String?

        init(library: String?, collection: String?, genre: String?, person: String?) {
            self.library = library.map(FilterKey.pattern)
            self.collection = collection.map(FilterKey.pattern)
            self.genre = genre.map(FilterKey.pattern)
            self.person = person.map(FilterKey.pattern)
        }
    }

    /// Les bornes numériques effectives, `nil` quand la borne n'est pas posée.
    private struct Bounds: Sendable {
        let minimumRuntime: Int?
        let maximumRuntime: Int?
        let minimumRating: Double?
        let maximumRating: Double?
    }

    /// Corbeille, archivage, contenu privé.
    private static func visibilityClauses(
        _ title: PredicateExpressions.Variable<Title>,
        showsArchived: Bool,
        hidingPrivate: Bool
    ) -> some StandardPredicateExpression<Bool> {
        let root = PredicateExpressions.build_Arg(title)
        let alive = PredicateExpressions.build_Equal(
            lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.deletedAt),
            rhs: PredicateExpressions.build_NilLiteral()
        )
        let notArchived = predicateClause(
            active: showsArchived == false,
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isArchived),
                rhs: PredicateExpressions.build_Arg(false)
            )
        )
        let notPrivate = predicateClause(
            active: hidingPrivate,
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isPrivate),
                rhs: PredicateExpressions.build_Arg(false)
            )
        )
        return PredicateExpressions.build_Conjunction(
            lhs: PredicateExpressions.build_Conjunction(lhs: alive, rhs: notArchived),
            rhs: notPrivate
        )
    }

    /// Bibliothèque, collection, genre, personne créditée — tous portés par
    /// `filterKeys`, donc tous la même opération sur la même colonne.
    private static func scopeClauses(
        _ title: PredicateExpressions.Variable<Title>,
        _ patterns: KeyPatterns
    ) -> some StandardPredicateExpression<Bool> {
        let keys = PredicateExpressions.build_KeyPath(
            root: PredicateExpressions.build_Arg(title), keyPath: \.filterKeys)

        func carries(_ pattern: String?) -> some StandardPredicateExpression<Bool> {
            predicateClause(
                active: pattern != nil,
                PredicateExpressions.build_contains(
                    keys, PredicateExpressions.build_Arg(pattern ?? ""))
            )
        }

        return PredicateExpressions.build_Conjunction(
            lhs: PredicateExpressions.build_Conjunction(
                lhs: carries(patterns.library), rhs: carries(patterns.collection)),
            rhs: PredicateExpressions.build_Conjunction(
                lhs: carries(patterns.genre), rhs: carries(patterns.person))
        )
    }

    private static func searchClause(
        _ title: PredicateExpressions.Variable<Title>,
        term: String
    ) -> some StandardPredicateExpression<Bool> {
        predicateClause(
            active: term.isEmpty == false,
            PredicateExpressions.build_contains(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg(title), keyPath: \.searchText),
                PredicateExpressions.build_Arg(term)
            )
        )
    }

    /// Durée et note.
    ///
    /// Une borne posée exclut les titres sans valeur : « moins de 90 minutes » ne
    /// veut pas dire « durée inconnue ». La sentinelle porte cette règle — un `nil`
    /// remplacé par `Int.min` échoue à toute borne inférieure réelle, par `Int.max`
    /// à toute borne supérieure. Deux clauses plutôt qu'un intervalle : une seule
    /// sentinelle ne peut pas exclure `nil` dans les deux sens à la fois.
    private static func boundsClauses(
        _ title: PredicateExpressions.Variable<Title>,
        _ bounds: Bounds
    ) -> some StandardPredicateExpression<Bool> {
        let root = PredicateExpressions.build_Arg(title)
        let runtime = PredicateExpressions.build_KeyPath(root: root, keyPath: \.runtimeMinutes)
        let rating = PredicateExpressions.build_KeyPath(root: root, keyPath: \.rating)

        let overMinimumRuntime = predicateClause(
            active: bounds.minimumRuntime != nil,
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_NilCoalesce(
                    lhs: runtime, rhs: PredicateExpressions.build_Arg(Int.min)),
                rhs: PredicateExpressions.build_Arg(bounds.minimumRuntime ?? 0),
                op: .greaterThanOrEqual
            )
        )
        let underMaximumRuntime = predicateClause(
            active: bounds.maximumRuntime != nil,
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_NilCoalesce(
                    lhs: runtime, rhs: PredicateExpressions.build_Arg(Int.max)),
                rhs: PredicateExpressions.build_Arg(bounds.maximumRuntime ?? 0),
                op: .lessThanOrEqual
            )
        )
        let overMinimumRating = predicateClause(
            active: bounds.minimumRating != nil,
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_NilCoalesce(
                    lhs: rating,
                    rhs: PredicateExpressions.build_Arg(-Double.greatestFiniteMagnitude)),
                rhs: PredicateExpressions.build_Arg(bounds.minimumRating ?? 0),
                op: .greaterThanOrEqual
            )
        )
        let underMaximumRating = predicateClause(
            active: bounds.maximumRating != nil,
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_NilCoalesce(
                    lhs: rating,
                    rhs: PredicateExpressions.build_Arg(Double.greatestFiniteMagnitude)),
                rhs: PredicateExpressions.build_Arg(bounds.maximumRating ?? 0),
                op: .lessThanOrEqual
            )
        )

        return PredicateExpressions.build_Conjunction(
            lhs: PredicateExpressions.build_Conjunction(
                lhs: overMinimumRuntime, rhs: underMaximumRuntime),
            rhs: PredicateExpressions.build_Conjunction(
                lhs: overMinimumRating, rhs: underMaximumRating)
        )
    }

    public var descriptors: [SortDescriptor<Title>] {
        sort.descriptors(ascending: ascending)
    }
}
