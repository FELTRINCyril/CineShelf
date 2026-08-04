import Foundation
import SwiftData

/// Journalise les écritures : alimente l'écran « Fil » et donne une piste
/// d'audit pour les fusions et les imports (`docs/02` §3.9).
///
/// **Non isolé depuis `L11b`, et c'était une isolation par contagion.** Ce type était
/// `@MainActor` parce que ses appelants le sont, pas parce qu'il en a besoin : il ne touche
/// qu'un `ModelContext` et une `ActivityEntry`, jamais `SpotlightIndexer`. Or `ImportActor`
/// doit écrire l'entrée de son lot depuis l'acteur, et l'isolation l'en empêchait — ce qui
/// aurait conduit à recopier la construction de l'entrée dans l'import, donc à deux façons
/// d'écrire le fil d'activité. Le dépôt a déjà payé ça une fois avec les bornes de la note.
///
/// Il hérite désormais de l'isolation de son appelant, comme `EntityResolver` et
/// `ImportWriter` : sur le fil principal depuis un repository, sur l'acteur depuis un import.
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
    /// **Pourquoi cette fabrique existe.** À l'origine, parce que `ActivityRecorder` était
    /// `@MainActor` et qu'une écriture de masse tournant dans un acteur ne pouvait pas
    /// l'appeler. `L11b` a levé cette isolation — elle était par contagion — donc la raison
    /// première a disparu, et la fabrique reste pour la seconde, qui vaut toujours : sans ce
    /// point commun, chaque écrivain recopierait les quatre affectations, et le jour où une
    /// cinquième colonne devient obligatoire, l'un des chemins écrirait des entrées incomplètes
    /// — dans une piste d'audit, en silence.
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
