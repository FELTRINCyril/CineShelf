import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L20 · La fusion, dont le format doit rester capable
//
// **Sorti de `BulkEditUndoTests` pour la longueur**, et le découpage tombe juste : ce fichier
// pose une question différente. L'autre vérifie qu'une édition en masse se défait ; celui-ci
// vérifie que le **format** porte une opération qu'aucun code ne produit encore.
//
// **Ces tests n'existaient pas à la première livraison de `L20`, et c'est ce qui la rendait
// sous-exercée.** Les deux défauts qu'ils ont trouvés étaient invisibles sur toute édition en
// masse : la garde « entité à la corbeille » refusait le perdant d'une fusion — donc **aucune
// fusion n'était annulable** — et le nom de la relation venait du lot entier, où il vaut
// « merge », donc toutes les relations paraissaient avoir bougé.

@Suite("Annulation d'une fusion")
@MainActor
struct BulkEditUndoMergeTests {

    private struct Fixture {
        let context: ModelContext
        let library: Library
        let titles: [Title]
    }

    private func titles(_ count: Int) throws -> Fixture {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let made = (0..<count).map { index in
            repository.create(name: "Titre \(index)", in: library)
        }
        try context.save()
        return Fixture(context: context, library: library, titles: made)
    }

    private func applied(
        _ mutation: TitleBulkMutation, _ context: ModelContext, _ ids: [UUID]
    ) throws -> UUID {
        let outcome = try BulkEditor(isolatedContext: context)
            .apply(mutation, toTitles: ids, summary: "Lot de sonde")
        guard case .applied(_, let activityID) = outcome else {
            Issue.record("Le lot a été refusé : \(outcome)")
            return UUID()
        }
        return activityID
    }

    //
    // **`L8` est reportée en v1.1, donc aucun code ne produit encore de diff de fusion.** La
    // fiche exige malgré tout que le format en soit **capable** : « les deux opérations doivent
    // produire le même format de diff, sinon il y aura deux exécuteurs d'annulation », et la
    // conséquence 1 du report ajoute que le diff doit rester capable de porter une fusion sans
    // faire évoluer `currentVersion`. Ces tests posent la question à l'exécuteur.
    //
    // **Ils ont trouvé deux défauts, et aucun ne se voyait sur une édition en masse** — c'est
    // la réponse à « `L20` était-elle simple ou sous-exercée ». Elle était sous-exercée.

    /// Une fusion telle que `L8` la produira : le gagnant absorbe un champ et une relation du
    /// perdant, et le perdant part à la corbeille.
    private func mergeDiff(
        winner: Title, loser: Title, genre: Genre, absorbed: String, at moment: Date
    ) -> BulkEditDiff {
        BulkEditDiff(
            summary: "Fusion de « \(loser.name) » dans « \(winner.name) »",
            field: "merge",
            operation: .replace,
            entries: [
                .init(
                    entityID: winner.id, entityType: .title,
                    fields: [.init(field: "summary", before: nil, after: absorbed)],
                    relationField: "genres", attached: [genre.id], detached: []),
                .init(
                    entityID: loser.id, entityType: .title,
                    fields: [
                        .init(
                            field: "deletedAt", before: nil,
                            after: BulkValueCoding.encode(moment))
                    ])
            ])
    }

    @Test("Une fusion se défait par le même chemin, et sort le perdant de la corbeille")
    func mergeIsUndoable() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let library = fixture.library
        let winner = fixture.titles[0]
        let loser = fixture.titles[1]
        let polar = try GenreRepository(context: context).findOrCreate(name: "Polar", in: library)
        let repository = TitleRepository(context: context)
        repository.update(winner, journal: .batched) { $0.summary = nil }
        try context.save()

        // La fusion elle-même, jouée à la main faute d'exécuteur : le gagnant prend le synopsis
        // et le genre, le perdant part à la corbeille.
        let absorbed = "Le synopsis venu du perdant, assez long pour être reconnaissable."
        let moment = Date()
        repository.update(winner, journal: .batched) { $0.summary = absorbed }
        repository.setGenres([polar], on: winner, journal: .batched)
        repository.softDelete(loser)

