import Foundation
import SwiftData

// MARK: - Appliquer un import au magasin, par lots, annulable
//
// L'étape 4 de l'import. Ce qui est écrit ici traverse trois exigences qui se contredisent
// presque :
//
//  - **par lots de 200**, pour que la mémoire ne monte pas et que l'interface ne se fige pas ;
//  - **annulable à tout moment**, en laissant un état cohérent — « pas un demi-lot » ;
//  - **une seule entrée de journal** pour l'ensemble, avec de quoi l'annuler.
//
// La contradiction est entre les deux premières : sauvegarder par lots veut dire qu'une partie
// est déjà durable quand l'annulation arrive. Le choix, hérité de `ImportActorTests`, est
// assumé et documenté : **la reprise est par lot, pas par élément**. Les lots déjà sauvegardés
// restent, le lot en cours est annulé par `rollback()`, et le bilan dit exactement où ça s'est
// arrêté. L'alternative — tout ou rien sur 1 284 lignes — demanderait une transaction unique
// que SwiftData n'expose pas, et ferait perdre une heure d'import sur une annulation.

/// Ce qu'un import a produit.
public struct ImportRunResult: Sendable, Hashable {

    /// Les titres créés, dans l'ordre du fichier.
    public let createdTitleIDs: [UUID]
    /// Les titres existants complétés.
    public let completedTitleIDs: [UUID]
    /// Les doublons dont rien n'était à compléter.
    public let unchangedTitleIDs: [UUID]
    /// Les personnes, collections et genres créés en passant.
    public let createdReferenceIDs: [UUID]
    /// L'entrée de journal du lot, `nil` si rien n'a été écrit.
    public let activityID: UUID?
    /// `true` si l'import a été interrompu avant la fin.
    public let wasCancelled: Bool
    /// Le nombre de lignes traitées, y compris celles qui n'ont rien changé.
    public let processedCount: Int

    public init(
        createdTitleIDs: [UUID] = [],
        completedTitleIDs: [UUID] = [],
        unchangedTitleIDs: [UUID] = [],
        createdReferenceIDs: [UUID] = [],
        activityID: UUID? = nil,
        wasCancelled: Bool = false,
        processedCount: Int = 0
    ) {
        self.createdTitleIDs = createdTitleIDs
        self.completedTitleIDs = completedTitleIDs
        self.unchangedTitleIDs = unchangedTitleIDs
        self.createdReferenceIDs = createdReferenceIDs
        self.activityID = activityID
        self.wasCancelled = wasCancelled
        self.processedCount = processedCount
    }

    /// Le bilan chiffré de la planche 11j.
    public var summary: String {
        "\(createdTitleIDs.count) ajoutés, \(completedTitleIDs.count) complétés, "
            + "\(unchangedTitleIDs.count) inchangés"
    }
}

public enum ImportRunError: Error, Sendable, Hashable {
    /// La bibliothèque visée n'existe pas, ou plus.
    case libraryNotFound(UUID)
    /// L'entité importée n'a pas de schéma de colonnes.
    case unsupportedEntity(ActivityEntityType)
    /// Un import est déjà en cours sur cet acteur.
    ///
    /// **La contrepartie d'avoir rendu `importRows` asynchrone.** Un acteur est **réentrant** :
    /// pendant un `await Task.yield()`, un second appel peut s'exécuter entre deux lots du
    /// premier. Les deux partageraient alors le `ModelContext` de l'acteur, donc leurs
    /// écritures s'entremêleraient dans les mêmes `save()`, et le `rollback()` de l'un
    /// jetterait le lot en cours de l'autre. Rien ne le signalerait : les deux imports
    /// rendraient un bilan plausible et faux.
    ///
    /// « Un seul brouillon d'import à la fois » le rendait improbable par l'interface ; ce cas
    /// le rend impossible par le code.
    case alreadyRunning
}

