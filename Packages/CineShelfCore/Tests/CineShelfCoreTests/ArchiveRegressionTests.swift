import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

/// Les défauts que la sonde de `L12` a trouvés, chacun avec son test.
///
/// Aucun n'était visible depuis la suite : tous les deux rendaient un bilan **plausible et
/// faux**, ce qui est précisément ce qu'une assertion écrite par l'auteur du code ne
/// regarde pas. C'est le troisième cas du dépôt, après le lecteur CSV et l'écriture
/// d'import, et le motif est chaque fois le même — la sonde imprime, le test assène.
@Suite("Archive — régressions trouvées par la sonde")
@MainActor
struct ArchiveRegressionTests {
    /// Le catalogue hostile, son archive écrite, et cette archive relue.
    private struct WrittenArchive {
        let fixture: ArchiveFixture
        let url: URL
        let document: ArchiveDocument
    }

    private func makeArchive(_ sandbox: ArchiveSandbox) throws -> WrittenArchive {
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)
        return WrittenArchive(fixture: fixture, url: url, document: try ArchiveReader().read(from: url))
    }

    @Test("Rejouer une archive ne crée rien, et compte TOUTES les entités ignorées")
    func replayingCountsEverySkippedEntity() throws {
        // **Le défaut.** Les douze entités de la passe 2 étaient sautées par un
        // `where !exists(…)`, qui ne note rien : le bilan disait « 0 créé, 15 ignoré » sur
        // une archive de 26 entités. Onze manquaient à l'appel, et le bilan laissait donc
        // croire qu'onze enregistrements avaient disparu — sur l'opération dont le seul
        // rôle est de rassurer sur ce qui est là.
        //
        // La garde est l'égalité avec le manifeste : elle ne peut pas être satisfaite en
        // oubliant un type, contrairement à un compte écrit en dur.
        let sandbox = try ArchiveSandbox()
        let archive = try makeArchive(sandbox)
        let target = try sandbox.makeContext("cible")

        let first = try ArchiveRestorer(context: target).restore(archive.document, from: archive.url)
        let second = try ArchiveRestorer(context: target)
            .restore(archive.document, from: archive.url)

        let announced = archive.document.manifest.counts.values.reduce(0, +)
        #expect(first.totalCreated == announced)
        #expect(second.totalCreated == 0)
        #expect(second.totalSkipped == announced)

        // Et type par type, pour que l'égalité des totaux ne puisse pas masquer une
        // compensation entre deux entités.
        for file in ArchiveEntityFile.allCases {
            let inArchive = archive.document.count(of: file)
            let counted = second.skipped[file.rawValue] ?? 0
            #expect(counted == inArchive, "\(file.rawValue) : \(inArchive) en archive, \(counted) compté ignoré")
        }
    }

    @Test("Restaurer sans source de médias signale les octets perdus")
    func restoringWithoutMediaSourceReportsTheLoss() throws {
        // **Le défaut.** `mediaSource: nil` était documenté comme un raccourci de test, et
        // le code ne comptait alors **rien** : la restauration rendait un catalogue complet
        // sans une seule image, en annonçant zéro anomalie. Du point de vue du résultat
        // c'est la même perte qu'un fichier absent, donc c'est le même compteur.
        let sandbox = try ArchiveSandbox()
        let archive = try makeArchive(sandbox)
        let target = try sandbox.makeContext("cible")

        let report = try ArchiveRestorer(context: target).restore(archive.document, from: nil)

        #expect(report.missingMediaAssetIDs.count == archive.document.manifest.mediaFileCount)
        #expect(report.missingMediaAssetIDs.count == 3)
        let restored = try #require(
            try target.fetch(FetchDescriptor<MediaAsset>())
                .first { $0.id == archive.fixture.assetWithBytes.id })
        #expect(restored.data == nil)
    }

    @Test("Deux assets sans checksum gardent chacun leurs octets")
    func assetsWithoutChecksumKeepTheirOwnBytes() throws {
        // Nommer les fichiers de `media/` par le `checksum` aurait écrit ces deux assets
        // dans le même fichier, et le second aurait écrasé le premier **sans qu'aucun
        // compte ne bouge** : deux assets en base, deux assets en archive, une seule image.
        // `checksum` vaut `""` sur tout asset dont personne ne l'a calculé, ce qui est le
        // cas de `DemoCatalog` — écart connu, donc pas un cas limite.
        let sandbox = try ArchiveSandbox()
        let archive = try makeArchive(sandbox)
        try #require(archive.fixture.assetNoChecksumA.checksum.isEmpty)
        try #require(archive.fixture.assetNoChecksumB.checksum.isEmpty)
        try #require(archive.fixture.assetNoChecksumA.data != archive.fixture.assetNoChecksumB.data)

        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target).restore(archive.document, from: archive.url)

        let restored = try target.fetch(FetchDescriptor<MediaAsset>())
        for original in [archive.fixture.assetNoChecksumA, archive.fixture.assetNoChecksumB] {
            let match = try #require(restored.first { $0.id == original.id })
            #expect(match.data == original.data)
        }
    }

    @Test("Une modification postérieure à la sauvegarde survit au rejeu de l'archive")
    func laterEditsAreNeverOverwritten() throws {
        // C'est la propriété qui rend la fusion par identifiant sûre sur une base qui n'est
        // pas vide : récupérer trois fiches perdues n'oblige pas à tout effacer d'abord.
        // Elle serait perdue le jour où quelqu'un « améliorerait » la restauration en lui
        // faisant mettre à jour les entités déjà là.
        let sandbox = try ArchiveSandbox()
        let archive = try makeArchive(sandbox)
        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target).restore(archive.document, from: archive.url)

        let edited = try #require(
            try target.fetch(FetchDescriptor<Title>())
                .first { $0.id == archive.fixture.plainTitle.id })
        edited.name = "TITRE MODIFIÉ APRÈS LA SAUVEGARDE"
        edited.rating = 1.0
        edited.refreshDerived()
        try target.save()

        _ = try ArchiveRestorer(context: target).restore(archive.document, from: archive.url)

        let after = try #require(
            try target.fetch(FetchDescriptor<Title>())
                .first { $0.id == archive.fixture.plainTitle.id })
        #expect(after.name == "TITRE MODIFIÉ APRÈS LA SAUVEGARDE")
        #expect(after.rating == 1.0, "9.5 signifierait que l'archive a écrasé")
    }
}