        let entry = ActivityEntry.make(
            action: .merge, entityType: .title, entityID: UUID(), summary: "Fusion")
        entry.payload = try mergeDiff(
            winner: winner, loser: loser, genre: polar, absorbed: absorbed, at: moment
        ).encoded()
        context.insert(entry)
        try context.save()

        // **Le défaut le plus grave de `L20`, et invisible sur toute édition en masse** : la
        // garde « entité à la corbeille » refusait le perdant, donc aucune fusion n'était
        // annulable. Elle ne mord désormais que si le lot n'est pas ce qui l'a mis là.
        #expect(try BulkEditUndoer(context: context).undo(activityID: entry.id) == .undone(count: 2))
        #expect(winner.summary == nil)
        #expect((winner.genres ?? []).isEmpty)
        #expect(loser.deletedAt == nil, "le perdant doit sortir de la corbeille")
    }

    @Test("Une fusion refuse si le gagnant a été retouché depuis")
    func mergeRefusesOnLaterEdit() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let library = fixture.library
        let winner = fixture.titles[0]
        let loser = fixture.titles[1]
        let polar = try GenreRepository(context: context).findOrCreate(name: "Polar", in: library)
        let repository = TitleRepository(context: context)
        let absorbed = "Le synopsis venu du perdant."
        let moment = Date()
        repository.update(winner, journal: .batched) { $0.summary = absorbed }
        repository.setGenres([polar], on: winner, journal: .batched)
        repository.softDelete(loser)

        let entry = ActivityEntry.make(
            action: .merge, entityType: .title, entityID: UUID(), summary: "Fusion")
        entry.payload = try mergeDiff(
            winner: winner, loser: loser, genre: polar, absorbed: absorbed, at: moment
        ).encoded()
        context.insert(entry)
        // Quelqu'un réécrit le synopsis du gagnant après la fusion.
        repository.update(winner, journal: .batched) { $0.summary = "Un synopsis réécrit à la main." }
        try context.save()

        let outcome = try BulkEditUndoer(context: context).undo(activityID: entry.id)
        guard case .refused(let refusals) = outcome else {
            Issue.record("Attendu un refus, obtenu \(outcome)")
            return
        }
        #expect(refusals.contains { $0.entityID == winner.id })
        // **Tout ou rien** : le perdant reste à la corbeille, il n'est pas à moitié ressorti.
        #expect(loser.deletedAt != nil)
    }

    /// **La compatibilité des `payload` déjà écrits**, que l'ajout de `relationField` ne doit
    /// pas casser — c'est l'argument qui justifie de ne pas faire évoluer `currentVersion`.
    @Test("Un diff écrit sans relationField se relit et retombe sur le champ du lot")
    func payloadsWithoutRelationFieldStillDecode() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let library = fixture.library
        let made = fixture.titles
        let drame = try GenreRepository(context: context).findOrCreate(name: "Drame", in: library)
        try context.save()
        let activityID = try applied(.addGenres([drame.id]), context, made.map(\.id))

        // Le JSON tel qu'il est en base : la clé ne doit **pas** y figurer, sinon ce test ne
        // vérifie pas la compatibilité qu'il prétend vérifier.
        let entry = try #require(
            try context.fetch(FetchDescriptor<ActivityEntry>()).first { $0.id == activityID })
        let payload = try #require(entry.payload)
        let text = try #require(String(data: payload, encoding: .utf8))
        #expect(text.contains("relationField") == false)

        let diff = try BulkEditDiff.decoded(from: payload)
        #expect(diff.version == BulkEditDiff.currentVersion)
        #expect(diff.entries.allSatisfy { $0.relationField == nil })
        // Et l'annulation retombe sur `diff.field` — « genres » — donc elle fonctionne.
        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 2))
        #expect(made.allSatisfy { ($0.genres ?? []).isEmpty })
    }

}
