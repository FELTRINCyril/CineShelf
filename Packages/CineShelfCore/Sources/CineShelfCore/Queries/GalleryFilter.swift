import Foundation
import SwiftData

// MARK: - L1 bis · Le filtre de galerie
//
// Deux critères, et un seul est difficile.
//
// **La source.** Un média de galerie appartient à un titre, à une personne ou à une
// collection — l'invariante `hasExactlyOneOwner` de `MediaAttachment` le garantit — ou à
// rien, et il est alors orphelin.
//
// **Le piège relevé à l'avance par la fiche, et il était réel.** Écrire « orphelin »
// `asset.attachments?.isEmpty ?? true` est exactement la traversée de relation optionnelle
// qui sature la vérification de types de `#Predicate` : c'est la découverte de `L1`, et ce
// n'est pas le nombre de clauses qui coûte, ce sont les traversées. La fiche donnait deux
// issues et demandait de trancher **par la mesure**.
//
// **Mesuré le 2026-08-05 par une sonde, et le résultat n'est pas celui que la fiche
// prévoyait — il est pire, donc plus utile.**
//
// | Route | Compile ? | Vérification de types | Au `fetch` |
// |---|---|---|---|
// | `#Predicate<MediaAsset> { $0.attachments?.isEmpty ?? true }` | **oui** | **sous 200 ms** | **tue le processus** |
// | `MediaAttachment` puis différence d'ensembles | oui | négligeable | 50 orphelins sur 50 attendus |
//
// La première route ne coûte **rien** à la compilation : elle compile, et le seuil de
// `-warn-long-expression-type-checking=200` ne la signale même pas. Le piège annoncé par la
// fiche — « la traversée qui fait sauter le budget de vérification de types » — **ne se
// reproduit pas** sur cette traversée-là.
//
// Ce qu'elle fait à la place est bien plus grave. Au premier `fetch`, Core Data abandonne :
//
//     CoreData: error: SQLCore dispatchRequest: exception handling request:
//     Keypath containing KVC aggregate where there shouldn't be one;
//     failed to handle attachments.@count
//
// et le processus **meurt sur un signal 6**. Ce n'est pas une erreur qu'on rattrape : le
// `do/catch` de la sonde n'a jamais été atteint. Un écran de galerie qui aurait posé ce
// prédicat aurait fait quitter l'app, sans aucun signe à la compilation ni au lint.
//
// **C'est exactement la règle de `CLAUDE.md` sur les prédicats, et son cas le plus dur.**
// « Tout test de `#Predicate` passe par le magasin » : ici, ni la compilation, ni le
// type-check, ni un test sur des objets encore en attente n'auraient vu quoi que ce soit.
// Seul le `fetch` depuis un `ModelContext` neuf l'a montré.
//
// La seconde route est celle que la fiche décrivait : « le propriétaire y est une colonne,
// et *orphelin* devient une absence de ligne ». On ne dénormalise donc rien, et la tâche ne
// retombe pas dans le schéma — ce qui était la condition pour qu'elle reste dans `L1 bis`.
//
// **Le test de non-régression ne peut pas exercer la mauvaise route.** Un test qui poserait
// le prédicat fautif tuerait la suite entière au lieu d'échouer, et on retomberait sur le
// diagnostic « la suite meurt sans nommer de test » que `CLAUDE.md` décrit. Il vérifie donc
// la bonne route sur des entrées où l'ordre de grandeur compte, et la mauvaise reste décrite
// ici — c'est le seul cas de ce dépôt où la preuve d'un défaut ne peut pas devenir un test.
//
// **Ce que ça impose à l'appelant, et il faut le dire.** « Orphelin » n'est pas un
// `Predicate` : c'est un ensemble d'identifiants à retrancher. Un `@Query` ne peut donc pas
// l'exprimer seul, et c'est `GalleryQuery.assetIDs(matching:in:)` qui fait le travail. Les
// trois autres sources, elles, sont bien des prédicats.

/// D'où vient un média de la galerie.
public enum MediaSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case title
    case person
    case collection
    /// Aucun propriétaire : importé puis détaché, ou resté d'une suppression.
    case orphan

    public var id: String { rawValue }
}

/// Ce que la galerie montre, et dans quel ordre.
///
/// `Sendable` et `Codable` : `NavigationModel` sérialise déjà `TitleFilter` de la même
/// façon, et une galerie qui perd son filtre au relancement est un filtre qu'on ne pose
/// pas.
public struct GalleryFilter: Codable, Sendable, Hashable {

    /// Les sources retenues. **Vide vaut « toutes »**, comme `TitleFilter` : un filtre vide
    /// est un filtre inactif, pas un filtre qui ne rend rien. L'inverse est le piège
    /// classique — l'utilisateur décoche la dernière case et l'écran se vide sans qu'aucun
    /// message l'explique.
    public var sources: Set<MediaSource>

    /// La graine du mélange. `nil` conserve l'ordre naturel (le plus récent d'abord).
    ///
    /// **Une graine, pas un booléen**, et c'est tout l'intérêt : le même ordre tant qu'on ne
    /// rafraîchit pas. Un mélange retiré d'un `random` à chaque évaluation de vue
    /// réordonnerait la grille à chaque défilement — un média changerait de place pendant
    /// qu'on le regarde.
    public var shuffleSeed: UInt64?

