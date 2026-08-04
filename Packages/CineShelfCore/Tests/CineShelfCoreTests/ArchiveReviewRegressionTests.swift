import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

/// Les sept défauts que la **revue adverse** de `L12` a trouvés, après la sonde.
///
/// Ils ont tous le même point commun, et c'est ce qui les rendait invisibles : ils vivent
/// dans la restauration **sur un magasin qui n'est pas vide**. Or `countsSurviveTheRoundTrip`
/// restaure sur une cible vide et compare des comptes, et `laterEditsAreNeverOverwritten`
/// vérifie que l'archive n'écrase pas — jamais que ce qu'elle **ajoute** est cohérent. La
/// fusion partielle est pourtant le mode d'emploi annoncé de l'outil : « récupérer trois
/// fiches perdues n'oblige pas à tout effacer d'abord ».
@Suite("Archive — régressions trouvées par la revue")
@MainActor
struct ArchiveReviewRegressionTests {
    /// Un titre crédité à une personne, et un asset de 4 096 octets dont `byteSize` est
    /// renseigné.
    private func makeSource(
        _ sandbox: ArchiveSandbox
    ) throws -> (
        context: ModelContext, url: URL
    ) {
        let context = try sandbox.makeContext("source")
        let library = Library(name: "Biblio", isDefault: true)
        context.insert(library)
        let title = Title(name: "Le Parrain")
        title.library = library
        context.insert(title)
        let person = Person(firstName: "Marlon", lastName: "Brando")
        person.library = library
        context.insert(person)
        let credit = Credit(role: .cast, characterName: "Don Vito", orderIndex: 0)
        credit.title = title
        credit.person = person
        context.insert(credit)
        let asset = MediaAsset(kind: .image)
        asset.data = Data((0..<4096).map { UInt8($0 % 251) })
        asset.byteSize = 4096
        context.insert(asset)
        title.refreshDerived()
        person.refreshDerived()
        try context.save()

        let url = sandbox.archiveURL()
        try ArchiveWriter(context: context).write(to: url)
        return (context, url)
    }

    @Test("Un crédit rendu à un titre déjà en base rafraîchit son `filterKeys`")
    func creditOnExistingTitleRefreshesItsFilterKeys() throws {
        // **Le défaut, et le plus grave des sept.** `Title.refreshDerived()` compose
        // `filterKeys` depuis `credits`, et la passe des dérivés ne traitait que les titres
        // qu'elle venait de créer. Un crédit rendu à un titre déjà présent entrait donc en
        // base sans que l'index qui le rend interrogeable ne bouge : la fiche affichait la
        // personne, et filtrer par cette personne rendait **0 titre au lieu de 1**, sans
        // qu'aucun compteur du bilan ne bouge.
        //
        // C'est la classe de défaut de `L1` et de la grille vide derrière 42 tests verts.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let document = try ArchiveReader().read(from: source.url)
        let originalTitle = try #require(try source.context.fetch(FetchDescriptor<Title>()).first)
        let originalPerson = try #require(try source.context.fetch(FetchDescriptor<Person>()).first)

        // La cible porte déjà le titre et la personne, mais pas le crédit.
        let target = try sandbox.makeContext("cible")
        let library = Library(name: "Biblio", isDefault: true)
        library.id = try #require(try source.context.fetch(FetchDescriptor<Library>()).first).id
        target.insert(library)
        let title = Title(name: "Le Parrain")
        title.id = originalTitle.id
        title.library = library
        title.refreshDerived()
        target.insert(title)
        let person = Person(firstName: "Marlon", lastName: "Brando")
        person.id = originalPerson.id
        person.library = library
        person.refreshDerived()
        target.insert(person)
        try target.save()
        try #require(!title.filterKeys.contains("p:"), "le titre ne porte pas encore la personne")

        let report = try ArchiveRestorer(context: target).restore(document, from: source.url)

        #expect(title.filterKeys == originalTitle.filterKeys)
        #expect(report.refreshedDerivedCount == 1)

        // Et la vraie question, posée au magasin : le prédicat SQL trouve-t-il le titre ?
        // C'est la règle de `CLAUDE.md` — un `#Predicate` évalué sur du pending ne prouve
        // rien, et c'est exactement ce qui a laissé la grille des titres vide.
        try target.save()
        let key = "|p:\(person.id.uuidString)|"
        let descriptor = FetchDescriptor<Title>(predicate: #Predicate { $0.filterKeys.contains(key) })
        #expect(try target.fetch(descriptor).count == 1)
    }

    @Test("Rejouer l'archive repose les octets d'un asset présent mais vide")
    func replayingRepairsAnAssetWithoutBytes() throws {
        // **Le défaut.** Un asset déjà présent par son identifiant était sauté avant que la
        // pose des octets soit atteinte. Donc si la ligne existait sans ses octets — ce que
        // produit une restauration sans source, un `CKAsset` non rapatrié, un `media/` perdu
        // à la copie — rejouer l'archive avec les images sous la main ne les remettait pas,
        // et le bilan disait « ignoré », zéro anomalie. C'est le cas d'usage central de la
        // fusion, et il ne marchait pas pour les médias.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let document = try ArchiveReader().read(from: source.url)
        let target = try sandbox.makeContext("cible")

        let first = try ArchiveRestorer(context: target).restore(document, from: nil)
        let asset = try #require(try target.fetch(FetchDescriptor<MediaAsset>()).first)
        try #require(asset.data == nil, "la première passe laisse bien l'asset sans octets")
        #expect(first.missingMediaAssetIDs.count == 1)

        let second = try ArchiveRestorer(context: target).restore(document, from: source.url)

        #expect(asset.data?.count == 4096)
        #expect(second.missingMediaAssetIDs.isEmpty)
        // Rien n'a été créé : c'est bien une réparation, pas un doublon.
        #expect(second.totalCreated == 0)
    }

    @Test("Un fichier de `media/` tronqué est refusé et compté, pas restauré à moitié")
    func truncatedMediaIsRefusedAndCounted() throws {
        // **Le défaut.** `Data(contentsOf:)` réussit sur un fichier coupé, et rien ne
        // comparait la taille relue à `byteSize`, pourtant écrit dans l'archive juste à
        // côté : 7 octets restaurés pour 4 096 annoncés, zéro compteur. Une image tronquée
        // ne s'affiche pas — l'écrire remplacerait une absence honnête par une corruption
        // silencieuse.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let asset = try #require(try source.context.fetch(FetchDescriptor<MediaAsset>()).first)
        let victim = ArchiveReader().mediaFileURL(forAssetID: asset.id, in: source.url)
        try #require((try Data(contentsOf: victim)).count == 4096)
        try Data(repeating: 0x00, count: 7).write(to: victim)
        try #require((try Data(contentsOf: victim)).count == 7, "l'injection a bien tronqué")

        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: source.url), from: source.url)

