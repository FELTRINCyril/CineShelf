import Foundation
import Testing

@testable import CineShelfCore

// Le diff est le contrat entre `L10`, qui l'écrit, et `L20`, qui le relira pour défaire
// un lot. Un diff mal encodé ne se voit pas au moment de l'écriture : il se voit le jour
// où quelqu'un annule, et à ce moment-là il est trop tard pour retrouver les valeurs.

struct BulkEditDiffTests {

    private func makeDiff(entries: [BulkEditDiff.Entry]) -> BulkEditDiff {
        BulkEditDiff(
            summary: "3 titres archivés", field: "isArchived", operation: .replace,
            entries: entries)
    }

    @Test("Un diff fait l'aller-retour sans rien perdre")
    func roundTrip() throws {
        let entry = BulkEditDiff.Entry(
            entityID: UUID(),
            entityType: .title,
            fields: [.init(field: "isArchived", before: "false", after: "true")],
            attached: [UUID()],
            detached: [UUID(), UUID()]
        )
        let diff = makeDiff(entries: [entry])

        let decoded = try BulkEditDiff.decoded(from: try diff.encoded())
        #expect(decoded == diff)
    }

    @Test("L'encodage est stable : deux diffs identiques donnent les mêmes octets")
    func encodingIsStable() throws {
        let entry = BulkEditDiff.Entry(
            entityID: UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)),
            entityType: .person,
            fields: [
                .init(field: "bio", before: nil, after: "Texte"),
                .init(field: "isPrivate", before: "false", after: "true")
            ]
        )
        let first = try makeDiff(entries: [entry]).encoded()
        let second = try makeDiff(entries: [entry]).encoded()
        #expect(first == second)
    }

    @Test("Une version inconnue est refusée, pas devinée")
    func unknownVersionIsRefused() throws {
        // Un diff écrit par une version future ne doit pas être interprété au petit
        // bonheur : une annulation qui se trompe est pire que pas d'annulation.
        let future = BulkEditDiff(
            version: BulkEditDiff.currentVersion + 1,
            summary: "…", field: "isArchived", operation: .replace, entries: [])
        let data = try future.encoded()

        #expect(throws: BulkEditDiffError.unsupportedVersion(BulkEditDiff.currentVersion + 1)) {
            try BulkEditDiff.decoded(from: data)
        }
    }

    @Test("`nil` avant et `nil` après ne sont pas la même chose qu'une absence de champ")
    func nilIsAValue() throws {
        // Vider un champ est une action, et l'annuler consiste à remettre la valeur
        // d'avant. Un `before` nul doit donc survivre à l'aller-retour, distinct d'un
        // champ qui n'apparaîtrait pas du tout.
        let entry = BulkEditDiff.Entry(
            entityID: UUID(), entityType: .title,
            fields: [.init(field: "rating", before: "4", after: nil)])
        let decoded = try BulkEditDiff.decoded(from: try makeDiff(entries: [entry]).encoded())

        let change = try #require(decoded.entries.first?.fields.first)
        #expect(change.before == "4")
        #expect(change.after == nil)
        #expect(change.isNoOp == false)
    }

    @Test("Un changement sans effet est reconnu comme tel")
    func noOpIsDetected() {
        #expect(BulkEditDiff.FieldChange(field: "x", before: "a", after: "a").isNoOp)
        #expect(BulkEditDiff.FieldChange(field: "x", before: nil, after: nil).isNoOp)
        #expect(BulkEditDiff.FieldChange(field: "x", before: nil, after: "a").isNoOp == false)
    }

    @Test("Les entités réellement touchées excluent les entrées vides")
    func touchedEntitiesSkipEmptyOnes() {
        let untouched = BulkEditDiff.Entry(entityID: UUID(), entityType: .title)
        let touched = BulkEditDiff.Entry(
            entityID: UUID(), entityType: .title,
            fields: [.init(field: "x", before: "a", after: "b")])
        let diff = makeDiff(entries: [untouched, touched])

        #expect(diff.entries.count == 2)
        #expect(diff.touchedEntityIDs == [touched.entityID])
    }

    // MARK: - Encodage des valeurs

    @Test("Un Double fait l'aller-retour au bit près")
    func doubleRoundTrip() {
        // `%.17g` plutôt qu'une conversion par défaut : une note venue d'un import peut
        // ne pas être un nombre rond, et une valeur tronquée à l'encodage rendrait
        // l'annulation approximative.
        for value in [0.0, 4.0, 3.5, 0.1, 1.0 / 3.0, 4.999_999_999_999_999] {
            let encoded = BulkValueCoding.encode(value)
            #expect(BulkValueCoding.decodeDouble(encoded) == value, "\(value)")
        }
    }

    @Test("Une date fait l'aller-retour à la seconde")
    func dateRoundTrip() throws {
        // Le format est en UTC et non localisé : sinon un diff écrit à Paris en juillet
        // ne se relit pas à l'identique en janvier.
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        let encoded = BulkValueCoding.encode(date)
        let decoded = try #require(BulkValueCoding.decodeDate(encoded))
        #expect(abs(decoded.timeIntervalSince(date)) < 1)
        #expect(try #require(encoded).hasSuffix("Z"), "Doit être en UTC")
    }

    @Test("Un booléen et un entier font l'aller-retour")
    func scalarsRoundTrip() {
        #expect(BulkValueCoding.decodeBool(BulkValueCoding.encode(true)) == true)
        #expect(BulkValueCoding.decodeBool(BulkValueCoding.encode(false)) == false)
        #expect(BulkValueCoding.decodeInt(BulkValueCoding.encode(155)) == 155)
        #expect(BulkValueCoding.encode(nil as Int?) == nil)
        #expect(BulkValueCoding.decodeInt(nil) == nil)
    }

    @Test("Une valeur illisible rend nil plutôt qu'une valeur fausse")
    func malformedValuesDecodeToNil() {
        // Un diff corrompu doit se signaler par une absence, pas par un zéro plausible.
        #expect(BulkValueCoding.decodeInt("pas un nombre") == nil)
        #expect(BulkValueCoding.decodeDouble("pas un nombre") == nil)
        #expect(BulkValueCoding.decodeBool("peut-être") == nil)
        #expect(BulkValueCoding.decodeDate("hier") == nil)
    }

    @Test("Une liste de valeurs est triée, donc comparable")
    func stringListIsSorted() {
        // Les rôles d'une personne sont un ensemble : sans tri, deux diffs identiques
        // auraient des octets différents selon l'ordre d'itération.
        #expect(BulkValueCoding.encode(["director", "actor"]) == "actor,director")
        #expect(BulkValueCoding.decodeStringList("actor,director") == ["actor", "director"])
        #expect(BulkValueCoding.decodeStringList(nil).isEmpty)
        #expect(BulkValueCoding.decodeStringList("").isEmpty)
    }
}