    public init(sources: Set<MediaSource> = [], shuffleSeed: UInt64? = nil) {
        self.sources = sources
        self.shuffleSeed = shuffleSeed
    }

    public var isActive: Bool { !sources.isEmpty && sources.count < MediaSource.allCases.count }

    /// Les sources effectivement demandées, « vide » résolu en « toutes ».
    public var effectiveSources: Set<MediaSource> {
        sources.isEmpty ? Set(MediaSource.allCases) : sources
    }
}

// MARK: - Le mélange à graine stable

extension GalleryFilter {

    /// Réordonne selon la graine, ou rend la collection inchangée sans graine.
    ///
    /// **Le générateur est déterministe et écrit ici**, pas `SystemRandomNumberGenerator` :
    /// c'est la graine qui doit décider, et une même graine doit donner le même ordre sur
    /// deux appareils. C'est aussi ce qui rend la fonction testable sans compter sur la
    /// chance.
    public func shuffled<T>(_ items: [T]) -> [T] {
        guard let shuffleSeed else { return items }
        var generator = SplitMix64(seed: shuffleSeed)
        return items.shuffled(using: &generator)
    }
}

/// Un générateur déterministe, de la famille SplitMix64.
///
/// Écrit à la main parce que la bibliothèque standard n'en fournit aucun qui soit
/// reproductible : `SystemRandomNumberGenerator` ne prend pas de graine, et c'est la graine
/// qui est la fonctionnalité. Vingt lignes, aucune dépendance.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Une graine nulle ne doit pas donner une suite dégénérée : SplitMix64 tolère 0,
        // mais l'incrément est ajouté avant le brassage, ce qui l'écarte tout de suite.
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Les requêtes

public enum GalleryQuery {

    /// Les pièces jointes dont le propriétaire est de ce type.
    ///
    /// Un prédicat par source, et **jamais une clause combinée** : le propriétaire est une
    /// colonne de `MediaAttachment`, donc chaque test est une comparaison à `nil` sans
    /// traversée. Les combiner en un `||` de trois clauses recréerait le coût que ce
    /// découpage évite.
    public static func attachments(from source: MediaSource) -> Predicate<MediaAttachment>? {
        switch source {
        case .title: return #Predicate<MediaAttachment> { $0.title != nil }
        case .person: return #Predicate<MediaAttachment> { $0.person != nil }
        case .collection: return #Predicate<MediaAttachment> { $0.collection != nil }
        // Un orphelin est l'**absence** d'une ligne, et une absence ne s'exprime pas par un
        // prédicat sur la table qui n'a pas la ligne. Voir `assetIDs(matching:in:)`.
        //
        // `return` explicite et non expression : un `switch` dont une branche vaut `nil` ne
        // laisse pas Swift inférer `Predicate<MediaAttachment>?`.
        case .orphan: return nil
        }
    }

    /// Les identifiants des médias qui satisfont le filtre.
    ///
    /// Rend des identifiants et non des `MediaAsset` : « orphelin » demande une différence
    /// d'ensembles, donc un passage par les identifiants de toute façon. Charger les objets
    /// ici obligerait l'appelant à les recharger dans son propre contexte.
    ///
    /// - Parameters:
    ///   - filter: les sources retenues. Vide vaut « toutes ».
    ///   - context: le contexte de lecture. Trois `fetch` au plus, un par source possédante,
    ///     plus deux pour les orphelins.
    /// - Returns: les identifiants des médias retenus, sans ordre — le mélange est l'affaire
    ///   de `GalleryFilter.shuffled(_:)`, sur la collection déjà chargée.
    /// - Throws: ce que `ModelContext.fetch` lève.
    public static func assetIDs(
        matching filter: GalleryFilter, in context: ModelContext
    ) throws -> Set<UUID> {
        let sources = filter.effectiveSources
        var owned: Set<UUID> = []

        for source in sources where source != .orphan {
            guard let predicate = attachments(from: source) else { continue }
            owned.formUnion(try assetIDs(ofAttachmentsMatching: predicate, in: context))
        }

        guard sources.contains(.orphan) else { return owned }

        // Les orphelins : tous les médias, moins ceux qu'une pièce jointe réclame. La
        // soustraction porte sur **toutes** les pièces jointes, pas seulement celles des
        // sources retenues — sinon un média rattaché à un titre serait compté comme
        // orphelin dès que « titre » est décoché, ce qui est faux et invisible.
        let attached = try assetIDs(ofAttachmentsMatching: nil, in: context)
        let all = try context.fetch(FetchDescriptor<MediaAsset>()).map(\.id)
        return owned.union(Set(all).subtracting(attached))
    }

    private static func assetIDs(
        ofAttachmentsMatching predicate: Predicate<MediaAttachment>?,
        in context: ModelContext
    ) throws -> Set<UUID> {
        let descriptor = FetchDescriptor<MediaAttachment>(predicate: predicate)
        return Set(try context.fetch(descriptor).compactMap(\.asset?.id))
    }
}
