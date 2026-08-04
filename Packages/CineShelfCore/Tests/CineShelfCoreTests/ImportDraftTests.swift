import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Le brouillon d'import, et l'indexation différée.
//
// Le brouillon est un **fichier** et non une entité : le schéma est fermé, et surtout il ne doit
// pas être synchronisé — il référence un fichier de *cet* appareil, et « un seul brouillon à la
// fois » est une notion d'appareil.

@MainActor
struct ImportDraftStoreTests {

    /// Un dossier neuf par test : ils écrivent pour de vrai, donc ils ne doivent pas se voir.
    private func makeStore() throws -> ImportDraftStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cineshelf-draft-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ImportDraftStore(directory: directory)
    }

    private func makeDraft(fileName: String = "collection.csv") -> ImportDraft {
        let document = CSVReader().read(
            csv(header: ["Titre", "Année"], rows: [["Dune", "20211"], ["Tenet", "2020"]]))
        let columns = ColumnMatcher(schema: .title).analyze(header: document.header, rows: document.rows)
        let analysis = ImportValidator(schema: .title).analyze(document: document, columns: columns)
        return ImportDraft(
            analysis: analysis,
            fileName: fileName,
            corrections: [ImportCorrection(fieldKey: "year", value: "2021", rowNumbers: [2])],
            savedAt: Date(timeIntervalSince1970: 1_000_000))
    }

    @Test("Un brouillon posé se relit à l'identique")
    func draftRoundTrips() throws {
        let store = try makeStore()
        let draft = makeDraft()
        try store.save(draft)

        #expect(try store.existingDraft() == draft)
    }

    @Test("Le brouillon porte les lignes, pas un chemin de fichier")
    func draftCarriesItsRows() throws {
        // Un chemin se périme : l'utilisateur déplace son fichier, vide ses téléchargements, ou
        // dépose depuis un dossier temporaire que le système nettoie. Reprendre un import dont le
        // fichier a disparu est l'échec le plus banal qu'on puisse s'épargner.
        let store = try makeStore()
        try store.save(makeDraft())
        let reread = try #require(try store.existingDraft())

        #expect(reread.rawRows.count == 2)
        #expect(reread.rawRows.first?.fields == ["Dune", "20211"])
        #expect(reread.rawRows.first?.number == 2, "le numéro du tableur, pas un rang")
        #expect(reread.header == ["Titre", "Année"])
        #expect(reread.corrections.count == 1)
    }

    @Test("Aucun brouillon rend nil, pas une erreur")
    func noDraftIsNotAnError() throws {
        #expect(try makeStore().existingDraft() == nil)
    }

    @Test("Poser un brouillon remplace le précédent : un seul à la fois")
    func savingReplacesThepreviousDraft() throws {
        let store = try makeStore()
        try store.save(makeDraft(fileName: "premier.csv"))
        try store.save(makeDraft(fileName: "second.csv"))

        // La contrainte de l'addendum est portée par le système de fichiers — un chemin fixe —
        // plutôt que par une vérification qu'on pourrait oublier.
        #expect(try store.existingDraft()?.fileName == "second.csv")
    }

    @Test("Abandonner supprime le brouillon")
    func discardRemovesTheDraft() throws {
        let store = try makeStore()
        try store.save(makeDraft())
        try store.discard()

        #expect(try store.existingDraft() == nil)
        // Abandonner deux fois n'est pas une erreur : l'utilisateur peut fermer deux fois.
        try store.discard()
    }

    @Test("Un brouillon d'une version postérieure est refusé, pas deviné")
    func futureVersionIsRefused() throws {
        let store = try makeStore()
        let draft = makeDraft()
        let future = ImportDraft(
            version: ImportDraft.currentVersion + 1,
            fileName: draft.fileName, entity: draft.entity, header: draft.header,
            rawRows: draft.rawRows, mapping: draft.mapping, corrections: draft.corrections,
            savedAt: draft.savedAt)
        try JSONEncoder().encode(future).write(to: store.url)

        // Un brouillon mal relu rejouerait des corrections dans les mauvaises colonnes.
        #expect(throws: ImportDraftError.unsupportedVersion(ImportDraft.currentVersion + 1)) {
            try store.existingDraft()
        }
    }

    @Test("Un brouillon illisible est traité comme absent")
    func corruptedDraftReadsAsNothing() throws {
        // Distinct d'un `payload` de journal, qui est de la donnée de l'utilisateur : un brouillon
        // est un état local reconstructible, et refuser d'ouvrir l'app pour un fichier abîmé
        // serait disproportionné.
        let store = try makeStore()
        try Data("pas du JSON".utf8).write(to: store.url)

        #expect(try store.existingDraft() == nil)
    }

    @Test("Les corrections se rejouent et redonnent l'état d'arrêt")
    func replayingCorrectionsRestoresTheState() throws {
        // C'est ce que « Reprendre » fait : le brouillon garde les décisions, pas leur résultat.
        // L'ordre compte — une correction peut en découvrir une autre — donc rejouer donne
        // exactement l'état où l'utilisateur s'est arrêté, y compris les refus qui restent.
        let store = try makeStore()
        try store.save(makeDraft())
        let draft = try #require(try store.existingDraft())

        let document = CSVReader().read(
            csv(header: draft.header, rows: draft.rawRows.map(\.fields)))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows, remembered: draft.mapping)
        let validator = ImportValidator(schema: .title)
        var analysis = validator.analyze(document: document, columns: columns)
        #expect(analysis.refusedRows.count == 1, "« 20211 » est hors bornes avant correction")

        for correction in draft.corrections {
            analysis = validator.applying(correction, to: analysis)
        }
        #expect(analysis.refusedRows.isEmpty)
        #expect(analysis.readyRows.count == 2)
    }
}

