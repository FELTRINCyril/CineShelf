import Foundation

/// Qui écrit l'entrée de journal d'une écriture.
///
/// **Pourquoi ce réglage existe.** `ActivityRecorder` écrit une entrée par appel, ce qui
/// est juste pour une écriture unitaire et faux pour un lot : cinquante titres modifiés
/// d'un coup produiraient cinquante lignes dans le fil, qui noieraient tout le reste et
/// ne diraient rien de plus que « cinquante titres modifiés ». La fiche `L10` l'exige
/// explicitement — une entrée pour le lot, pas une par ligne.
///
/// La tentation était de laisser l'édition en masse muter les entités en direct, sans
/// passer par les repositories. Elle a été écartée : ce sont eux qui appellent
/// `refreshDerived()`, donc qui maintiennent `filterKeys`, et une relation écrite sans
/// rafraîchissement rend le filtre correspondant faux **en silence**. Mieux vaut un
/// paramètre de plus qu'une seconde porte d'écriture.
/// > **Ce paramètre n'a volontairement pas de valeur par défaut.**
/// >
/// > La première version en donnait une (`.perEntity`), et deux mutateurs de
/// > `PersonRepository` — `setGenres` et `setRoles` — ont aussitôt accepté le paramètre
/// > **sans le transmettre** à `update`. Le lot journalisait quand même, et rien ne le
/// > signalait : ni la compilation, ni les tests d'alors. Deux fois dans la même heure,
/// > ce n'est pas un accident, c'est une propriété de la forme.
/// >
/// > Sans défaut, le compilateur force chaque site d'appel à décider, et un mutateur
/// > ajouté demain ne peut pas hériter silencieusement du mauvais comportement. Le coût
/// > est de six caractères par appel ; le bénéfice est qu'un oubli devient une erreur de
/// > compilation. **Ne pas remettre de défaut.**
public enum JournalPolicy: Sendable, Hashable {
    /// Une entrée par entité touchée. Le défaut, et ce que veut toute écriture faite à
    /// la main dans l'interface.
    case perEntity
    /// Aucune entrée : l'appelant en écrit une seule pour tout le lot, avec son diff.
    ///
    /// `refreshDerived()` et l'indexation Spotlight restent faits — ce sont eux
    /// l'invariant, le journal n'en fait pas partie.
    case batched
}
