import Foundation

// MARK: - Replier du texte de façon reproductible
//
// **Le seul endroit du dépôt où une chaîne se replie.** Avant le 2026-08-04, la même
// expression était recopiée à douze endroits :
//
//     folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
//
// `.current` est un bug, et il ne se voit pas en France. Mesuré :
//
//     mot            | fr_FR        | tr_TR
//     Interstellar   | interstellar | ınterstellar   <- diverge
//     ITALIA         | italia       | ıtalıa         <- diverge
//     Indépendant    | independant  | ındependant    <- diverge
//
// Ce n'est pas un cas exotique : **tout mot contenant un `I` majuscule** diverge, parce
// que le turc et l'azéri ont un `i` sans point. La moitié des titres écrits en capitales
// sont concernés.
//
// **Pourquoi c'est grave ici et pas ailleurs.** `sortName`, `searchText` et `nameKey` sont
// des champs **persistés et synchronisés par CloudKit**. Deux appareils sous des locales
// différentes écriraient donc des valeurs différentes pour la même entité :
//
//   - `Genre.nameKey` sert au **dédoublonnage** — c'est notre remplacement de
//     `@Attribute(.unique)`, que CloudKit interdit. Un iPhone en turc et un Mac en français
//     ne s'accorderaient pas sur la clé de « Indépendant », et `findOrCreate` créerait un
//     second genre **sans rien signaler**. Exactement la classe de bug qu'on traque.
//   - `searchText` est comparé à un terme replié au moment de la recherche : si les deux
//     côtés n'utilisent pas la même règle, la recherche ne trouve rien — et un `CONTAINS`
//     qui ne matche pas ne lève aucune erreur.
//   - `sortName` produirait un ordre instable et des écritures de synchronisation inutiles.
//
// La règle est donc : **une seule fonction, une locale invariante, les deux côtés.** Le
// côté écriture et le côté lecture doivent replier identiquement, sinon la comparaison est
// fausse quelle que soit la locale choisie.

/// Replie du texte pour la comparaison, l'indexation et le dédoublonnage.
public enum TextFolding {

    /// La locale de repliage. **Invariante, et volontairement pas `.current`.**
    ///
    /// `en_US_POSIX` est la convention d'Apple pour les traitements qui ne doivent pas
    /// dépendre des réglages de l'appareil. Ce qui est replié ici n'est jamais montré à
    /// l'utilisateur : ce sont des clés de comparaison.
    ///
    /// Le tri **affiché**, lui, peut légitimement être localisé — mais il se fait alors à
    /// l'affichage avec un comparateur, pas dans un champ stocké. `sortName` est une clé de
    /// tri partagée entre appareils, pas un ordre alphabétique national.
    public static let locale = Locale(identifier: "en_US_POSIX")

    /// Sans accents, sans casse.
    static let options: String.CompareOptions = [.diacriticInsensitive, .caseInsensitive]

    /// La forme repliée d'une chaîne : sans accents, sans casse, reproductible partout.
    public static func key(_ text: String) -> String {
        text.folding(options: options, locale: locale)
    }
}

extension String {
    /// La forme repliée de cette chaîne, pour comparer, indexer ou dédoublonner.
    ///
    /// À utiliser **des deux côtés** de toute comparaison : la valeur écrite en base et le
    /// terme cherché. Voir `TextFolding`.
    public var foldedForMatching: String { TextFolding.key(self) }
}
