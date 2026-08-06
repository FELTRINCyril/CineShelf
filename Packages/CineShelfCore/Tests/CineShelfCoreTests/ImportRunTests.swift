import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// L'application d'un import au magasin. **Tout le risque de `L11a` / `L11b` est ici.**
//
// Chaque test de ce fichier vient d'une **sonde adverse** lancée avant d'écrire la suite, comme
// `CLAUDE.md` l'exige désormais pour les tâches critiques de données. Trois défauts n'auraient
// été trouvés par aucun test écrit depuis les mêmes hypothèses que le code :
//
//  - l'annulation était **décorative** : la méthode était synchrone, donc elle tenait son fil
//    6,3 s sans jamais rendre la main, et un `cancel()` programmé à 300 ms ne s'exécutait qu'à
//    6,8 s — après la fin. Un test qui annule *avant* le démarrage passait au vert ;
//  - le fil **principal** était l'un des fils que le pool coopératif donnait à l'acteur, donc
//    l'interface gelait pendant tout l'import — ce que `ImportActor` existe pour empêcher ;
//  - le bilan d'une annulation se calculait par `created.prefix(lignes sauvegardées)`, où l'un
//    comptait des titres et l'autre des lignes : dès qu'une ligne complétait un doublon, le
//    bilan annonçait des titres qui n'existaient pas.
//
// Les seuils assenés viennent de `CatalogBounds` et de `docs/02` §3.3. Aucun ne vient d'une
// planche de design.

@MainActor
struct ImportRunFixture {
    let container: ModelContainer
    let context: ModelContext
    let library: Library

    var actor: ImportActor { ImportActor(modelContainer: container) }
    /// Un contexte neuf sur le même magasin : ce qu'un autre écran verrait.
    func freshContext() -> ModelContext { ModelContext(container) }

    func titles() throws -> [Title] {
        try freshContext().fetch(FetchDescriptor<Title>())
    }
    func people() throws -> [Person] {
        try freshContext().fetch(FetchDescriptor<Person>())
    }
    func batchEntries() throws -> [ActivityEntry] {
        try freshContext().fetch(FetchDescriptor<ActivityEntry>()).filter { $0.entityType == .batch }
    }
}

@MainActor
func makeImportFixture() throws -> ImportRunFixture {
    let container = try makeTestContainer()
    let context = ModelContext(container)
    let library = Library(name: "Principal", isDefault: true)
    context.insert(library)
    try context.save()
    return ImportRunFixture(container: container, context: context, library: library)
}

/// Les lignes prêtes d'un fichier bâti à la volée.
///
/// Le chemin complet — octets, découpage, correspondance, validation — et non des `ImportRow`
/// fabriquées à la main : c'est ce qui garantit que ces tests exercent ce que l'app exécute, y
/// compris la projection des cellules depuis `rawFields`.
@MainActor
func importRows(header: [String], rows: [[String]]) -> [ImportRow] {
    let document = CSVReader().read(csv(header: header, rows: rows))
    let columns = ColumnMatcher(schema: .title).analyze(header: document.header, rows: document.rows)
    return ImportValidator(schema: .title).analyze(document: document, columns: columns).rows
}

@MainActor
struct ImportRunTests {

    @Test("Un titre neuf est écrit avec ses relations")
    func writesTitleWithRelations() async throws {
        let fixture = try makeImportFixture()
        let rows = importRows(
            header: ["Titre", "Année", "Genres", "Collection", "Réalisation", "Distribution"],
            rows: [["Dune", "2021", "sci-fi|thriller", "Saga Dune", "Denis Villeneuve", "Timothée Chalamet"]])

        let result = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)

        #expect(result.createdTitleIDs.count == 1)
        let title = try #require(try fixture.titles().first)
        #expect(title.name == "Dune")
        #expect(title.releaseYear == 2021)
        #expect((title.genres ?? []).count == 2)
        #expect(title.collection?.name == "Saga Dune")
        #expect((title.credits ?? []).count == 2)
    }

    @Test("Une année seule donne une date au 1er janvier, et la précision le dit")
    func yearOnlyKeepsItsPrecision() async throws {
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", "2021"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let title = try #require(try fixture.titles().first)
        // Sans `releasePrecision`, l'interface afficherait « 1er janvier 2021 » là où le fichier
        // ne disait que « 2021 ».
        #expect(title.releasePrecision == .year)
        #expect(title.releaseYear == 2021)
    }

    @Test("Seules les lignes prêtes sont écrites")
    func onlyReadyRowsAreWritten() async throws {
        let fixture = try makeImportFixture()
        let rows = importRows(header: ["Titre", "Année"], rows: [["Dune", "2021"], ["", "2020"]])

        let result = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)

        // L'appelant a pu choisir « importer les 771 lignes prêtes » : lui renvoyer une erreur
        // l'obligerait à filtrer deux fois.
        #expect(result.createdTitleIDs.count == 1)
        #expect(try fixture.titles().map(\.name) == ["Dune"])
    }

    @Test("Un fichier sans aucune ligne prête n'écrit rien, pas même une entrée de journal")
    func nothingReadyWritesNothing() async throws {
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["", "2021"], ["", "2020"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(result.activityID == nil)
        #expect(try fixture.titles().isEmpty)
        // Une entrée annonçant un import qui n'a pas eu lieu serait annulable dans le vide.
        #expect(try fixture.batchEntries().isEmpty)
    }

    @Test("Une bibliothèque inconnue est refusée avant toute écriture")
    func unknownLibraryIsRefused() async throws {
        let fixture = try makeImportFixture()
        let unknown = UUID()

        await #expect(throws: ImportRunError.libraryNotFound(unknown)) {
            try await fixture.actor.importRows(
                importRows(header: ["Titre"], rows: [["Dune"]]),
                fileName: "f.csv", libraryID: unknown)
        }
        #expect(try fixture.titles().isEmpty)
    }

    @Test("Une entité sans schéma de colonnes est refusée")
    func unsupportedEntityIsRefused() async throws {
        let fixture = try makeImportFixture()
        await #expect(throws: ImportRunError.unsupportedEntity(.genre)) {
            try await fixture.actor.importRows(
                [], fileName: "f.csv", libraryID: fixture.library.id, entity: .genre)
        }
    }
}

