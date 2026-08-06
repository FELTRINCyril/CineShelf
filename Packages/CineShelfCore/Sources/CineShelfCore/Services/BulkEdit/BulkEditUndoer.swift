import Foundation
import SwiftData

// MARK: - L20 · Défaire un lot
//
// **Ce que cette tâche ajoute, et ce qu'elle n'ajoute pas.** Le format du diff existe depuis
// `L10` — `BulkEditDiff`, versionné, écrit dans `ActivityEntry.payload` — et `undoneAt` est
// posé depuis la fermeture du schéma. Ce qui manquait est **l'exécuteur** : personne n'avait
// jamais relu un `payload`. C'est la même forme de trou que `ActivityEntry`, écrit quinze
// prompts avant son premier lecteur.
//
// > **La fiche de `L20` dit « `ActivityEntry.payload` n'existe pas ». C'est périmé** : le champ
// > a été ajouté à la fermeture du schéma le 2026-08-03, précisément pour que `L20` n'ait pas à
// > l'ouvrir. Vérifié dans le modèle avant d'écrire une ligne.
//
// **Le principe, en une phrase : refuser plutôt qu'écraser.** Une annulation qui détruit une
// modification postérieure est pire que pas d'annulation du tout — l'utilisateur perdrait un
// travail qu'il n'a pas demandé à défaire, et sans le savoir. Chaque champ est donc comparé à
// la valeur que le lot avait **écrite** (`after`) avant d'être ramené à celle d'**avant**
// (`before`) ; toute divergence arrête l'annulation entière.
//
// **Tout ou rien, et c'est ce que la fiche demande** : « c'est le lot qui s'annule, pas une
// ligne du lot ». Annuler quarante-six titres sur quarante-sept laisserait une sélection dans
// un état que personne n'a jamais voulu, et qu'aucune trace ne décrit.

/// Ce qu'une annulation a fait, ou pourquoi elle n'a rien fait.
public enum UndoOutcome: Sendable, Equatable {
    /// Le lot est défait. `count` est le nombre d'entités ramenées en arrière.
    case undone(count: Int)
    /// Rien n'a été écrit. Les refus disent ce qui s'y oppose, groupés par cause.
    case refused([UndoRefusal])
}

/// Pourquoi une annulation est refusée.
///
/// **Un cas par cause, et le détail dans le cas** — même choix que `BulkRefusalReason` : une
/// interface doit pouvoir grouper « 3 titres modifiés depuis » sans analyser des phrases.
public struct UndoRefusal: Sendable, Hashable {
    public let entityID: UUID
    public let reason: Reason

    public init(entityID: UUID, reason: Reason) {
        self.entityID = entityID
        self.reason = reason
    }

    /// `Hashable` comme `BulkRefusalReason` : une interface groupe les refus par cause, et
    /// grouper demande de pouvoir les mettre dans un ensemble.
    public enum Reason: Sendable, Hashable {
        /// Aucune entrée de journal de cet identifiant.
        case entryNotFound
        /// L'entrée existe mais ne porte pas de diff : ce n'était pas une opération de masse.
        case notUndoable
        /// Le lot est sorti de la fenêtre d'annulation.
        ///
        /// > **Trouvé par la sonde, et c'était une divergence, pas un manque.** `isUndoable`
        /// > répondait « non » au-delà de trente jours pendant qu'`undo` défaisait quand même :
        /// > deux réponses à la même question, la pire des formes. L'interface aurait grisé le
        /// > bouton, et tout appel programmatique — un App Intent, un raccourci — serait passé
        /// > outre. La fenêtre est désormais tenue **ici**, et `isUndoable` la lit du même
        /// > endroit ; la purge de `L16` n'est plus qu'une libération d'espace, pas la seule
        /// > chose qui fait respecter la borne.
        case expired
        /// Ce lot a déjà été défait. **Rejouer l'inverse écraserait ce qui a été saisi
        /// depuis**, puisque les valeurs sont déjà celles d'avant.
        case alreadyUndone
        /// Le diff vient d'un format qu'on ne sait pas relire.
        case unsupportedVersion(Int)
        /// L'entité a disparu du magasin depuis le lot.
        case entityNotFound
        /// L'entité est à la corbeille. La restaurer d'abord est une décision de
        /// l'utilisateur, pas un effet de bord d'une annulation.
        case entityInTrash
        /// Un champ ne porte plus la valeur que le lot y avait écrite : quelqu'un — ou un
        /// autre appareil — l'a modifié depuis.
        case fieldChangedSince(field: String, expected: String?, found: String?)
        /// Une relation ne porte plus ce que le lot y avait mis.
        case relationChangedSince(field: String, missing: [UUID], unexpected: [UUID])
    }
}

