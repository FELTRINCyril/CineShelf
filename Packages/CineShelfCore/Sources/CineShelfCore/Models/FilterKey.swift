import Foundation

/// Les jetons de `filterKeys`, le champ dénormalisé qui rend les relations
/// interrogeables en SQL.
///
/// **Le problème que ça résout.** Un `#Predicate` cesse de se type-checker bien
/// avant d'être long : ce qui sature le vérificateur, ce ne sont pas les clauses,
/// ce sont les **traversées de relation optionnelle** — `(x.rel?.id ?? sentinelle)
/// == cible`. Deux traversées de cette forme dans la même chaîne faisaient
/// échouer la compilation des *deux* prédicats de `TitleFilter` (mesuré). Filtrer
/// sur collection, genre et personne était donc impossible en SQL, et le
/// catalogue entier était rapatrié pour être filtré en Swift.
///
/// Dénormaliser les identifiants dans une colonne `String` non optionnelle
/// remplace chaque traversée par un `contains` — une opération que le
/// vérificateur traite en temps constant, et que SQLite exécute sans jointure.
///
/// **Pourquoi une seule colonne et non une par critère.** Chaque critère devient
/// alors la même opération sur la même colonne, il n'y a qu'un endroit à
/// maintenir, et un critère nouveau ne coûte pas une migration de schéma. C'est
/// ce qui permettra à `L18` (rayons par genre) de s'y brancher sans toucher au
/// modèle.
///
/// **Pourquoi des identifiants et non des noms.** Un nom change ; un identifiant
/// non. Renommer un genre n'invalide donc aucune clé — c'est vérifié par un test,
/// parce que l'absence de code à écrire est le genre de chose qu'on croit à tort
/// avoir oubliée.
public enum FilterKey {

    /// Le délimiteur, présent des deux côtés de chaque jeton.
    ///
    /// Il n'est pas décoratif : sans lui, `contains` ferait des correspondances
    /// partielles entre jetons voisins. Les `uuidString` étant de longueur fixe,
    /// le risque est aujourd'hui théorique — il cesserait de l'être au premier
    /// jeton de longueur variable, et c'est trop tard qu'on s'en apercevrait.
    private static let delimiter = "|"

    // MARK: Jetons

    public static func library(_ id: UUID) -> String { "l:\(id.uuidString)" }
    public static func collection(_ id: UUID) -> String { "c:\(id.uuidString)" }
    public static func genre(_ id: UUID) -> String { "g:\(id.uuidString)" }
    public static func person(_ id: UUID) -> String { "p:\(id.uuidString)" }
    public static func role(_ role: PersonRole) -> String { "r:\(role.rawValue)" }

    // MARK: Les deux formes

    /// La valeur à stocker dans `filterKeys`, produite par `refreshDerived()`.
    ///
    /// Triée et dédoublonnée : un champ dérivé doit être une fonction de l'état,
    /// pas de l'ordre dans lequel SwiftData rend une relation. Sans le tri, deux
    /// recalculs du même titre pourraient produire deux chaînes différentes,
    /// donc deux `updatedAt` et une synchronisation CloudKit pour rien.
    public static func keys(_ tokens: [String]) -> String {
        let unique = Set(tokens).sorted()
        guard unique.isEmpty == false else { return "" }
        return delimiter + unique.joined(separator: delimiter) + delimiter
    }

    /// Le motif à chercher dans un `#Predicate`.
    ///
    /// Distinct de `keys(_:)` par le nom pour que les deux côtés ne puissent pas
    /// être confondus : c'est le seul couple d'écriture et de lecture qui doit
    /// rester d'accord, et le faire passer par une paire de fonctions est ce qui
    /// rend le format interne indifférent.
    public static func pattern(_ token: String) -> String {
        delimiter + token + delimiter
    }
}
