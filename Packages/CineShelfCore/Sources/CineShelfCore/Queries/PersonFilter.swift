import Foundation
import SwiftData

/// Les tranches d'âge pré-réglées — mêmes bornes que la v1 (`docs/04` §12).
public enum AgeBand: String, CaseIterable, Identifiable, Codable, Sendable {
    case young
    case middle
    case senior

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .young: "Jeune (moins de 35 ans)"
        case .middle: "Moyen (35 à 55 ans)"
        case .senior: "Senior (plus de 55 ans)"
        }
    }

    /// Les bornes en années, incluses.
    public var years: ClosedRange<Int> {
        switch self {
        case .young: 0...34
        case .middle: 35...55
        case .senior: 56...150
        }
    }
}

/// Tout ce qui restreint une liste de personnes — `docs/03` §5.
///
/// Vit dans `CineShelfCore` et non dans `App/` : c'est un type neuf, et la règle
/// des tâches `L` réserve `App/` aux types qui y sont déjà (`TitleFilter`, qu'on
/// complète sur place plutôt que d'en créer un doublon).
/// Les critères de tri de la liste des personnes — bloc `4c`, « Trier ▾ ».
///
/// **Calqué sur `TitleSortField`, et c'est voulu.** Les deux écrans posent le même menu, donc
/// une forme différente ici obligerait à écrire deux fois la liaison de la vue.
///
/// **Pas de tri sur l'âge**, alors que le filtre en propose des tranches : l'âge d'un vivant
/// n'est pas une donnée mais une fonction du temps, et le seul champ triable, `birthDate`,
/// donne l'ordre inverse — le plus vieux est celui né le plus tôt. `naissance` dit donc ce que
/// la colonne trie réellement, plutôt que de promettre un âge que le magasin ne stocke pas.
public enum PersonSortField: String, CaseIterable, Identifiable, Codable, Sendable {
    case added
    case name
    case birth
    case credits

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .added: "Ajout"
        case .name: "Nom"
        case .birth: "Naissance"
        case .credits: "Crédits"
        }
    }

    public var symbol: String {
        switch self {
        case .added: "clock"
        case .name: "textformat"
        case .birth: "calendar"
        case .credits: "film.stack"
        }
    }

    /// Les descripteurs SwiftData correspondants.
    ///
    /// Le tri secondaire sur `sortName` a la même raison que chez les titres : sans lui, deux
    /// personnes nées la même année s'échangent de place à chaque réévaluation, et la grille
    /// scintille.
    ///
    /// **`credits` n'est pas ici**, et c'est une limite du magasin, pas un oubli : SwiftData ne
    /// trie pas sur le compte d'une relation. Le cas est traité par la vue, qui trie en mémoire
    /// — ce qu'elle peut se permettre parce qu'elle a déjà la page en main. `descriptors` rend
    /// donc le tri par nom, qui est l'ordre stable sur lequel le compte se départage.
    public func descriptors(ascending: Bool) -> [SortDescriptor<Person>] {
        let order: SortOrder = ascending ? .forward : .reverse
        let byName = SortDescriptor(\Person.sortName, order: .forward)

        return switch self {
        case .added: [SortDescriptor(\Person.createdAt, order: order), byName]
        case .name: [SortDescriptor(\Person.sortName, order: order)]
        case .birth: [SortDescriptor(\Person.birthDate, order: order), byName]
        case .credits: [byName]
        }
    }

    /// Le tri se termine-t-il en mémoire ?
    ///
    /// Un seul cas, et l'exposer évite que la vue le devine par un `if` sur le cas — ce qui la
    /// rendrait fausse en silence le jour où un second critère non triable apparaît.
    public var sortsInMemory: Bool { self == .credits }
}

/// **`Codable` comme `TitleFilter`, et pour la même exigence** : les filtres survivent au
/// redémarrage, donc ils entrent dans l'instantané de navigation. Un filtre qu'on repose à
/// chaque lancement est un filtre qu'on ne pose pas.
public struct PersonFilter: Equatable, Sendable, Codable {
    public var searchText: String = ""
    public var role: PersonRole?
    public var genreID: UUID?
    public var ageBand: AgeBand?
    public var showsArchived: Bool = false
    public var sort: PersonSortField = .added
    public var ascending: Bool = false

    /// **Le tri n'est pas un critère**, exactement comme chez `TitleFilter` : il vit dans le
    /// même objet parce que la vue les passe ensemble, mais changer l'ordre d'affichage ne
    /// rend pas un filtre « actif ». D'où l'initialiseur qui les prend, et dont `isActive` et
    /// `clear()` se servent comme référence.
    public init(sort: PersonSortField = .added, ascending: Bool = false) {
        self.sort = sort
        self.ascending = ascending
    }