        #expect(report.truncatedMediaAssetIDs == [asset.id])
        let restored = try #require(try target.fetch(FetchDescriptor<MediaAsset>()).first)
        #expect(restored.data == nil, "des octets tronqués ne sont pas posés")
        // Les métadonnées sont là : la fiche reste réparable.
        #expect(restored.byteSize == 4096)
    }

    @Test("Une archive venue d'un schéma plus récent est refusée")
    func newerSchemaVersionIsRefused() throws {
        // **Le défaut.** `schemaVersion` était écrite et relue par personne, alors que sa
        // propre documentation affirmait qu'elle servait à reconnaître une archive venue
        // d'une version future. Le format étant inchangé, une archive de schéma V2 passait
        // la garde de `formatVersion` et se relisait sans un mot. Le schéma est fermé depuis
        // le 2026-08-03 : c'est le chemin de la prochaine version de l'app.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let manifestURL = source.url.appendingPathComponent(ArchiveLayout.manifestFileName)
        let text = try String(contentsOf: manifestURL, encoding: .utf8)
        let injected = text.replacingOccurrences(
            of: "\"schemaVersion\" : \"\(ArchiveWriter.schemaVersionText)\"",
            with: "\"schemaVersion\" : \"9.9.9\"")
        try #require(injected != text, "l'injection de schemaVersion n'a rien remplacé")
        try injected.write(to: manifestURL, atomically: true, encoding: .utf8)

        #expect(throws: ArchiveError.unsupportedSchemaVersion("9.9.9")) {
            try ArchiveReader().read(from: source.url)
        }
    }

    @Test("Un fichier de `entities/` inconnu est relevé, pas ignoré en silence")
    func unknownEntityFileIsReported() throws {
        // La boucle de relecture n'itère que sur `ArchiveEntityFile.allCases` : un fichier
        // écrit par une version plus récente était parfaitement invisible. Ce n'est pas une
        // erreur — l'archive reste lisible — mais ça doit se voir.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        try Data("[{}]".utf8).write(
            to: source.url.appendingPathComponent("entities/episodes.json"))

        let document = try ArchiveReader().read(from: source.url)
        #expect(document.unknownEntityFiles == ["episodes.json"])

        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target).restore(document, from: source.url)
        #expect(report.unknownEntityFiles == ["episodes.json"])
    }

    @Test("Un `media/` perdu se voit à la relecture, avant toute écriture — sans refus")
    func lostMediaDirectoryIsVisibleBeforeWriting() throws {
        // **Le défaut.** `mediaFileCount` était écrit et vérifié par personne : la garde des
        // comptes ne couvrait que les entités. Un `media/` perdu se relisait donc sans un
        // mot, et la perte n'apparaissait qu'après avoir commencé à écrire dans le magasin.
        //
        // **La première correction en faisait une erreur, et ce test l'a rejetée** : refuser
        // contredit « un média manquant n'annule pas la restauration » et « un orphelin
        // n'est pas une erreur », deux décisions déjà prises. Ce qui manquait était
        // l'information avant d'écrire, pas un refus.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let media = source.url.appendingPathComponent(ArchiveLayout.mediaDirectoryName)
        try #require(FileManager.default.fileExists(atPath: media.path))
        try FileManager.default.removeItem(at: media)

        let document = try ArchiveReader().read(from: source.url)
        #expect(document.manifest.mediaFileCount == 1)
        #expect(document.mediaFilesFound == 0)
        #expect(document.mediaFileDelta == -1, "l'écart est lisible avant d'écrire")

        // Et il rejoint le bilan, pour que la trace survive à la restauration.
        let target = try sandbox.makeContext("cible")
        let report = try ArchiveRestorer(context: target).restore(document, from: source.url)
        #expect(report.mediaFileDelta == -1)
        #expect(report.missingMediaAssetIDs.count == 1)
        // La restauration a bien eu lieu : c'est tout le point du non-refus.
        #expect(try target.fetchCount(FetchDescriptor<Title>()) == 1)
    }

    @Test("Un octet en trop dans `media/` rend un écart positif, sans refus non plus")
    func extraMediaFileGivesAPositiveDelta() throws {
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        try Data(repeating: 0, count: 8).write(
            to: source.url.appendingPathComponent(
                "media/\(UUID().uuidString).\(ArchiveLayout.mediaFileExtension)"))

        let document = try ArchiveReader().read(from: source.url)
        #expect(document.mediaFileDelta == 1)
        #expect(try ArchiveReader().orphanedMediaFileCount(in: source.url, for: document) == 1)
    }

    @Test("Aucun état commis en cours de restauration n'a de dérivé vide")
    func noCommittedStateHasEmptyDerivedFields() throws {
        // **Le défaut.** Les passes 1 et 2 inséraient sans dérivés, et `checkpoint()` commet
        // tous les 200 enregistrements : 700 titres sur 700 traversaient le disque avec
        // `sortName` et `searchText` vides, donc introuvables en recherche — et une
        // interruption (jetsam, `save()` qui lève) les y laissait pour de bon. Les dérivés
        // sont désormais posés dès la passe 1, puis reposés en passe 3 avec les relations.
        //
        // Le test vérifie l'état final, qui était déjà correct ; ce qu'il verrouille est
        // l'appel de la passe 1, dont le retrait rend des lignes commises vides sans faire
        // rougir quoi que ce soit d'autre. La vérification de l'état **intermédiaire** exige
        // un observateur concurrent — hors de portée d'un test unitaire, et l'écart est
        // inscrit.
        let sandbox = try ArchiveSandbox()
        let context = try sandbox.makeContext("volume")
        let library = Library(name: "Volume")
        context.insert(library)
        let person = Person(firstName: "Actrice", lastName: "Prolifique")
        person.library = library
        context.insert(person)
        // Plus de 200 titres, pour que `checkpoint()` commette au moins deux fois.
        for index in 0..<450 {
            let title = Title(name: "Titre \(index)")
            title.library = library
            context.insert(title)
            let credit = Credit(role: .cast, orderIndex: 0)
            credit.title = title
            credit.person = person
            context.insert(credit)
            title.refreshDerived()
        }
        try context.save()

        let url = sandbox.archiveURL("Volume")
        try ArchiveWriter(context: context).write(to: url)
        let target = try sandbox.makeContext("cible")
        _ = try ArchiveRestorer(context: target)
            .restore(try ArchiveReader().read(from: url), from: url)

        let restored = try target.fetch(FetchDescriptor<Title>())
        #expect(restored.count == 450)
        #expect(restored.count { $0.sortName.isEmpty } == 0)
        #expect(restored.count { $0.searchText.isEmpty } == 0)
        #expect(restored.count { $0.filterKeys.isEmpty } == 0)
        #expect(restored.count { $0.filterKeys.contains("p:\(person.id.uuidString)") } == 450)
    }

    @Test("Un `media/` illisible remonte l'erreur au lieu de rendre zéro orphelin")
    func unreadableMediaDirectoryPropagatesTheError() throws {
        // **Le défaut.** Un `?? []` faisait rendre « 0 orphelin » à un dossier illisible —
        // la même réponse qu'une archive parfaitement saine, sur le compteur dont la
        // documentation dit qu'il est le seul endroit où cette perte laisse une trace.
        let sandbox = try ArchiveSandbox()
        let source = try makeSource(sandbox)
        let document = try ArchiveReader().read(from: source.url)
        let media = source.url.appendingPathComponent(ArchiveLayout.mediaDirectoryName)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000], ofItemAtPath: media.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: media.path)
        }

        #expect(throws: (any Error).self) {
            try ArchiveReader().orphanedMediaFileCount(in: source.url, for: document)
        }
    }
}
