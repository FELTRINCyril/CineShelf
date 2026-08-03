import CineShelfCore
import Foundation
import SwiftData

// L'état de filtre et de tri de la liste des titres.
//
// Placé dans `App/Navigation/` et non dans `Features/Titles/` parce que le
// prompt 11 exige qu'il soit **restauré au lancement** : c'est donc
// `NavigationModel` qui le porte et le sérialise. L'y mettre depuis une feature
// obligerait `App/Navigation/` à importer `Features/Titles/`, et créerait un
// cycle — la feature lisant déjà le modèle de navigation.
//
// Le type ne connaît que `CineShelfCore` : aucune vue, aucun composant.

/// Les critères de tri de la liste des titres — `docs/03` §4.
enum TitleSortField: String, CaseIterable, Identifiable, Codable, Sendable {
    case added
    case name
    case rating
    case release
    case runtime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .added: "Ajout"
        case .name: "Titre"
        case .rating: "Note"
        case .release: "Sortie"
        case .runtime: "Durée"
        }
    }

    var symbol: String {
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
    func descriptors(ascending: Bool) -> [SortDescriptor<Title>] {
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
enum RuntimeBand: String, CaseIterable, Identifiable, Codable, Sendable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: "Court (< 1 h 30)"
        case .medium: "Moyen (1 h 30 – 2 h)"
        case .long: "Long (> 2 h)"
        }
    }

    var range: ClosedRange<Int> {
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
struct TitleFilter: Codable, Equatable, Sendable {
    var searchText: String = ""
    var collectionID: UUID?
    var genreID: UUID?
    var personID: UUID?
    var runtimeBand: RuntimeBand?
    var minimumRuntime: Int?
    var maximumRuntime: Int?
    var minimumRating: Double?
    var maximumRating: Double?
    var showsArchived: Bool = false

    var sort: TitleSortField = .added
    var ascending: Bool = false

    /// `true` dès qu'un critère restreint la liste. Le tri n'en fait pas partie :
    /// trier ne cache rien.
    var isActive: Bool {
        self != TitleFilter(sort: sort, ascending: ascending)
    }

    /// Les bornes de durée effectives : la tranche pré-réglée l'emporte sur les
    /// bornes libres, parce que c'est elle que l'utilisateur vient de toucher.
    var effectiveRuntime: (minimum: Int?, maximum: Int?) {
        if let band = runtimeBand {
            return (band.range.lowerBound, band.range.upperBound)
        }
        return (minimumRuntime, maximumRuntime)
    }

    mutating func clear() {
        self = TitleFilter(sort: sort, ascending: ascending)
    }
}

// MARK: - Traduction en requête

extension TitleFilter {

    /// Le prédicat SwiftData correspondant.
    ///
    /// Deux limites assumées de `#Predicate`, qui expliquent la forme du code :
    ///
    ///   - les propriétés calculées (`kind`, `releaseYear`) n'y sont pas
    ///     utilisables — on filtre sur les colonnes brutes ;
    ///   - les relations to-many sont optionnelles, donc chaque traversée doit
    ///     gérer le `nil`. C'est la première cause d'erreur en SwiftData.
    ///
    /// Le partage entre prédicat et `matches(_:)` est dicté par le compilateur,
    /// pas par le goût : `#Predicate` s'expanse en une pile de types génériques
    /// `PredicateExpressions`, et la vérification de types cesse d'aboutir
    /// au-delà de cinq ou six clauses (mesuré ici, pas supposé). Le prédicat
    /// garde donc les critères toujours actifs et les plus sélectifs — ceux qui
    /// réduisent réellement le nombre de lignes lues. Les critères optionnels
    /// et les traversées to-many partent dans `matches(_:)`, appliqué en
    /// mémoire sur le résultat.
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
    func predicate(hidingPrivate: Bool, libraryID: UUID?) -> Predicate<Title> {
        let showsArchived = showsArchived

        // `Title.searchText` est replié par `refreshDerived()` (sans accents,
        // sans casse) : le terme cherché doit l'être aussi, sinon « Âme » ne
        // trouve rien alors que « ame » trouve tout.
        let search =
            searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // L'identifiant est dénormalisé en `Bool` + `UUID` non optionnel :
        // comparer un `UUID?` capturé à une colonne `UUID` oblige le
        // vérificateur de types à explorer toutes les promotions d'optionnel.
        // Une seule traversée de ce genre tient dans le budget, pas deux —
        // mesuré : ajouter la collection à côté de la bibliothèque fait échouer
        // les *deux* prédicats. La collection est donc filtrée en mémoire.
        let noID = UUID()
        let hasLibrary = libraryID != nil
        let libraryTarget = libraryID ?? noID

        // ATTENTION — deux prédicats, et non un seul avec une clause gardée.
        //
        // `String.contains("")` est **vrai** en Swift, mais un `#Predicate` n'est
        // pas évalué en Swift : SwiftData le traduit en SQL, et `CONTAINS ''`
        // n'y matche **aucune** ligne. Mettre la clause de recherche dans le
        // prédicat quand le terme est vide vide donc la grille en permanence,
        // pour tout le monde. C'est le bug qu'on a eu, et le commentaire
        // d'origine affirmait exactement le contraire.
        //
        // Le garde ne peut pas vivre à l'intérieur du `#Predicate` : ajouter
        // `search.isEmpty || …` à la chaîne dépasse le budget de vérification de
        // types, pour la raison décrite plus haut. D'où la duplication, assumée.
        guard search.isEmpty == false else {
            return #Predicate<Title> { title in
                title.deletedAt == nil
                    && (showsArchived || title.isArchived == false)
                    && (hidingPrivate == false || title.isPrivate == false)
                    && (hasLibrary == false || (title.library?.id ?? noID) == libraryTarget)
            }
        }

        return #Predicate<Title> { title in
            title.deletedAt == nil
                && (showsArchived || title.isArchived == false)
                && (hidingPrivate == false || title.isPrivate == false)
                && (hasLibrary == false || (title.library?.id ?? noID) == libraryTarget)
                && title.searchText.contains(search)
        }
    }

    /// Ce que le prédicat ne prend pas en charge : collection, genre, personne,
    /// durée, note.
    ///
    /// Un titre sans durée (ou sans note) est exclu dès qu'une borne est posée,
    /// et gardé quand il n'y en a aucune.
    func matches(_ title: Title) -> Bool {
        matchesCollection(title) && matchesGenre(title) && matchesPeople(title)
            && matchesRuntime(title) && matchesRating(title)
    }

    /// Filtré ici et non dans le prédicat : la bibliothèque a pris la seule
    /// place disponible pour une traversée de relation optionnelle (voir
    /// `predicate(hidingPrivate:libraryID:)`). Une collection demandée exclut
    /// les titres qui n'en portent aucune.
    private func matchesCollection(_ title: Title) -> Bool {
        guard let collectionID else { return true }
        return title.collection?.id == collectionID
    }

    private func matchesPeople(_ title: Title) -> Bool {
        guard let personID else { return true }
        return (title.credits ?? []).contains { $0.person?.id == personID }
    }

    /// Un genre demandé exclut les titres qui ne le portent pas — y compris
    /// ceux qui n'ont aucun genre.
    private func matchesGenre(_ title: Title) -> Bool {
        guard let genreID else { return true }
        return (title.genres ?? []).contains { $0.id == genreID }
    }

    /// Une borne posée exclut les titres sans durée : « moins de 90 minutes »
    /// ne veut pas dire « durée inconnue ».
    private func matchesRuntime(_ title: Title) -> Bool {
        let (low, high) = effectiveRuntime
        guard low != nil || high != nil else { return true }
        guard let runtime = title.runtimeMinutes else { return false }
        if let low, runtime < low { return false }
        if let high, runtime > high { return false }
        return true
    }

    /// Même règle pour la note : un titre non noté sort dès qu'une borne existe.
    private func matchesRating(_ title: Title) -> Bool {
        guard minimumRating != nil || maximumRating != nil else { return true }
        guard let rating = title.rating else { return false }
        if let minimumRating, rating < minimumRating { return false }
        if let maximumRating, rating > maximumRating { return false }
        return true
    }

    var descriptors: [SortDescriptor<Title>] {
        sort.descriptors(ascending: ascending)
    }
}