    /// `true` dès qu'un critère restreint la liste.
    public var isActive: Bool { self != PersonFilter(sort: sort, ascending: ascending) }

    public mutating func clear() { self = PersonFilter(sort: sort, ascending: ascending) }

    /// Les descripteurs à passer au `@Query`.
    public var descriptors: [SortDescriptor<Person>] { sort.descriptors(ascending: ascending) }
}

// MARK: - Traduction en requête

extension PersonFilter {

    /// Le prédicat SwiftData correspondant.
    ///
    /// Construit à la main, pour la raison exposée dans
    /// `predicateClause(active:_:)` : `#Predicate` plafonne à cinq clauses sur un
    /// `@Model`, et il en faut davantage. Même découpage que `TitleFilter` — des
    /// sous-arbres sous le plafond, recombinés ensuite.
    ///
    /// > **Le pari de `PredicateExpressions` est documenté dans
    /// > `predicateClause(active:_:)`, à lire avant de modifier cet arbre.** Le
    /// > risque n'est pas la rupture d'API — elle ne compilerait pas — mais que
    /// > SwiftData cesse de reconnaître la forme et retombe en mémoire, sans qu'un
    /// > seul test de critère ne bronche.
    ///
    /// - Parameters:
    ///   - hidingPrivate: le profil actif masque les entités privées.
    ///   - libraryID: la bibliothèque du profil actif. `nil` ne filtre pas.
    ///   - now: l'instant de référence pour les tranches d'âge. Paramétré et non
    ///     lu depuis l'horloge, parce qu'un test qui vérifie une borne d'âge doit
    ///     pouvoir fixer le jour — sinon il change de sens à chaque anniversaire
    ///     de sa fixture.
    /// - Returns: le prédicat à passer à un `@Query` ou un `FetchDescriptor`.
    public func predicate(
        hidingPrivate: Bool,
        libraryID: UUID?,
        now: Date = .now
    ) -> Predicate<Person> {
        let showsArchived = showsArchived
        let term =
            searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .foldedForMatching

        let libraryPattern = libraryID.map { FilterKey.pattern(FilterKey.library($0)) }
        let genrePattern = genreID.map { FilterKey.pattern(FilterKey.genre($0)) }
        let rolePattern = role.map { FilterKey.pattern(FilterKey.role($0)) }
        let age = AgeWindow(band: ageBand, now: now)

        return Predicate<Person> { person in
            PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Conjunction(
                    lhs: Self.visibilityClauses(
                        person, showsArchived: showsArchived, hidingPrivate: hidingPrivate),
                    rhs: Self.scopeClauses(
                        person, library: libraryPattern, genre: genrePattern, role: rolePattern)
                ),
                rhs: PredicateExpressions.build_Conjunction(
                    lhs: Self.searchClause(person, term: term),
                    rhs: Self.ageClauses(person, age)
                )
            )
        }
    }

    /// Ce qu'une tranche d'âge demande au magasin, préparé hors du prédicat.
    ///
    /// **Pourquoi deux formes pour un seul critère.** L'âge d'un vivant n'est pas
    /// une donnée, c'est une fonction du temps : le dénormaliser le rendrait faux
    /// dès le lendemain. On le filtre donc par bornes de `birthDate`, calculées à
    /// l'instant de la requête — exact, et jamais périmé.
    ///
    /// L'âge au décès, lui, est immuable : `Person.ageAtDeath` est donc dénormalisé
    /// sans risque, et c'est ce champ qui sert pour les défunts. Un défunt ne peut
    /// pas être filtré par bornes de naissance : sa tranche est celle de son âge à
    /// la mort, pas celle qu'il aurait aujourd'hui.
    ///
    /// D'où la disjonction du prédicat : `(vivant ET né dans la fenêtre) OU (défunt
    /// ET mort dans la tranche)`. Fusionner les deux branches en dénormalisant
    /// l'âge de tout le monde serait plus court, et faux.
    private struct AgeWindow: Sendable {
        let isActive: Bool
        let lowestYears: Int
        let highestYears: Int
        /// Naissance la plus tardive acceptée : celle qui donne l'âge minimal.
        let latestBirth: Date
        /// Naissance la plus ancienne acceptée, **exclue** — un an au-delà de
        /// l'âge maximal.
        let earliestBirth: Date

        init(band: AgeBand?, now: Date) {
            let years = band?.years ?? 0...0
            isActive = band != nil
            lowestYears = years.lowerBound
            highestYears = years.upperBound

            let calendar = Calendar.current
            latestBirth =
                calendar.date(byAdding: .year, value: -years.lowerBound, to: now) ?? now
            earliestBirth =
                calendar.date(byAdding: .year, value: -(years.upperBound + 1), to: now) ?? now
        }
    }

    /// Corbeille, archivage, contenu privé.
    private static func visibilityClauses(
        _ person: PredicateExpressions.Variable<Person>,
        showsArchived: Bool,
        hidingPrivate: Bool
    ) -> some StandardPredicateExpression<Bool> {
        let root = PredicateExpressions.build_Arg(person)
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

    /// Bibliothèque, genre, rôle — tous portés par `filterKeys`.
    private static func scopeClauses(
        _ person: PredicateExpressions.Variable<Person>,
        library: String?,
        genre: String?,
        role: String?
    ) -> some StandardPredicateExpression<Bool> {
        let keys = PredicateExpressions.build_KeyPath(
            root: PredicateExpressions.build_Arg(person), keyPath: \.filterKeys)

        func carries(_ pattern: String?) -> some StandardPredicateExpression<Bool> {
            predicateClause(
                active: pattern != nil,
                PredicateExpressions.build_contains(
                    keys, PredicateExpressions.build_Arg(pattern ?? ""))
            )
        }

        return PredicateExpressions.build_Conjunction(
            lhs: PredicateExpressions.build_Conjunction(
                lhs: carries(library), rhs: carries(genre)),
            rhs: carries(role)
        )
    }

    private static func searchClause(
        _ person: PredicateExpressions.Variable<Person>,
        term: String
    ) -> some StandardPredicateExpression<Bool> {
        predicateClause(
            active: term.isEmpty == false,
            PredicateExpressions.build_contains(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg(person), keyPath: \.searchText),
                PredicateExpressions.build_Arg(term)
            )
        )
    }

    /// La tranche d'âge : bornes de naissance pour les vivants, `ageAtDeath` pour
    /// les défunts. Voir `AgeWindow` pour le pourquoi des deux branches.
    ///
    /// Une personne sans date de naissance est exclue dès qu'une tranche est
    /// demandée — même règle que les bornes de durée sur `Title` : « moins de
    /// 35 ans » ne veut pas dire « âge inconnu ».
    private static func ageClauses(
        _ person: PredicateExpressions.Variable<Person>,
        _ window: AgeWindow
    ) -> some StandardPredicateExpression<Bool> {
        let root = PredicateExpressions.build_Arg(person)
        let birth = PredicateExpressions.build_KeyPath(root: root, keyPath: \.birthDate)
        let ageAtDeath = PredicateExpressions.build_KeyPath(root: root, keyPath: \.ageAtDeath)

        // Vivant : `deathDate == nil`, et naissance dans la fenêtre. Les
        // sentinelles `.distantFuture` et `.distantPast` excluent les naissances
        // inconnues, dans un sens comme dans l'autre.
        let isLiving = PredicateExpressions.build_Equal(
            lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.deathDate),
            rhs: PredicateExpressions.build_NilLiteral()
        )
        let bornEarlyEnough = PredicateExpressions.build_Comparison(
            lhs: PredicateExpressions.build_NilCoalesce(
                lhs: birth, rhs: PredicateExpressions.build_Arg(Date.distantFuture)),
            rhs: PredicateExpressions.build_Arg(window.latestBirth),
            op: .lessThanOrEqual
        )
        let bornLateEnough = PredicateExpressions.build_Comparison(
            lhs: PredicateExpressions.build_NilCoalesce(
                lhs: birth, rhs: PredicateExpressions.build_Arg(Date.distantPast)),
            rhs: PredicateExpressions.build_Arg(window.earliestBirth),
            op: .greaterThan
        )
        let livingInBand = PredicateExpressions.build_Conjunction(
            lhs: PredicateExpressions.build_Conjunction(lhs: isLiving, rhs: bornEarlyEnough),
            rhs: bornLateEnough
        )

        // Défunt : l'âge au décès est dans la tranche. `ageAtDeath` est `nil` pour
        // les vivants et pour les défunts sans date de naissance ; les sentinelles
        // écartent les deux cas.
        let diedOldEnough = PredicateExpressions.build_Comparison(
            lhs: PredicateExpressions.build_NilCoalesce(
                lhs: ageAtDeath, rhs: PredicateExpressions.build_Arg(Int.min)),
            rhs: PredicateExpressions.build_Arg(window.lowestYears),
            op: .greaterThanOrEqual
        )
        let diedYoungEnough = PredicateExpressions.build_Comparison(
            lhs: PredicateExpressions.build_NilCoalesce(
                lhs: ageAtDeath, rhs: PredicateExpressions.build_Arg(Int.max)),
            rhs: PredicateExpressions.build_Arg(window.highestYears),
            op: .lessThanOrEqual
        )
        let deadInBand = PredicateExpressions.build_Conjunction(
            lhs: diedOldEnough, rhs: diedYoungEnough
        )

        return predicateClause(
            active: window.isActive,
            PredicateExpressions.build_Disjunction(lhs: livingInBand, rhs: deadInBand)
        )
    }
}