/// L'exécuteur d'annulation. **Un seul pour les deux opérations**, comme la fiche l'exige :
/// l'édition en masse et la fusion produisent le même format de diff, donc deux exécuteurs
/// finiraient par diverger sur la moitié des cas.
///
/// La fusion (`L8`) est reportée en v1.1 ; ce type n'en dépend pas — il lit un `BulkEditDiff`,
/// quelle que soit l'opération qui l'a écrit.
@MainActor
public struct BulkEditUndoer {

    /// La fenêtre pendant laquelle un lot reste annulable.
    ///
    /// **Trente jours, et ce n'est pas un nombre choisi ici** : le bloc `5e` du design écrit
    /// « 30 jours conservés » sous le titre du fil. Aligner les deux évite qu'une entrée
    /// visible se révèle inannulable, ou l'inverse.
    public static let window: TimeInterval = 30 * 24 * 60 * 60

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Défait le lot journalisé sous `activityID`.
    ///
    /// - Parameters:
    ///   - activityID: l'identifiant rendu par `BulkEditor.apply`.
    ///   - now: l'instant de référence, paramétré pour que les tests fixent la fenêtre plutôt
    ///     que de dépendre de l'horloge.
    /// - Returns: `.undone` avec le compte d'entités ramenées, ou `.refused` — et dans ce cas
    ///   **rien n'a été écrit**.
    /// - Throws: l'erreur de `fetch` ou de `save()`. Le contexte est ramené à son état d'avant
    ///   dans tous les cas.
    @discardableResult
    public func undo(activityID: UUID, now: Date = .now) throws -> UndoOutcome {
        do {
            guard let entry = try entry(activityID) else {
                return .refused([.init(entityID: activityID, reason: .entryNotFound)])
            }
            guard let payload = entry.payload else {
                // **Deux causes pour un même symptôme, et elles ne disent pas la même chose à
                // l'utilisateur.** Une entrée ordinaire n'a jamais eu de diff : « ce n'était
                // pas une opération de masse ». Une entrée purgée en avait un : « c'est trop
                // vieux ». Rendre `notUndoable` dans les deux cas laisserait croire qu'un lot
                // de six semaines n'a jamais été annulable, alors qu'il l'a été pendant trente
                // jours. La fenêtre départage.
                let reason: UndoRefusal.Reason =
                    isWithinWindow(entry, now: now) ? .notUndoable : .expired
                return .refused([.init(entityID: activityID, reason: reason)])
            }
            guard entry.undoneAt == nil else {
                return .refused([.init(entityID: activityID, reason: .alreadyUndone)])
            }
            guard isWithinWindow(entry, now: now) else {
                return .refused([.init(entityID: activityID, reason: .expired)])
            }

            let diff: BulkEditDiff
            do {
                diff = try BulkEditDiff.decoded(from: payload)
            } catch BulkEditDiffError.unsupportedVersion(let version) {
                // **Refusé, pas deviné.** Un diff d'une version inconnue peut avoir changé de
                // sémantique sur n'importe quel champ ; l'interpréter au jugé écrirait des
                // valeurs fausses dans la base, en silence.
                return .refused([.init(entityID: activityID, reason: .unsupportedVersion(version))])
            }

            let plan = try prepare(diff)
            guard plan.refusals.isEmpty else { return .refused(plan.refusals) }

            apply(plan)
            entry.undoneAt = now
            journalUndo(of: entry, diff: diff)
            try context.save()
            return .undone(count: plan.steps.count)
        } catch {
            // Même garantie que `BulkEditor.apply` : une sortie non nominale ne laisse pas de
            // mutation partielle en attente, que le prochain `save()` écrirait.
            context.rollback()
            throw error
        }
    }

