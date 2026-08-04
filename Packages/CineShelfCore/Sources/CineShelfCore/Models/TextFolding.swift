import Foundation

// MARK: - Replier du texte de façon reproductible
//
// **Le seul endroit du dépôt où une chaîne se replie.** Avant le 2026-08-04, la même
// expression était recopiée à douze endroits :
//
//     folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
//
// **Pourquoi `.current` est un bug — et l'argument ne repose sur aucune locale exotique.**
// Une clé repliée n'a de sens que comparée à une autre clé repliée de la MÊME façon. Si le
// côté écriture et le côté lecture replient différemment, la comparaison est fausse, quelle
// que soit la locale de chacun : il suffit qu'elles diffèrent.
//
// Or `sortName`, `searchText` et `nameKey` sont des champs **persistés et synchronisés par
// CloudKit** : une valeur est écrite depuis un appareil et interrogée depuis un autre.
// Replier selon les réglages de l'appareil fait donc de la divergence un **défaut
// structurel de la synchronisation**, pas un cas limite. Conséquences par champ :
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
// La règle est donc : **une seule fonction, une locale invariante, les deux côtés.**
//
// Le turc, où `I` se replie en `ı` sans point, n'est **qu'une illustration** : c'est là que
// la divergence se mesure commodément, ce n'est pas la raison de la règle.
//
//     mot            | fr_FR        | tr_TR
//     Interstellar   | interstellar | ınterstellar   <- diverge
//     ITALIA         | italia       | ıtalıa         <- diverge
//     Indépendant    | independant  | ındependant    <- diverge

/// Replie du texte pour la comparaison, l'indexation et le dédoublonnage.
public enum TextFolding {

    /// La locale de repliage. **Invariante, et volontairement pas `.current`.**
    ///
    /// `en_US_POSIX` est la convention d'Apple pour les traitements qui ne doivent pas
    /// dépendre des réglages de l'appareil. Ce qui est replié ici n'est jamais montré à
    /// l'utilisateur : ce sont des clés de comparaison.
    ///
    /// **Compromis assumé : le tri n'est pas sensible à la locale.** `sortName` étant replié
    /// ici, l'ordre produit est le même partout — c'est ce qu'on veut d'une clé partagée
    /// entre appareils. En français c'est sans effet visible (`é` se replie sur `e`, à sa
    /// place attendue), mais une bibliothèque suédoise trierait `ö` avec les `o` au lieu de
    /// l'attendre après `z`. Arbitrage retenu pour une app personnelle en français, décidé
    /// et non subi (voir `docs/02` §3).
    ///
    /// Si l'ordre affiché doit un jour être national, il se fait à l'affichage avec un
    /// comparateur localisé — **jamais** dans le champ stocké, sous peine de ramener la
    /// divergence entre appareils.
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