// MARK: - Le journal du lot

@MainActor
struct ImportJournalTests {

    @Test("Un import de trois lignes écrit UNE entrée de journal")
    func oneEntryForTheWholeBatch() async throws {
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Genres"], rows: [["A", "x"], ["B", "y"], ["C", "z"]]),
            fileName: "collection.csv", libraryID: fixture.library.id)

        // `JournalPolicy.batched` : 1 284 entrées noieraient le fil sans rien dire de plus que
        // « 1 284 titres importés ».
        let entries = try fixture.batchEntries()
        #expect(entries.count == 1)
        #expect(result.activityID == entries.first?.id)
        #expect(entries.first?.action == .import)
        #expect(entries.first?.summary.contains("collection.csv") == true)
    }

    @Test("L'entrée porte un diff relisible, et qui s'accorde avec le magasin")
    func payloadAgreesWithTheStore() async throws {
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", "2021"], ["Tenet", "2020"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let payload = try #require(try fixture.batchEntries().first?.payload)
        let diff = try ImportBatchDiff.decoded(from: payload)

        #expect(diff.createdTitleIDs == result.createdTitleIDs)
        // C'est cette liste qui rend « voir les 1 081 titres ajoutés » réalisable : le schéma
        // est fermé, donc aucun champ d'import n'existe sur `Title`.
        let stored = Set(try fixture.titles().map(\.id))
        #expect(Set(diff.createdTitleIDs).isSubset(of: stored))
        #expect(diff.fileName == "f.csv")
    }

    @Test("Une version de diff inconnue est refusée, pas devinée")
    func unknownDiffVersionIsRefused() throws {
        let future = ImportBatchDiff(
            version: ImportBatchDiff.currentVersion + 1, fileName: "f.csv", entity: .title,
            createdTitleIDs: [], createdReferenceIDs: [], completions: [])
        let data = try JSONEncoder().encode(future)

        #expect(throws: ImportBatchDiffError.unsupportedVersion(ImportBatchDiff.currentVersion + 1)) {
            try ImportBatchDiff.decoded(from: data)
        }
        // Bornée des deux côtés : une version 0 vient d'un payload tronqué.
        let zero = try JSONEncoder().encode(
            ImportBatchDiff(
                version: 0, fileName: "f.csv", entity: .title, createdTitleIDs: [],
                createdReferenceIDs: [], completions: []))
        #expect(throws: ImportBatchDiffError.unsupportedVersion(0)) {
            try ImportBatchDiff.decoded(from: zero)
        }
    }
}

// MARK: - L'annulation

/// Un porte-tâche partagé entre le test et la fermeture de progression.
///
/// **C'est ce qui rend l'annulation déterministe.** Annuler après un `Task.sleep` dépend de la
/// vitesse de la machine : sur un portable rapide, l'annulation arrivait *avant* le premier lot,
/// donc zéro titre écrit — et `0` étant un multiple de 200, l'assertion « s'arrête à une
/// frontière de lot » passait sans rien vérifier. Le test était vert et creux, exactement ce que
/// `CLAUDE.md` reproche aux seuils de temps sur un runner partagé.
///
/// Ici la fermeture de progression est appelée par l'acteur **à la frontière du premier lot** :
/// annuler depuis elle place le point d'annulation à un endroit connu, sur n'importe quelle
/// machine.
final class TaskBox: @unchecked Sendable {
    private let mutex = NSLock()
    private var task: Task<ImportRunResult, Error>?
    private var cancellations = 0

    func hold(_ task: Task<ImportRunResult, Error>) {
        mutex.withLock { self.task = task }
    }

    /// Annule à la première invocation seulement.
    func cancelOnce() {
        mutex.withLock {
            guard cancellations == 0 else { return }
            cancellations += 1
            task?.cancel()
        }
    }
}

@MainActor
struct ImportCancellationTests {

