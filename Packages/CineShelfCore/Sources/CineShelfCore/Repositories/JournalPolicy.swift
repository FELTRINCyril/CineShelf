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
