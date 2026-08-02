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
        entityType: String,
        entityID: UUID,
        summary: String
    ) -> ActivityEntry {
        let entry = ActivityEntry()
        entry.actionRaw = action.rawValue
        entry.entityTypeRaw = entityType
        entry.entityID = entityID
        entry.summary = summary
        context.insert(entry)
        return entry
    }
}
