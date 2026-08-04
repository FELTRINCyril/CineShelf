import Foundation
import SwiftData

/// Journalise les écritures : alimente l'écran « Fil » et donne une piste
/// d'audit pour les fusions et les imports (`docs/02` §3.9).
@MainActor
public struct ActivityRecorder {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func record(_ action: ActivityAction, _ entity: some ActivityDescribing) -> ActivityEntry {
        record(
            action,
            entityType: entity.activityEntityType,
            entityID: entity.activityEntityID,
            summary: entity.activitySummary
        )
    }

    /// Pour les actions qui ne portent pas sur une entité unique : une fusion,
    /// un import de lot.
    @discardableResult
    public func record(
        _ action: ActivityAction,
        entityType: ActivityEntityType,
        entityID: UUID,
        summary: String
    ) -> ActivityEntry {
        let entry = ActivityEntry.make(
            action: action,
            entityType: entityType,
            entityID: entityID,
            summary: summary
        )
        context.insert(entry)
        return entry
    }
}

extension ActivityEntry {

    /// Construit une entrée, sans l'insérer.
    ///
    /// **Pourquoi cette fabrique existe.** `ActivityRecorder` est `@MainActor`, et une
    /// écriture de masse tourne dans un acteur dédié : elle ne peut pas l'appeler. Sans
    /// ce point commun, l'édition en masse recopierait les quatre affectations, et le
    /// jour où une cinquième colonne devient obligatoire, l'un des deux chemins
    /// écrirait des entrées incomplètes — dans une piste d'audit, en silence.
    ///
    /// N'insère pas : l'appelant connaît son contexte, la fabrique non.
    static func make(
        action: ActivityAction,
        entityType: ActivityEntityType,
        entityID: UUID,
        summary: String
    ) -> ActivityEntry {
        let entry = ActivityEntry()
        entry.actionRaw = action.rawValue
        entry.entityTypeRaw = entityType.rawValue
        entry.entityID = entityID
        entry.summary = summary
        return entry
    }
}