// MARK: - L'indexation différée

@MainActor
struct SpotlightBatchIndexerTests {

    @Test("Les titres importés entrent dans l'index")
    func importedTitlesAreIndexed() async throws {
        // **Le trou que cette passe ferme.** `ImportWriter` n'appelle pas l'indexeur — il ne peut
        // pas, il n'est pas sur le fil principal — mais « ne pas l'appeler » et « ne pas indexer »
        // sont deux choses différentes. Sans cette passe, 1 284 titres seraient absents de la
        // recherche système, en silence.
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", "2021"], ["Tenet", "2020"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let spy = RecordingSpotlightIndex()
        let indexed = try SpotlightBatchIndexer(
            context: fixture.freshContext(),
            indexer: SpotlightIndexer(index: spy)
        ).index(result)

        #expect(indexed == 2)
        #expect(spy.indexed.count == 2)
    }

    @Test("Un titre importé comme privé n'entre pas dans l'index")
    func privateImportedTitleStaysOut() async throws {
        // `sync(_:)` décide à partir de l'état courant, donc cette passe n'a pas à connaître la
        // règle. C'est ce qui la rend incapable de fuiter : l'index système est unique pour
        // l'appareil, il n'a pas de notion de profil.
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Privé"],
                rows: [["Public", "non"], ["Secret", "oui"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let spy = RecordingSpotlightIndex()
        _ = try SpotlightBatchIndexer(
            context: fixture.freshContext(),
            indexer: SpotlightIndexer(index: spy)
        ).index(result)

        #expect(spy.indexed.count == 1)
        #expect(spy.removed.count == 1, "le privé est explicitement retiré, pas seulement omis")
    }

    @Test("Un identifiant disparu entre l'import et l'indexation ne fait pas échouer la passe")
    func missingTitleIsSkipped() throws {
        let fixture = try makeImportFixture()
        let spy = RecordingSpotlightIndex()
        let indexed = try SpotlightBatchIndexer(
            context: fixture.freshContext(),
            indexer: SpotlightIndexer(index: spy)
        ).indexTitles(ids: [UUID(), UUID()])

        #expect(indexed == 0)
        #expect(spy.indexed.isEmpty)
    }

    @Test("Un lot plus grand que la taille de découpe est indexé entièrement")
    func largeBatchIsChunked() async throws {
        // `IN (...)` sur 1 284 valeurs est un prédicat que SQLite refuse de préparer au-delà d'un
        // certain nombre de paramètres : découper est la seule façon sûre.
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: (1...250).map { ["T\($0)", "2000"] }),
            fileName: "f.csv", libraryID: fixture.library.id)

        let spy = RecordingSpotlightIndex()
        let indexed = try SpotlightBatchIndexer(
            context: fixture.freshContext(),
            indexer: SpotlightIndexer(index: spy)
        ).indexTitles(ids: result.createdTitleIDs, chunkSize: 100)

        #expect(indexed == 250)
    }
}
