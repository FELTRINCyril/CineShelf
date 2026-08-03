import Foundation
import SwiftData

/// Les prédicats simples, nommés une fois et réutilisables.
///
/// **Pourquoi ils ne vivent pas dans les vues.** Six `#Predicate` étaient écrits
/// directement dans `App/` — deux « le titre d'identifiant X », les genres vivants,
/// les genres épinglés, un média par identifiant, un genre par clé repliée. Trois
/// raisons de les rapatrier ici :
///
/// 1. **Aucune cible de test ne monte les vues** : ces prédicats étaient les seuls
///    du dépôt sans couverture possible, et c'était un écart connu. Ici, ils sont
///    testables.
/// 2. **Le plafond de cinq clauses** (voir `predicateClause(active:_:)`) est une
///    propriété de `#Predicate` que personne ne devine. Concentrer les prédicats
///    dans un seul module met la documentation à côté du code qu'elle concerne, et
///    la règle SwiftLint `no_predicate_outside_core` empêche qu'un septième
///    réapparaisse dans une vue.
/// 3. `CLAUDE.md` l'exigeait déjà : aucune logique métier dans une `View`.
///
/// Chacun tient largement sous le plafond — le plus long en compte trois.
public enum TitleQuery {

    /// Un titre par identifiant.
    ///
    /// Sert aux vues de détail, qui reçoivent un `UUID` de route et non un objet :
    /// une route doit survivre à un redémarrage, donc elle ne peut pas transporter
    /// de référence.
    public static func withID(_ id: UUID) -> Predicate<Title> {
        #Predicate<Title> { $0.id == id }
    }
}

public enum GenreQuery {

    /// Les genres hors corbeille.
    ///
    /// `docs/02` §3.5 : **toute** requête de genres filtre `deletedAt == nil`. Sans
    /// ce filtre, un genre mis à la corbeille réapparaîtrait dans les sélecteurs, et
    /// le retaper le ressusciterait avec toutes ses anciennes associations.
    public static var living: Predicate<Genre> {
        #Predicate<Genre> { $0.deletedAt == nil }
    }

    /// Les genres épinglés, pour la barre latérale.
    public static var pinned: Predicate<Genre> {
        #Predicate<Genre> { $0.isPinned && $0.deletedAt == nil && $0.isArchived == false }
    }

    /// Un genre vivant par clé repliée, dans une bibliothèque donnée.
    ///
    /// C'est le dédoublonnage applicatif qui remplace `@Attribute(.unique)`, que
    /// CloudKit interdit. `GenreRepository.findOrCreate` s'en sert.
    public static func living(key: String, target: GenreTarget, inLibrary libraryID: UUID) -> Predicate<Genre> {
        let targetRaw = target.rawValue
        return #Predicate<Genre> {
            $0.nameKey == key && $0.targetRaw == targetRaw && $0.library?.id == libraryID
                && $0.deletedAt == nil
        }
    }

    /// Un genre vivant par clé repliée, toutes bibliothèques confondues.
    public static func living(key: String) -> Predicate<Genre> {
        #Predicate<Genre> { $0.nameKey == key && $0.deletedAt == nil }
    }
}

public enum MediaQuery {

    /// Un média par identifiant.
    public static func asset(withID id: UUID) -> Predicate<MediaAsset> {
        #Predicate<MediaAsset> { $0.id == id }
    }
}