/// Le verrou d'un import à la fois, porté par l'acteur.
///
/// Une classe et non une propriété d'`ImportActor` : le macro `@ModelActor` synthétise le
/// stockage de l'acteur, et une extension ne peut pas y ajouter de propriété. L'instance est
/// isolée par l'acteur qui la détient, donc l'accès reste sérialisé.
final class ImportRunLock {
    private var running = false

    /// Prend le verrou, ou rend `false` s'il est déjà pris.
    func acquire() -> Bool {
        guard !running else { return false }
        running = true
        return true
    }

    func release() { running = false }
}

extension ImportActor {

    /// Le verrou de cet acteur. Un seul import à la fois.
    ///
    /// Associé à l'acteur par son identité plutôt que stocké dans une propriété, que
    /// `@ModelActor` empêche d'ajouter depuis une extension. La table est protégée par le fil
    /// principal : elle n'est touchée qu'à la prise et à la libération du verrou, deux
    /// opérations courtes.
    private static let locks = LockTable()

    final class LockTable: @unchecked Sendable {
        private let mutex = NSLock()
        private var table: [ObjectIdentifier: ImportRunLock] = [:]

        func lock(for actor: ImportActor) -> ImportRunLock {
            mutex.withLock {
                let key = ObjectIdentifier(actor)
                if let existing = table[key] { return existing }
                let lock = ImportRunLock()
                table[key] = lock
                return lock
            }
        }
    }