    /// Un lot est-il encore annulable à cet instant ?
    ///
    /// **Trois conditions, et la troisième est la fenêtre** : porter un diff, ne pas avoir déjà
    /// été défait, et ne pas être plus vieux que `window`. `ActivityEntry.isUndoable` ne connaît
    /// que les deux premières — c'est une propriété du modèle, et le modèle n'a pas d'horloge.
    public func isUndoable(_ entry: ActivityEntry, now: Date = .now) -> Bool {
        entry.isUndoable && isWithinWindow(entry, now: now)
    }

    /// **Le seul juge de la fenêtre**, lu par `isUndoable` comme par `undo`. Deux calculs
    /// séparés, c'était le défaut que la sonde a trouvé.
    private func isWithinWindow(_ entry: ActivityEntry, now: Date) -> Bool {
        now.timeIntervalSince(entry.createdAt) <= Self.window
    }

    // MARK: - Purge
    //
    // Appelée par la passe de maintenance de `L16`. Elle vit ici parce que la fenêtre et le
    // format sont ici : `L16` décide *quand* purger, `L20` sait *quoi*.

    /// Efface les diffs devenus inannulables, **sans toucher aux entrées elles-mêmes**.
    ///
    /// **C'est le `payload` qui coûte, pas la ligne.** Il est en `.externalStorage` et il est
    /// synchronisé ; le résumé, lui, fait quelques dizaines d'octets et porte la piste d'audit.
    /// Supprimer l'entrée entière effacerait la trace de l'opération en même temps que la
    /// capacité de la défaire — or « qui a modifié ces 47 titres » reste une question valide
    /// bien après que l'annulation soit devenue impossible.
    ///
    /// **Rejouable** : une entrée déjà purgée n'a plus de `payload`, donc le second passage la
    /// laisse tranquille et rend 0. La fiche l'exige — « la purge des diffs anciens est
    /// rejouable ».
    ///
    /// - Returns: le nombre de diffs effacés.
    @discardableResult
    public func purgeExpiredPayloads(now: Date = .now) throws -> Int {
        let cutoff = now.addingTimeInterval(-Self.window)
        // Le prédicat porte sur `payload != nil` **et** sur la date : filtrer après le `fetch`
        // matérialiserait tout le journal, dont les `Data` en stockage externe — exactement ce
        // que `L1` a mesuré à 248 ms pour 5 000 objets.
        let descriptor = FetchDescriptor<ActivityEntry>(
            predicate: #Predicate { $0.payload != nil && $0.createdAt < cutoff })
        let expired = try context.fetch(descriptor)
        for entry in expired { entry.payload = nil }
        if !expired.isEmpty { try context.save() }
        return expired.count
    }

    // MARK: - Le plan
    //
    // **Vérifier tout, puis écrire.** Deux passes et non une : une annulation qui écrirait au
    // fil de sa vérification laisserait, sur le premier champ divergent, la moitié du lot
    // défaite — c'est-à-dire le désordre que « tout ou rien » existe pour empêcher.

    private struct Plan {
        var steps: [Step] = []
        var refusals: [UndoRefusal] = []
    }

    /// Ce qu'il faut faire à une entité pour la ramener en arrière.
    private struct Step {
        let entityID: UUID
        let subject: UndoSubject
        /// Champ → valeur d'avant.
        let fields: [String: String?]
        /// À rattacher (le lot les avait détachés) et à détacher (le lot les avait rattachés).
        let reattach: [UUID]
        let detach: [UUID]
    }

    private func prepare(_ diff: BulkEditDiff) throws -> Plan {
        var plan = Plan()
        // Les entrées vides ne décrivent aucun changement : les compter dans le total ferait
        // annoncer « 47 titres remis en arrière » quand quarante-cinq n'avaient pas bougé.
        for entry in diff.entries where !entry.isEmpty {
            guard let subject = try subject(of: entry) else {
                plan.refusals.append(.init(entityID: entry.entityID, reason: .entityNotFound))
                continue
            }
            guard subject.deletedAt == nil else {
                plan.refusals.append(.init(entityID: entry.entityID, reason: .entityInTrash))
                continue
            }

            var restored: [String: String?] = [:]
            var diverged = false
            for change in entry.fields where !change.isNoOp {
                let current = subject.value(of: change.field)
                guard current == change.after else {
                    plan.refusals.append(
                        .init(
                            entityID: entry.entityID,
                            reason: .fieldChangedSince(
                                field: change.field, expected: change.after, found: current)))
                    diverged = true
                    continue
                }
                restored[change.field] = change.before
            }

            let related = Set(subject.relatedIDs(of: diff.field))
            // Ce que le lot avait rattaché doit encore l'être, et ce qu'il avait détaché doit
            // encore être absent. Sinon quelqu'un a retouché la relation depuis.
            let missing = entry.attached.filter { !related.contains($0) }
            let unexpected = entry.detached.filter { related.contains($0) }
            if !missing.isEmpty || !unexpected.isEmpty {
                plan.refusals.append(
                    .init(
                        entityID: entry.entityID,
                        reason: .relationChangedSince(
                            field: diff.field, missing: missing, unexpected: unexpected)))
                diverged = true
            }

            guard !diverged else { continue }
            plan.steps.append(
                Step(
                    entityID: entry.entityID, subject: subject, fields: restored,
                    reattach: entry.detached, detach: entry.attached))
        }
        return plan
    }

    private func apply(_ plan: Plan) {
        for step in plan.steps {
            // **Une seule écriture par entité**, tous champs et relations confondus. Deux
            // écritures successives feraient tourner `refreshDerived()` sur un état
            // intermédiaire — et, pour une date, sur une `releaseDate` remise sans sa
            // `releasePrecision`. C'est exactement le couple que `L10` prend soin de journaliser
            // ensemble, et le défaire séparément rejouerait le bug du prompt 11.
            step.subject.restore(fields: step.fields, reattach: step.reattach, detach: step.detach, in: context)
        }
    }

    // MARK: - Journal

    /// L'annulation est elle-même journalisée, et **sans `payload`**.
    ///
    /// Une annulation n'est pas annulable : la refaire serait réappliquer le lot, ce qui est un
    /// nouveau lot, pas un retour en arrière. Lui donner un diff laisserait croire le contraire
    /// — et `isUndoable` deviendrait vrai sur une entrée qu'aucun code ne sait défaire.
    private func journalUndo(of entry: ActivityEntry, diff: BulkEditDiff) {
        let undo = ActivityEntry.make(
            action: .undo,
            entityType: entry.entityType ?? .batch,
            entityID: entry.id,
            summary: "Annulé : \(diff.summary)")
        context.insert(undo)
    }

    // MARK: - Résolution

    private func entry(_ id: UUID) throws -> ActivityEntry? {
        var descriptor = FetchDescriptor<ActivityEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func subject(of entry: BulkEditDiff.Entry) throws -> UndoSubject? {
        let id = entry.entityID
        switch entry.entityType {
        case .title:
            var descriptor = FetchDescriptor<Title>(predicate: TitleQuery.withID(id))
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map(UndoSubject.title)
        case .person:
            var descriptor = FetchDescriptor<Person>(predicate: PersonQuery.withID(id))
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map(UndoSubject.person)
        default:
            // Un type qu'aucune édition en masse ne produit aujourd'hui. Le traiter comme
            // « introuvable » plutôt que d'ignorer l'entrée : ignorer ferait annoncer un succès
            // sur un lot partiellement défait.
            return nil
        }
    }
}
