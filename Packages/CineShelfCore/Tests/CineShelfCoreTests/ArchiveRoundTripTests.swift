import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

/// L'aller-retour est **le** test de `L12` : « la même archive se réimporte et redonne les
/// mêmes comptes. C'est le test qui compte, pas le format » (`PROMPTS.md`, fiche `L12`).
@Suite("Archive — aller-retour")
@MainActor
struct ArchiveRoundTripTests {
    @Test("Écrire puis relire puis restaurer redonne exactement les mêmes comptes")
    func countsSurviveTheRoundTrip() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()

        try ArchiveWriter(context: fixture.context).write(to: url)
        let document = try ArchiveReader().read(from: url)
        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target).restore(document, from: url)

        #expect(try entityCounts(in: target) == (try entityCounts(in: fixture.context)))
    }

    @Test("Le manifeste annonce exactement ce que les fichiers contiennent")
    func manifestMatchesFiles() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()

        let manifest = try ArchiveWriter(context: fixture.context).write(to: url)
        let document = try ArchiveReader().read(from: url)

        // `read(from:)` lève déjà `countMismatch` si les deux divergent : le fait qu'il
        // n'ait pas levé est la moitié de la preuve. L'autre moitié est que les comptes
        // ne sont pas tous nuls, sans quoi le test passerait sur une archive vide.
        #expect(manifest.counts == document.counts)
        #expect(manifest.counts["titles"] == 4)
        #expect(manifest.mediaFileCount == 3)
    }

    @Test("Les dix-neuf entités du schéma ont chacune leur fichier")
    func everyEntityHasItsFile() throws {
        #expect(ArchiveEntityFile.allCases.count == CineShelfSchemaV1.models.count)
        #expect(ArchiveEntityFile.allCases.count == 19)
        #expect(Set(ArchiveEntityFile.allCases.map(\.fileName)).count == 19)
    }

    @Test("Aucun des dix-neuf fichiers n'est vide dans l'archive du fixture")
    func noEntityFileIsEmpty() throws {
        // Sans cette garde, l'aller-retour peut être vert en ne prouvant rien pour les
        // entités que le fixture ne peuple pas : zéro en entrée, zéro en sortie, égalité
        // satisfaite. C'est ce qui rend `countsSurviveTheRoundTrip` significatif.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)
        let document = try ArchiveReader().read(from: url)

        for file in ArchiveEntityFile.allCases {
            #expect(document.count(of: file) > 0, "\(file.rawValue) est vide dans le fixture")
        }
    }

    @Test("Les champs dérivés ne sont pas dans l'archive, ils sont recalculés")
    func derivedFieldsAreRecomputedNotTransported() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        // Absents du fichier…
        let json = try String(
            contentsOf: url.appendingPathComponent("entities/titles.json"), encoding: .utf8)
        #expect(!json.contains("sortName"))
        #expect(!json.contains("searchText"))
        #expect(!json.contains("filterKeys"))

        // …et pourtant identiques après restauration, parce que `filterKeys` dérive des
        // identifiants des relations, et que ceux-là sont préservés tels quels.
        let target = try sandbox.makeContext("cible")
        let document = try ArchiveReader().read(from: url)
        _ = try ArchiveRestorer(context: target).restore(document, from: url)

        let restored = try target.fetch(FetchDescriptor<Title>())
        for original in [fixture.plainTitle, fixture.nastyTitle, fixture.futureTitle] {
            let match = try #require(restored.first { $0.id == original.id })
            #expect(match.sortName == original.sortName)
            #expect(match.searchText == original.searchText)
            #expect(match.filterKeys == original.filterKeys)
            #expect(!match.filterKeys.isEmpty || original.filterKeys.isEmpty)
        }
    }

    @Test("`updatedAt` est celui de l'archive, pas celui de la restauration")
    func updatedAtIsRestoredNotStamped() throws {
        // `refreshDerived()` pose `updatedAt = .now`, et la passe des dérivés l'appelle :
        // sans réassignation ensuite, un catalogue restauré daterait entièrement du jour
        // de sa restauration, et « trié par date de modification » deviendrait faux
        // partout — sans qu'aucun test de compte ne le voie.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let target = try sandbox.makeContext("cible")
        let document = try ArchiveReader().read(from: url)
        _ = try ArchiveRestorer(context: target).restore(document, from: url)

        let restored = try #require(
            try target.fetch(FetchDescriptor<Title>()).first { $0.id == fixture.plainTitle.id })
        // Tolérance d'une milliseconde : les dates sont en ISO 8601 à trois décimales, un
        // arbitrage assumé de lisibilité contre fidélité (voir `ArchiveDate`). Rien dans le
        // modèle ne compare deux dates sous cette résolution.
        let drift = abs(restored.updatedAt.timeIntervalSince(fixture.plainTitle.updatedAt))
        #expect(drift < 0.001, "dérive de \(drift) s")
        #expect(abs(restored.createdAt.timeIntervalSince(fixture.plainTitle.createdAt)) < 0.001)
    }

    @Test("Deux archives du même catalogue sont identiques octet pour octet")
    func twoWritesAreByteIdentical() throws {
        // C'est ce qui rend une archive diffable, donc inspectable, donc digne de
        // confiance. Le tri des clés JSON et celui des identifiants de genres y pourvoient.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let first = sandbox.archiveURL("Un")
        let second = sandbox.archiveURL("Deux")

        try ArchiveWriter(context: fixture.context).write(to: first)
        try ArchiveWriter(context: fixture.context).write(to: second)

        for file in ArchiveEntityFile.allCases {
            let lhs = try Data(
                contentsOf: first.appendingPathComponent("entities/\(file.fileName)"))
            let rhs = try Data(
                contentsOf: second.appendingPathComponent("entities/\(file.fileName)"))
            #expect(lhs == rhs, "\(file.fileName) diffère entre deux écritures")
        }
    }

    @Test("Un `rawValue` d'énumération inconnu traverse l'archive sans être normalisé")
    func unknownRawValuesSurvive() throws {
        // Une sauvegarde conserve ce qu'elle trouve. Décoder en `TitleKind` remplacerait
        // par `.movie` un enregistrement écrit par une version future et rapatrié par
        // CloudKit — donc perdrait l'information au lieu de la garder.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let document = try ArchiveReader().read(from: url)
        let record = try #require(document.titles.first { $0.id == fixture.futureTitle.id })
        #expect(record.kindRaw == "miniseries-4k-hdr")
        #expect(record.releasePrecisionRaw == "decade")

        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target).restore(document, from: url)
        let restored = try #require(
            try target.fetch(FetchDescriptor<Title>()).first { $0.id == fixture.futureTitle.id })
        #expect(restored.kindRaw == "miniseries-4k-hdr")
        // Et la propriété calculée replie toujours, sans écraser le brut.
        #expect(restored.kind == .movie)
    }

    @Test("La corbeille est dans l'archive et en ressort en corbeille")
    func trashSurvives() throws {
        // Une sauvegarde qui perdrait `deletedAt` supprimerait définitivement, à la
        // restauration, ce que l'utilisateur avait seulement jeté.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        let restored = try #require(
            try target.fetch(FetchDescriptor<Title>()).first { $0.id == fixture.hiddenTitle.id })
        #expect(restored.deletedAt != nil)
        #expect(restored.isPrivate)
        #expect(restored.isArchived)
    }

    @Test("Le texte hostile traverse l'archive intact")
    func hostileTextSurvives() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let document = try ArchiveReader().read(from: url)
        let record = try #require(document.titles.first { $0.id == fixture.nastyTitle.id })
        #expect(record.name == fixture.nastyTitle.name)
        #expect(record.summary == fixture.nastyTitle.summary)
        #expect(record.originalName == fixture.nastyTitle.originalName)
    }

    @Test("Les inverses de relations sont reconstruits, y compris celui sans `@Relationship`")
    func inverseRelationshipsAreRebuilt() throws {
        // `Library.importMappings` est déclaré **sans** `@Relationship(inverse:)` — il
        // n'existe que pour que le miroir CloudKit accepte le schéma. Vérifier qu'il se
        // repeuple quand même est le seul moyen de savoir que la restauration n'a pas
        // besoin de l'écrire des deux côtés.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        let library = try #require(try target.fetch(FetchDescriptor<Library>()).first)
        #expect(library.titles?.count == 4)
        #expect(library.genres?.count == 1)
        #expect(library.importMappings?.count == 1)
        #expect(library.profiles?.count == 1)

        let genre = try #require(try target.fetch(FetchDescriptor<Genre>()).first)
        #expect(genre.titles?.count == 1)
        #expect(genre.people?.count == 1)
        #expect(genre.savedLinks?.count == 1)
    }

    @Test("Une base vide donne une archive lisible, et une restauration sans effet")
    func emptyStoreRoundTrips() throws {
        let sandbox = try ArchiveSandbox()
        let url = sandbox.archiveURL("Vide")
        let manifest = try ArchiveWriter(context: try sandbox.makeContext("vide")).write(to: url)
        #expect(manifest.counts.values.reduce(0, +) == 0)
        #expect(manifest.mediaFileCount == 0)

        let document = try ArchiveReader().read(from: url)
        let report = try ArchiveRestorer(context: try sandbox.makeContext("cible"))
            .restore(document, from: url)
        #expect(report.totalCreated == 0)
        #expect(report.totalSkipped == 0)
    }

    @Test("Réécrire par-dessus une archive existante la remplace, sans l'empiler")
    func writingOverAnExistingArchiveReplacesIt() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let extra = Title(name: "Ajouté après la première sauvegarde")
        extra.library = fixture.library
        extra.refreshDerived()
        fixture.context.insert(extra)
        try fixture.context.save()

        try ArchiveWriter(context: fixture.context).write(to: url)
        let document = try ArchiveReader().read(from: url)
        #expect(document.titles.count == 5)
        let files = try FileManager.default.contentsOfDirectory(
            atPath: url.appendingPathComponent("entities").path)
        #expect(files.count == 19)
    }
}
