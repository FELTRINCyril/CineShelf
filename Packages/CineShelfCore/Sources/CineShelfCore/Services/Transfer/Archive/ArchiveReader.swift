import Foundation

/// Relit un paquet `.cineshelfarchive` et rend sa valeur en mémoire.
///
/// **Aucune écriture de modèle, aucun `ModelContext`.** Tout le travail de format se
/// teste donc sans conteneur SwiftData, et un défaut de relecture ne peut pas corrompre
/// un magasin en cours de route : `ArchiveRestorer` est le seul à écrire, et il ne
/// reçoit qu'une valeur déjà validée.
public struct ArchiveReader {
    public init() {}

    /// - Throws: `ArchiveError` — version inconnue, manifeste absent, fichier d'entité
    ///   manquant ou illisible, ou compte annoncé que le fichier ne tient pas.
    public func read(from url: URL) throws -> ArchiveDocument {
        let manager = FileManager.default
        let manifestURL = url.appendingPathComponent(ArchiveLayout.manifestFileName)
        guard manager.fileExists(atPath: manifestURL.path) else {
            throw ArchiveError.missingManifest
        }

        let decoder = ArchiveDate.decoder()
        let manifest: ArchiveManifest
        do {
            manifest = try decoder.decode(ArchiveManifest.self, from: Data(contentsOf: manifestURL))
        } catch let error as ArchiveError {
            throw error
        } catch {
            throw ArchiveError.malformedEntityFile(ArchiveLayout.manifestFileName)
        }

        // Les versions se vérifient **avant** de toucher au moindre fichier d'entité. Une
        // archive écrite par une version future peut avoir déplacé les médias ou renommé
        // un champ : la lire « au mieux » rendrait un catalogue partiel qui a l'air
        // complet. Même refus explicite que `BulkEditDiff.decoded(from:)`.
        guard manifest.formatVersion == ArchiveManifest.currentVersion else {
            throw ArchiveError.unsupportedFormatVersion(manifest.formatVersion)
        }
        // **Et la version du schéma, pas seulement celle du format.** Les deux bougent pour
        // des raisons différentes : le format change quand on écrit les médias autrement, le
        // schéma quand une entité gagne un champ. Une archive de schéma V2 a le même format,
        // donc passait la garde ci-dessus et se relisait sans un mot — mesuré par la revue :
        // acceptée, cinq entités restaurées, zéro anomalie, et le champ neuf perdu. Le
        // schéma étant fermé depuis le 2026-08-03, c'est le chemin de la **prochaine
        // version de l'app**, pas un cas d'école.
        guard manifest.schemaVersion <= ArchiveWriter.schemaVersionText else {
            throw ArchiveError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        var document = ArchiveDocument(manifest: manifest)
        let entities = url.appendingPathComponent(
            ArchiveLayout.entitiesDirectoryName, isDirectory: true)
        for file in ArchiveEntityFile.allCases {
            let fileURL = entities.appendingPathComponent(file.fileName)
            guard manager.fileExists(atPath: fileURL.path) else {
                throw ArchiveError.missingEntityFile(file.fileName)
            }
            // Distinguer « absent » de « illisible » : le premier est une archive amputée,
            // le second un problème de disque ou de permission. Les confondre — ce que
            // faisait un `try? Data(contentsOf:)` unique — donnait un refus nommé mais un
            // diagnostic faux, et on cherche alors le mauvais coupable.
            guard let bytes = try? Data(contentsOf: fileURL) else {
                throw ArchiveError.unreadableEntityFile(file.fileName)
            }
            try document.decodeEntities(for: file, from: bytes, using: decoder)
        }

        // Le manifeste dit ce que l'archive **prétend** contenir, les fichiers ce qu'elle
        // contient. Comparer les deux est la seule façon de distinguer « ce catalogue n'a
        // pas de collections » de « le fichier des collections a été perdu » — et c'est
        // exactement la confusion qui a laissé le lecteur CSV annoncer 7 lignes sur 15.
        for file in ArchiveEntityFile.allCases {
            let announced = manifest.counts[file.rawValue] ?? 0
            let found = document.count(of: file)
            guard announced == found else {
                throw ArchiveError.countMismatch(
                    entity: file.rawValue, announced: announced, found: found)
            }
        }

        // Les médias sont **relevés, pas assenés**, et la différence est un arbitrage, pas
        // une facilité. `mediaFileCount` était écrit et vérifié par personne : un `media/`
        // perdu se relisait sans un mot, et la perte n'apparaissait qu'après avoir commencé
        // à écrire dans le magasin.
        //
        // Mais en faire une erreur — première correction tentée, et rejetée par les tests —
        // contredit deux décisions déjà prises et documentées : « un média manquant n'annule
        // pas la restauration » (refuser l'archive entière ferait perdre neuf cent
        // quatre-vingt-dix-neuf affiches pour une absente) et « un orphelin n'est pas une
        // erreur ». Le trou à combler était l'**absence d'information avant d'écrire**, pas
        // l'absence de refus : `mediaFilesFound` la donne, et l'appelant décide.
        document.mediaFilesFound = try mediaFileNames(in: url).count

        // Un fichier de `entities/` que le format courant ne connaît pas n'est **pas** une
        // erreur — l'archive reste lisible — mais il se compte, sinon il est invisible.
        let known = Set(ArchiveEntityFile.allCases.map(\.fileName))
        document.unknownEntityFiles =
            ((try? FileManager.default.contentsOfDirectory(atPath: entities.path)) ?? [])
            .filter { $0.hasSuffix(".json") && !known.contains($0) }
            .sorted()
        return document
    }

    /// Les octets d'un asset, ou `nil` si l'archive n'en porte pas.
    public func mediaData(forAssetID id: UUID, in url: URL) -> Data? {
        try? Data(contentsOf: mediaFileURL(forAssetID: id, in: url))
    }

    func mediaFileURL(forAssetID id: UUID, in url: URL) -> URL {
        url
            .appendingPathComponent(ArchiveLayout.mediaDirectoryName, isDirectory: true)
            .appendingPathComponent("\(id.uuidString).\(ArchiveLayout.mediaFileExtension)")
    }

    /// Les noms des fichiers d'octets présents dans `media/`.
    ///
    /// - Throws: si le dossier n'est pas lisible. **Ne pas replier sur un tableau vide** :
    ///   un `media/` illisible rendait alors « 0 orphelin » et « 0 média attendu », soit la
    ///   même réponse qu'une archive parfaitement saine — sur le compteur dont la
    ///   documentation dit qu'il est le seul endroit où cette perte laisse une trace.
    func mediaFileNames(in url: URL) throws -> [String] {
        let media = url.appendingPathComponent(
            ArchiveLayout.mediaDirectoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: media.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: media.path)
            .filter { $0.hasSuffix(".\(ArchiveLayout.mediaFileExtension)") }
    }

    /// Les fichiers présents dans `media/` que **aucun** asset ne réclame.
    ///
    /// Ils ne sont pas une erreur — une archive reste lisible avec des octets en trop —
    /// mais ils se comptent : c'est le signe d'un asset perdu à l'écriture, et le seul
    /// endroit où cette perte laisse une trace.
    public func orphanedMediaFileCount(in url: URL, for document: ArchiveDocument) throws -> Int {
        let expected = Set(document.assetIDsWithMediaFile.map { $0.uuidString })
        return try mediaFileNames(in: url).filter { name in
            !expected.contains(String(name.dropLast(ArchiveLayout.mediaFileExtension.count + 1)))
        }.count
    }
}

extension ArchiveDocument {
    // swiftlint:disable cyclomatic_complexity
    /// Décode le fichier demandé. Exhaustif et sans `default`, symétrique de
    /// `encodedEntities(for:using:)` — et désactivé pour la même raison.
    mutating func decodeEntities(
        for file: ArchiveEntityFile, from bytes: Data, using decoder: JSONDecoder
    ) throws {
        do {
            switch file {
            case .libraries: libraries = try decoder.decode([LibraryRecord].self, from: bytes)
            case .profiles: profiles = try decoder.decode([ProfileRecord].self, from: bytes)
            case .titleFlags: titleFlags = try decoder.decode([TitleFlagRecord].self, from: bytes)
            case .personFlags:
                personFlags = try decoder.decode([PersonFlagRecord].self, from: bytes)
            case .mediaFlags: mediaFlags = try decoder.decode([MediaFlagRecord].self, from: bytes)
            case .titles: titles = try decoder.decode([TitleRecord].self, from: bytes)
            case .people: people = try decoder.decode([PersonRecord].self, from: bytes)
            case .socialHandles:
                socialHandles = try decoder.decode([SocialHandleRecord].self, from: bytes)
            case .collections:
                collections = try decoder.decode([CollectionRecord].self, from: bytes)
            case .genres: genres = try decoder.decode([GenreRecord].self, from: bytes)
            case .credits: credits = try decoder.decode([CreditRecord].self, from: bytes)
            case .mediaAssets:
                mediaAssets = try decoder.decode([MediaAssetRecord].self, from: bytes)
            case .mediaAttachments:
                mediaAttachments = try decoder.decode([MediaAttachmentRecord].self, from: bytes)
            case .mediaCrops: mediaCrops = try decoder.decode([MediaCropRecord].self, from: bytes)
            case .resourceLinks:
                resourceLinks = try decoder.decode([ResourceLinkRecord].self, from: bytes)
            case .savedLinks: savedLinks = try decoder.decode([SavedLinkRecord].self, from: bytes)
            case .activityEntries:
                activityEntries = try decoder.decode([ActivityEntryRecord].self, from: bytes)
            case .importMappings:
                importMappings = try decoder.decode([ImportMappingRecord].self, from: bytes)
            case .legacyRecords:
                legacyRecords = try decoder.decode([LegacyRecordRecord].self, from: bytes)
            }
        } catch let error as ArchiveError {
            throw error
        } catch {
            throw ArchiveError.malformedEntityFile(file.fileName)
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
