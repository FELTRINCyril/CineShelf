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

        // La version se vérifie **avant** de toucher au moindre fichier d'entité. Une
        // archive écrite par une version future peut avoir déplacé les médias ou renommé
        // un champ : la lire « au mieux » rendrait un catalogue partiel qui a l'air
        // complet. Même refus explicite que `BulkEditDiff.decoded(from:)`.
        guard manifest.formatVersion == ArchiveManifest.currentVersion else {
            throw ArchiveError.unsupportedFormatVersion(manifest.formatVersion)
        }

        var document = ArchiveDocument(manifest: manifest)
        let entities = url.appendingPathComponent(
            ArchiveLayout.entitiesDirectoryName, isDirectory: true)
        for file in ArchiveEntityFile.allCases {
            let fileURL = entities.appendingPathComponent(file.fileName)
            guard let bytes = try? Data(contentsOf: fileURL) else {
                throw ArchiveError.missingEntityFile(file.fileName)
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
        return document
    }

    /// Les octets d'un asset, ou `nil` si l'archive n'en porte pas.
    public func mediaData(forAssetID id: UUID, in url: URL) -> Data? {
        try? Data(
            contentsOf:
                url
                .appendingPathComponent(ArchiveLayout.mediaDirectoryName, isDirectory: true)
                .appendingPathComponent("\(id.uuidString).\(ArchiveLayout.mediaFileExtension)"))
    }

    /// Les fichiers présents dans `media/` que **aucun** asset ne réclame.
    ///
    /// Ils ne sont pas une erreur — une archive reste lisible avec des octets en trop —
    /// mais ils se comptent : c'est le signe d'un asset perdu à l'écriture, et le seul
    /// endroit où cette perte laisse une trace.
    public func orphanedMediaFileCount(in url: URL, for document: ArchiveDocument) -> Int {
        let media = url.appendingPathComponent(
            ArchiveLayout.mediaDirectoryName, isDirectory: true)
        let present =
            (try? FileManager.default.contentsOfDirectory(atPath: media.path))?
            .filter { $0.hasSuffix(".\(ArchiveLayout.mediaFileExtension)") } ?? []
        let expected = Set(document.assetIDsWithMediaFile.map { $0.uuidString })
        return present.filter { name in
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
