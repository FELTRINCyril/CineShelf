import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

/// Ce qu'une archive abîmée doit produire : un refus **nommé**, jamais un catalogue partiel
/// qui a l'air complet.
///
/// Chaque cas abîme une copie d'une archive valide, et **vérifie d'abord que l'injection a
/// eu lieu** — c'est la règle de `CLAUDE.md` : un rouge attendu ressemble à un succès, et
/// trois fois déjà une preuve d'échec s'est appuyée sur une faute qui n'était pas là.
@Suite("Archive — intégrité")
@MainActor
struct ArchiveIntegrityTests {
    /// Une archive valide, et une copie prête à être abîmée.
    private func makeCopy(_ sandbox: ArchiveSandbox, _ name: String) throws -> URL {
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source-\(name)"))
        let origin = sandbox.archiveURL("Origine-\(name)")
        try ArchiveWriter(context: fixture.context).write(to: origin)
        let copy = sandbox.archiveURL(name)
        try FileManager.default.copyItem(at: origin, to: copy)
        return copy
    }

    /// Remplace du texte dans un fichier de l'archive, et **échoue si rien n'a changé**.
    private func substitute(
        _ old: String, with new: String, in file: String, of archive: URL
    ) throws {
        let url = archive.appendingPathComponent(file)
        let text = try String(contentsOf: url, encoding: .utf8)
        let replaced = text.replacingOccurrences(of: old, with: new)
        try #require(replaced != text, "l'injection dans \(file) n'a rien remplacé")
        try replaced.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("Un manifeste absent : ce dossier n'est pas une archive")
    func missingManifestIsRefused() throws {
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "SansManifeste")
        let manifest = copy.appendingPathComponent(ArchiveLayout.manifestFileName)
        try #require(FileManager.default.fileExists(atPath: manifest.path))
        try FileManager.default.removeItem(at: manifest)

        #expect(throws: ArchiveError.missingManifest) {
            try ArchiveReader().read(from: copy)
        }
    }

    @Test("Une version de format inconnue est refusée, pas relue au mieux")
    func unknownFormatVersionIsRefused() throws {
        // Même refus explicite que `BulkEditDiff.decoded(from:)`. Une archive écrite par
        // une version future peut avoir déplacé les médias ou renommé un champ : la lire
        // « au mieux » rendrait un catalogue partiel qui a l'air complet.
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "VersionFuture")
        try substitute(
            "\"formatVersion\" : 1", with: "\"formatVersion\" : 2",
            in: ArchiveLayout.manifestFileName, of: copy)

        #expect(throws: ArchiveError.unsupportedFormatVersion(2)) {
            try ArchiveReader().read(from: copy)
        }
    }

    @Test("Un fichier d'entité absent est nommé")
    func missingEntityFileIsNamed() throws {
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "EntiteAbsente")
        let file = copy.appendingPathComponent("entities/\(ArchiveEntityFile.collections.fileName)")
        try #require(FileManager.default.fileExists(atPath: file.path))
        try FileManager.default.removeItem(at: file)

        #expect(throws: ArchiveError.missingEntityFile("collections.json")) {
            try ArchiveReader().read(from: copy)
        }
    }

    @Test("Un fichier d'entité illisible est nommé")
    func malformedEntityFileIsNamed() throws {
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "EntiteIllisible")
        try Data("ceci n'est pas du JSON".utf8)
            .write(to: copy.appendingPathComponent("entities/genres.json"))

        #expect(throws: ArchiveError.malformedEntityFile("genres.json")) {
            try ArchiveReader().read(from: copy)
        }
    }

    @Test("Un compte annoncé que le fichier ne tient pas est refusé, avec l'écart chiffré")
    func countMismatchIsRefusedWithNumbers() throws {
        // C'est la garde qui distingue « ce catalogue n'a pas de collections » de « le
        // fichier des collections a été perdu ». Sans elle, une archive dont un fichier a
        // été vidé se restaure en silence, amputée.
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "CompteFaux")
        try Data("[]".utf8).write(to: copy.appendingPathComponent("entities/genres.json"))

        #expect(throws: ArchiveError.countMismatch(entity: "genres", announced: 1, found: 0)) {
            try ArchiveReader().read(from: copy)
        }
    }

    @Test("Une date illisible est refusée, et la chaîne fautive est rendue")
    func malformedDateIsRefused() throws {
        let sandbox = try ArchiveSandbox()
        let copy = try makeCopy(sandbox, "DateIllisible")
        try substitute("T", with: " ", in: "entities/libraries.json", of: copy)

        // Le message porte la chaîne : sans elle, « date illisible » sur un fichier de
        // trois mille lignes n'aide personne à trouver laquelle.
        var raised: ArchiveError?
        do {
            _ = try ArchiveReader().read(from: copy)
        } catch let error as ArchiveError {
            raised = error
        }
        guard case .malformedDate(let text) = try #require(raised) else {
            Issue.record("erreur inattendue : \(String(describing: raised))")
            return
        }
        #expect(!text.isEmpty)
        #expect(!text.contains("T"))
    }

    @Test("Un média annoncé mais absent est compté, et n'annule pas la restauration")
    func missingMediaIsCountedNotFatal() throws {
        // Refuser l'archive entière ferait perdre neuf cent quatre-vingt-dix-neuf affiches
        // pour une absente, alors que l'asset sans image reste réparable.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let victim = url.appendingPathComponent(
            "media/\(fixture.assetWithBytes.id.uuidString).\(ArchiveLayout.mediaFileExtension)")
        try #require(FileManager.default.fileExists(atPath: victim.path))
        try FileManager.default.removeItem(at: victim)

        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        #expect(report.missingMediaAssetIDs == [fixture.assetWithBytes.id])
        #expect(try target.fetchCount(FetchDescriptor<Title>()) == 4)
        let restored = try #require(
            try target.fetch(FetchDescriptor<MediaAsset>())
                .first { $0.id == fixture.assetWithBytes.id })
        #expect(restored.data == nil)
        // Les métadonnées, elles, sont là : la fiche est réparable.
        #expect(restored.pixelWidth == 800)
        #expect(restored.checksum == "abc123")
    }

    @Test("Des octets en trop dans `media/` sont comptés")
    func orphanedMediaFilesAreCounted() throws {
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)
        try Data(repeating: 0, count: 8).write(
            to: url.appendingPathComponent(
                "media/\(UUID().uuidString).\(ArchiveLayout.mediaFileExtension)"))

        let document = try ArchiveReader().read(from: url)
        #expect(try ArchiveReader().orphanedMediaFileCount(in: url, for: document) == 1)
    }

    @Test("Une référence vers un identifiant inconnu est comptée, pas avalée")
    func danglingReferencesAreCounted() throws {
        // Une référence pendante rendue silencieusement nulle donne un catalogue qui
        // s'affiche sans erreur, avec des titres sans bibliothèque : exactement la forme
        // de perte qu'une sauvegarde doit empêcher.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let ghost = UUID().uuidString
        try substitute(
            fixture.library.id.uuidString, with: ghost, in: "entities/titles.json", of: url)

        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        #expect(report.danglingReferenceCount == 4, "un par titre")
        // Les titres sont créés quand même, et leur `filterKeys` reflète l'absence.
        #expect(try target.fetchCount(FetchDescriptor<Title>()) == 4)
        let orphan = try #require(
            try target.fetch(FetchDescriptor<Title>()).first { $0.id == fixture.futureTitle.id })
        #expect(orphan.library == nil)
    }

    @Test("Un rattachement à deux propriétaires est compté, pas corrigé")
    func attachmentWithTwoOwnersIsCounted() throws {
        // L'archive restitue ce qu'elle a trouvé — `L16` est la tâche qui nettoie. Mais
        // elle le **compte**, sinon l'invariant `hasExactlyOneOwner` se viole en silence.
        let sandbox = try ArchiveSandbox()
        let fixture = try ArchiveFixture(in: sandbox.makeContext("source"))
        let url = sandbox.archiveURL()
        try ArchiveWriter(context: fixture.context).write(to: url)

        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        #expect(report.invalidAttachmentCount == 1)
        let restored = try #require(
            try target.fetch(FetchDescriptor<MediaAttachment>())
                .first { $0.id == fixture.twoOwnerAttachment.id })
        #expect(!restored.hasExactlyOneOwner)
    }
}