    /// Applique des lignes **déjà validées** à la bibliothèque.
    ///
    /// - Parameters:
    ///   - rows: les lignes prêtes. Celles qui portent un refus sont ignorées ici plutôt que
    ///     refusées : l'appelant a pu choisir « importer les 771 lignes prêtes », et lui
    ///     renvoyer une erreur l'obligerait à filtrer deux fois.
    ///   - fileName: pour le fil d'activité et le diff.
    ///   - libraryID: la bibliothèque d'accueil, retrouvée dans le contexte de l'acteur.
    ///   - entity: l'entité importée. Seuls les titres sont écrits pour l'instant.
    ///   - progress: avancement entre 0 et 1, appelé **à chaque lot sauvegardé** et non à
    ///     chaque ligne : une fermeture appelée 1 284 fois depuis un acteur coûte plus que
    ///     l'import lui-même.
    /// - Returns: le bilan, y compris en cas d'annulation.
    /// - Throws: `ImportRunError`, ou l'erreur de sauvegarde.
    public func importRows(
        _ rows: [ImportRow],
        fileName: String,
        libraryID: UUID,
        entity: ActivityEntityType = .title,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ImportRunResult {
        guard let schema = CSVSchema.schema(for: entity), entity == .title else {
            throw ImportRunError.unsupportedEntity(entity)
        }
        let lock = Self.locks.lock(for: self)
        guard lock.acquire() else { throw ImportRunError.alreadyRunning }
        defer { lock.release() }
        let library = try self.library(id: libraryID)
        let ready = rows.filter(\.isReady)
        guard !ready.isEmpty else { return ImportRunResult() }

        var writer = ImportWriter(context: modelContext, library: library, schema: schema)
        var outcomes: [ImportWriter.Outcome] = []

        // **Les instantanés de frontière, et pourquoi ils remplacent un calcul.** Ma première
        // version reconstituait l'état durable après annulation par `created.prefix(saved)`, où
        // `saved` comptait des **lignes** et `created` des **titres** : dès qu'une ligne
        // complétait un doublon au lieu de créer, la découpe partait de travers et le bilan
        // annonçait des titres qui n'existaient pas. Un instantané pris à chaque `save()` ne se
        // calcule pas, il se constate.
        var committedOutcomes = 0
        var committedReferences: Set<UUID> = []
        var cancelled = false

        for (offset, row) in ready.enumerated() {
            // **L'annulation est vérifiée avant d'écrire la ligne, pas après.** Après, la ligne
            // serait écrite puis annulée par `rollback()`, ce qui donne le même magasin mais un
            // compte faux : le bilan annoncerait une ligne qui n'est pas là.
            if Task.isCancelled {
                cancelled = true
                break
            }

            outcomes.append(writer.write(title: row))

            // **Rendre la main plus souvent que l'on sauvegarde.** La durabilité a pour unité le
            // lot de 200 ; la réactivité, elle, n'a pas à s'y aligner. Mesuré : avec une seule
            // suspension par lot, le fil d'exécution restait tenu 160 ms d'affilée — un
            // à-coup visible. À 50 lignes, c'est 40 ms, et le coût total des suspensions
            // supplémentaires est indétectable devant l'écriture.
            if (offset + 1).isMultiple(of: Self.yieldInterval) { await Task.yield() }

            guard (offset + 1).isMultiple(of: Self.batchSize) else { continue }
            try modelContext.save()
            committedOutcomes = outcomes.count
            committedReferences = writer.createdReferenceIDs
            progress?(Double(offset + 1) / Double(ready.count))

            // **Le point de suspension, et sans lui l'annulation était décorative.** Mesuré :
            // cette méthode était synchrone, donc elle tenait son fil d'exécution du premier
            // au dernier titre — 6,3 secondes sans rendre la main sur 1 500 lignes. Deux
            // conséquences, l'une grave et l'autre pire :
            //
            //  - l'appelant qui voulait annuler **ne pouvait pas** : mesuré, un `cancel()`
            //    programmé 300 ms après le début ne s'exécutait qu'à 6,8 s, après la fin de
            //    l'import. Le drapeau arrivait donc toujours trop tard, et le
            //    `if Task.isCancelled` de la boucle ne mordait jamais. Le test l'aurait
            //    confirmé « vert » en annulant avant le démarrage, ce qui ne prouve rien ;
            //  - le fil **principal** était l'un des fils que le pool coopératif donnait à cet
            //    acteur (mesuré : `Thread.isMainThread == true` dans la boucle), donc
            //    l'interface gelait pendant tout l'import — précisément ce que `ImportActor`
            //    existe pour éviter (`docs/04` §3).
            //
            // **Aucun test ne prouve cette ligne, et il faut le dire.** La suspension sert la
            // *réactivité*, pas la sémantique d'annulation : les tests d'annulation annulent
            // depuis la fermeture de progression — donc depuis l'acteur — et le drapeau est alors
            // vu au tour suivant sans qu'aucune suspension soit nécessaire. Preuve d'échec
            // tentée : `Task.yield()` retiré, les cinq tests d'annulation **passent**.
            //
            // Ce qui justifie la ligne est donc la mesure, pas un test : réveils du fil principal
            // toutes les ~35 ms pendant l'import, contre un blocage de 6,3 s d'affilée sans elle.
            // C'est le même statut que les budgets de `docs/04` §4, qui se vérifient avec
            // Instruments sur appareil — écart inscrit dans `docs/PROMPTS.md`.
            await Task.yield()
        }

        if cancelled {
            // **Le lot en cours est annulé, les précédents restent.** C'est ce que « l'abandon à
            // mi-parcours laisse un état cohérent et non un demi-lot » veut dire ici : la
            // frontière est le dernier `save()`, et le bilan la dit.
            modelContext.rollback()
            let result = try finish(
                outcomes: Array(outcomes.prefix(committedOutcomes)),
                references: committedReferences,
                fileName: fileName,
                entity: entity,
                cancelled: true)
            progress?(Double(committedOutcomes) / Double(ready.count))
            return result
        }

        if modelContext.hasChanges { try modelContext.save() }
        progress?(1)
        return try finish(
            outcomes: outcomes,
            references: writer.createdReferenceIDs,
            fileName: fileName,
            entity: entity,
            cancelled: false)
    }

    /// Écrit l'entrée de journal du lot et rend le bilan.
    ///
    /// **Une entrée pour l'import, pas une par titre** — `JournalPolicy.batched`, et la fiche
    /// `L10` l'exigeait déjà pour l'édition en masse : 1 284 entrées noieraient le fil sans rien
    /// dire de plus que « 1 284 titres importés ». C'est aussi cette entrée qui porte le
    /// `payload` dont `L20` a besoin.
    ///
    /// Elle est écrite **après** les données, dans une sauvegarde distincte : si l'écriture du
    /// journal échouait, les titres seraient déjà là, et un fil incomplet est moins grave qu'un
    /// import perdu. L'inverse — journal d'abord — laisserait une entrée annonçant un import qui
    /// n'a pas eu lieu, donc annulable dans le vide.
    private func finish(
        outcomes: [ImportWriter.Outcome],
        references: Set<UUID>,
        fileName: String,
        entity: ActivityEntityType,
        cancelled: Bool
    ) throws -> ImportRunResult {
        // Le repliage est fait **ici et une seule fois**, à partir des issues durables. Le
        // tenir à jour dans la boucle obligeait à défaire trois listes en cas d'annulation, et
        // c'est là que la première version se trompait.
        var created: [UUID] = []
        var completed: [UUID] = []
        var unchanged: [UUID] = []
        var completions: [ImportBatchDiff.Completion] = []
        for outcome in outcomes {
            switch outcome {
            case .created(let id):
                created.append(id)
            case .completed(let id, let previousValues):
                completed.append(id)
                completions.append(.init(entityID: id, previousValues: previousValues))
            case .unchanged(let id):
                unchanged.append(id)
            }
        }

        guard !created.isEmpty || !completions.isEmpty else {
            return ImportRunResult(
                unchangedTitleIDs: unchanged,
                wasCancelled: cancelled,
                processedCount: outcomes.count)
        }

        let diff = ImportBatchDiff(
            fileName: fileName,
            entity: entity,
            createdTitleIDs: created,
            createdReferenceIDs: references.sorted { $0.uuidString < $1.uuidString },
            completions: completions)

        // `ActivityRecorder` et non une `ActivityEntry` construite à la main : il porte déjà la
        // forme d'une entrée de lot (`entityType: .batch`, un identifiant qui désigne le lot
        // lui-même), et il est désormais appelable depuis l'acteur.
        let entry = ActivityRecorder(context: modelContext).record(
            .import,
            entityType: .batch,
            entityID: UUID(),
            summary: Self.journalSummary(
                created: created.count, completed: completions.count,
                fileName: fileName, cancelled: cancelled))
        entry.payload = try diff.encoded()
        try modelContext.save()

        return ImportRunResult(
            createdTitleIDs: created,
            completedTitleIDs: completed,
            unchangedTitleIDs: unchanged,
            createdReferenceIDs: diff.createdReferenceIDs,
            activityID: entry.id,
            wasCancelled: cancelled,
            processedCount: outcomes.count)
    }

    /// Le texte du fil d'activité. En français, comme toute l'interface.
    static func journalSummary(created: Int, completed: Int, fileName: String, cancelled: Bool) -> String {
        var parts: [String] = []
        if created > 0 { parts.append("\(created) titre\(created > 1 ? "s" : "") ajouté\(created > 1 ? "s" : "")") }
        if completed > 0 {
            parts.append("\(completed) complété\(completed > 1 ? "s" : "")")
        }
        let core = parts.isEmpty ? "aucun titre" : parts.joined(separator: ", ")
        return cancelled
            ? "Import de \(fileName) interrompu : \(core)"
            : "Import de \(fileName) : \(core)"
    }

    /// La bibliothèque, dans le contexte de **cet** acteur.
    ///
    /// Elle est retrouvée par identifiant et non reçue en paramètre : un `@Model` appartient au
    /// contexte qui l'a lu, et le traverser vers un acteur ne compile pas en concurrence
    /// stricte. Même motif que `BulkEditor`, qui reçoit des `UUID`.
    private func library(id: UUID) throws -> Library {
        var descriptor = FetchDescriptor<Library>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let library = try modelContext.fetch(descriptor).first else {
            throw ImportRunError.libraryNotFound(id)
        }
        return library
    }
}
