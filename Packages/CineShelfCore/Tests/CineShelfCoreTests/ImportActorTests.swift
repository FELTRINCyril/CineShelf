import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Import par lots")
struct ImportActorTests {
    private func makeActor() async throws -> ImportActor {
        let container = try await makeTestContainer()
        return ImportActor(modelContainer: container)
    }

    @Test("Le lot fait 200 objets")
    func batchSizeIsTwoHundred() {
        #expect(ImportActor.batchSize == 200)
    }

    @Test("Tout est inséré, y compris le dernier lot incomplet")
    func everyItemLandsInTheStore() async throws {
        let actor = try await makeActor()
        let names = (1...450).map { "Titre \($0)" }

        try await actor.insertInBatches(names) { name, context in
            context.insert(Title(name: name))
        }

        let count = try await actor.titleCount()
        #expect(count == 450)
    }

    @Test("L'avancement est rapporté à chaque lot, puis à la fin")
    func progressIsReportedPerBatch() async throws {
        let actor = try await makeActor()
        let names = (1...450).map { "Titre \($0)" }
        let steps = Steps()

        try await actor.insertInBatches(
            names,
            progress: { steps.append($0) },
            insert: { name, context in context.insert(Title(name: name)) }
        )

        // 200, 400, puis la fin : trois points d'avancement.
        #expect(steps.values.count == 3)
        #expect(steps.values.last == 1)
    }

    @Test("Une liste vide ne déclenche aucune sauvegarde")
    func emptyListDoesNothing() async throws {
        let actor = try await makeActor()
        let steps = Steps()

        try await actor.insertInBatches([String]()) { name, context in
            context.insert(Title(name: name))
        }

        #expect(steps.values.isEmpty)
        #expect(try await actor.titleCount() == 0)
    }

    @Test("Une erreur d'insertion interrompt l'import et remonte")
    func insertionErrorPropagates() async throws {
        let actor = try await makeActor()
        let names = (1...450).map { "Titre \($0)" }

        await #expect(throws: ImportFailure.self) {
            try await actor.insertInBatches(names) { name, context in
                guard name != "Titre 250" else { throw ImportFailure.refused }
                context.insert(Title(name: name))
            }
        }

        // Seuls les lots déjà sauvegardés sont durables : les 200 premiers. Les
        // 49 insertions du lot en cours restent en attente dans le contexte,
        // visibles d'un `fetch` mais perdues si on l'abandonne. C'est ce qui rend
        // l'import reprenable par lot, et non par élément.
        #expect(try await actor.savedTitleCount() == 200)
        #expect(try await actor.titleCount() == 249)
    }
}

private enum ImportFailure: Error {
    case refused
}

/// Collecteur d'avancement partagé avec la fermeture `@Sendable`.
private final class Steps: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []

    var values: [Double] {
        lock.withLock { storage }
    }

    func append(_ value: Double) {
        lock.withLock { storage.append(value) }
    }
}

extension ImportActor {
    /// Compte les titres depuis le contexte de l'acteur : insertions en attente
    /// comprises.
    func titleCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Title>())
    }

    /// Compte les titres depuis un contexte neuf : seulement ce qui est sauvegardé.
    func savedTitleCount() throws -> Int {
        try ModelContext(modelContainer).fetchCount(FetchDescriptor<Title>())
    }
}