    /// Assez de lignes pour dépasser plusieurs lots.
    ///
    /// **Aucun budget de temps n'est assené ici** : les assertions portent sur des *relations* —
    /// annulé, partiel, cohérent, exactement un lot — et non sur une durée.
    private static let rowCount = 1_000

    /// Lance un import annulé à la frontière du premier lot.
    private func runCancelledAtFirstBatch(
        _ fixture: ImportRunFixture
    ) async throws -> ImportRunResult {
        let rows = importRows(
            header: ["Titre", "Année"],
            rows: (1...Self.rowCount).map { ["Titre \($0)", "2000"] })
        let actor = fixture.actor
        let libraryID = fixture.library.id
        let box = TaskBox()

        let task = Task {
            try await actor.importRows(rows, fileName: "f.csv", libraryID: libraryID) { _ in
                box.cancelOnce()
            }
        }
        box.hold(task)
        return try await task.value
    }

    @Test("Une annulation en cours de route s'arrête à une frontière de lot")
    func cancellationStopsAtABatchBoundary() async throws {
        let fixture = try makeImportFixture()
        let result = try await runCancelledAtFirstBatch(fixture)

        #expect(result.wasCancelled)
        let stored = try fixture.titles().count
        // Exactement un lot : la progression est appelée après le premier `save()`, l'annulation
        // est vue au début de la ligne suivante.
        #expect(stored == ImportActor.batchSize)
        #expect(stored < Self.rowCount)
        // **Le bilan et le magasin s'accordent.** C'est l'assertion que la première version du
        // code échouait : elle découpait une liste de titres avec un compte de lignes.
        #expect(result.createdTitleIDs.count == stored)
    }

    @Test("Le journal d'un import interrompu dit qu'il l'a été, et compte juste")
    func cancelledImportJournalsWhatItWrote() async throws {
        let fixture = try makeImportFixture()
        let result = try await runCancelledAtFirstBatch(fixture)
        try #require(result.wasCancelled)

        let entry = try #require(try fixture.batchEntries().first)
        #expect(entry.summary.contains("interrompu"))
        let diff = try ImportBatchDiff.decoded(from: try #require(entry.payload))
        let stored = try fixture.titles().count
        #expect(diff.createdTitleIDs.count == stored)
    }

    @Test("Annuler avant le premier lot n'écrit rien du tout")
    func cancellingImmediatelyWritesNothing() async throws {
        let fixture = try makeImportFixture()
        let rows = importRows(
            header: ["Titre", "Année"], rows: (1...400).map { ["T\($0)", "2000"] })
        let actor = fixture.actor
        let libraryID = fixture.library.id

        let task = Task { try await actor.importRows(rows, fileName: "f.csv", libraryID: libraryID) }
        task.cancel()
        let result = try await task.value

        #expect(result.wasCancelled)
        #expect(result.createdTitleIDs.isEmpty)
        #expect(try fixture.titles().isEmpty)
        #expect(try fixture.batchEntries().isEmpty)
    }

    @Test("Deux imports simultanés : le second est refusé, pas entrelacé")
    func concurrentImportsAreRefused() async throws {
        // La contrepartie d'avoir rendu la méthode asynchrone : un acteur est réentrant, donc
        // pendant un `await Task.yield()` un second import pourrait s'exécuter entre deux lots
        // du premier. Les deux partageraient le `ModelContext`, et le `rollback()` de l'un
        // jetterait le lot en cours de l'autre — deux bilans plausibles et faux.
        let fixture = try makeImportFixture()
        let first = importRows(header: ["Titre", "Année"], rows: (1...400).map { ["A\($0)", "2000"] })
        let second = importRows(header: ["Titre", "Année"], rows: (1...400).map { ["B\($0)", "2001"] })
        let actor = fixture.actor
        // L'identifiant est extrait **avant** : une `Library` est un `@Model`, donc non
        // `Sendable`, et elle ne peut pas sortir du fil principal. C'est la contrainte même qui
        // fait que `importRows` prend un `UUID`.
        let libraryID = fixture.library.id

        let one = Task { try await actor.importRows(first, fileName: "a.csv", libraryID: libraryID) }
        let two = Task { try await actor.importRows(second, fileName: "b.csv", libraryID: libraryID) }

        var refused = 0
        var succeeded = 0
        for task in [one, two] {
            do {
                _ = try await task.value
                succeeded += 1
            } catch ImportRunError.alreadyRunning {
                refused += 1
            }
        }
        #expect(succeeded == 1)
        #expect(refused == 1)
        #expect(try fixture.titles().count == 400, "un seul des deux fichiers est entré")
    }

    @Test("Le verrou se relâche après une annulation")
    func lockIsReleasedAfterCancellation() async throws {
        let fixture = try makeImportFixture()
        _ = try await runCancelledAtFirstBatch(fixture)
        let actor = fixture.actor
        let libraryID = fixture.library.id

        // Un verrou qui resterait pris interdirait tout import jusqu'au redémarrage de l'app.
        let next = try await actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Après", "1999"]]),
            fileName: "s.csv", libraryID: libraryID)
        #expect(next.createdTitleIDs.count == 1)
    }
}
