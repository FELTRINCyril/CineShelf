import Foundation
import SwiftData

/// Lit tout le magasin et en écrit un paquet `.cineshelfarchive`.
///
/// Tout le magasin, pas une bibliothèque : `ActivityEntry` et `LegacyRecord` ne sont
/// rattachés à aucune, et une sauvegarde qui les laisserait dehors perdrait le journal
/// d'annulation et le lien vers les données d'origine de `L13` — c'est-à-dire les deux
/// recours dont on a besoin le jour où on restaure.
public struct ArchiveWriter {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// L'archive en mémoire, **sans les octets des médias**.
    ///
    /// Ils sont écrits fichier par fichier par `write(to:)` : les tenir tous en mémoire
    /// pour un catalogue de mille affiches coûterait quelques centaines de mégaoctets,
    /// et une sauvegarde n'a aucune raison de les rassembler avant de les écrire.
    public func snapshot() throws -> ArchiveDocument {
        var document = ArchiveDocument(
            manifest: ArchiveManifest(
                schemaVersion: schemaVersionText,
                createdAt: .now,
                counts: [:],
                mediaFileCount: 0
            )
        )
        try readRoots(into: &document)
        try readRelated(into: &document)
        try readJournals(into: &document)
        document.manifest.counts = document.counts
        document.manifest.mediaFileCount = document.assetIDsWithMediaFile.count
        return document
    }

    /// Écrit le paquet à l'emplacement demandé, et rend le manifeste écrit.
    ///
    /// **L'écriture est atomique** : tout va d'abord dans un dossier temporaire, qui ne
    /// prend la place de la destination qu'une fois complet. Une archive à moitié écrite
    /// est pire qu'une archive absente — elle a l'air d'une sauvegarde.
    @discardableResult
    public func write(to destination: URL) throws -> ArchiveManifest {
        let document = try snapshot()
        let manager = FileManager.default
        let staging = manager.temporaryDirectory
            .appendingPathComponent("cineshelf-archive-\(UUID().uuidString)", isDirectory: true)
        // Le dossier de travail part quoi qu'il arrive, y compris si l'écriture lève.
        defer { try? manager.removeItem(at: staging) }

        let entities = staging.appendingPathComponent(
            ArchiveLayout.entitiesDirectoryName, isDirectory: true)
        let media = staging.appendingPathComponent(
            ArchiveLayout.mediaDirectoryName, isDirectory: true)
        try manager.createDirectory(at: entities, withIntermediateDirectories: true)
        try manager.createDirectory(at: media, withIntermediateDirectories: true)

        let encoder = ArchiveDate.encoder()
        try encoder.encode(document.manifest)
            .write(to: staging.appendingPathComponent(ArchiveLayout.manifestFileName))
        for file in ArchiveEntityFile.allCases {
            try document.encodedEntities(for: file, using: encoder)
                .write(to: entities.appendingPathComponent(file.fileName))
        }

        // Les octets, un asset à la fois : `data` est en `.externalStorage`, donc chargé
        // à la demande, et on ne veut pas tout le catalogue en mémoire d'un coup.
        for asset in try all(MediaAsset.self) {
            guard let bytes = asset.data else { continue }
            try bytes.write(
                to: media.appendingPathComponent(
                    "\(asset.id.uuidString).\(ArchiveLayout.mediaFileExtension)"))
        }

        if manager.fileExists(atPath: destination.path) {
            _ = try manager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try manager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.moveItem(at: staging, to: destination)
        }
        return document.manifest
    }

    // MARK: - Lecture, par groupe

    /// Les entités qui existent par elles-mêmes : elles n'ont besoin d'aucune autre pour
    /// avoir un sens, et ce sont elles que la restauration crée en premier.
    private func readRoots(into document: inout ArchiveDocument) throws {
        document.libraries = try all(Library.self).map {
            LibraryRecord(
                id: $0.id, name: $0.name, isDefault: $0.isDefault, isSandbox: $0.isSandbox,
                sortIndex: $0.sortIndex, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        document.profiles = try all(Profile.self).map {
            ProfileRecord(
                id: $0.id, name: $0.name, avatarSymbol: $0.avatarSymbol,
                avatarEmoji: $0.avatarEmoji, accentRaw: $0.accentRaw, isDefault: $0.isDefault,
                sortIndex: $0.sortIndex, requiresBiometry: $0.requiresBiometry,
                hidesPrivateContent: $0.hidesPrivateContent, createdAt: $0.createdAt,
                updatedAt: $0.updatedAt, libraryID: $0.library?.id)
        }
        document.collections = try all(TitleCollection.self).map {
            CollectionRecord(
                id: $0.id, name: $0.name, summary: $0.summary, isPrivate: $0.isPrivate,
                isArchived: $0.isArchived, deletedAt: $0.deletedAt, createdAt: $0.createdAt,
                updatedAt: $0.updatedAt, libraryID: $0.library?.id)
        }
        document.genres = try all(Genre.self).map {
            GenreRecord(
                id: $0.id, name: $0.name, targetRaw: $0.targetRaw, colorToken: $0.colorToken,
                isPinned: $0.isPinned, pinIndex: $0.pinIndex, isPrivate: $0.isPrivate,
                isArchived: $0.isArchived, deletedAt: $0.deletedAt, createdAt: $0.createdAt,
                updatedAt: $0.updatedAt, libraryID: $0.library?.id)
        }
        document.titles = try all(Title.self).map {
            TitleRecord(
                id: $0.id, kindRaw: $0.kindRaw, name: $0.name, originalName: $0.originalName,
                summary: $0.summary, releaseDate: $0.releaseDate,
                releasePrecisionRaw: $0.releasePrecisionRaw, runtimeMinutes: $0.runtimeMinutes,
                seasonCount: $0.seasonCount, episodeCount: $0.episodeCount, rating: $0.rating,
                isPrivate: $0.isPrivate, isArchived: $0.isArchived, deletedAt: $0.deletedAt,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt, libraryID: $0.library?.id,
                collectionID: $0.collection?.id, genreIDs: Self.sorted($0.genres))
        }
        document.people = try all(Person.self).map {
            PersonRecord(
                id: $0.id, firstName: $0.firstName, lastName: $0.lastName,
                birthDate: $0.birthDate, deathDate: $0.deathDate, bio: $0.bio,
                roleValues: $0.roleValues, isPrivate: $0.isPrivate, isArchived: $0.isArchived,
                deletedAt: $0.deletedAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                libraryID: $0.library?.id, genreIDs: Self.sorted($0.genres))
        }
        document.mediaAssets = try all(MediaAsset.self).map {
            MediaAssetRecord(
                id: $0.id, kindRaw: $0.kindRaw, hasMediaFile: $0.data != nil,
                externalURLString: $0.externalURLString, mimeType: $0.mimeType,
                pixelWidth: $0.pixelWidth, pixelHeight: $0.pixelHeight, byteSize: $0.byteSize,
                blurHash: $0.blurHash, checksum: $0.checksum, isGenerated: $0.isGenerated,
                isPrivate: $0.isPrivate, isArchived: $0.isArchived, deletedAt: $0.deletedAt,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
    }

    /// Les entités qui n'existent que par ce qu'elles relient : un crédit sans titre ni
    /// personne ne veut rien dire, un recadrage sans média non plus.
    private func readRelated(into document: inout ArchiveDocument) throws {
        document.credits = try all(Credit.self).map {
            CreditRecord(
                id: $0.id, roleRaw: $0.roleRaw, characterName: $0.characterName,
                orderIndex: $0.orderIndex, createdAt: $0.createdAt, titleID: $0.title?.id,
                personID: $0.person?.id)
        }
        document.socialHandles = try all(SocialHandle.self).map {
            SocialHandleRecord(
                id: $0.id, platform: $0.platform, handle: $0.handle, urlString: $0.urlString,
                createdAt: $0.createdAt, personID: $0.person?.id)
        }
        document.mediaAttachments = try all(MediaAttachment.self).map {
            MediaAttachmentRecord(
                id: $0.id, slotRaw: $0.slotRaw, orderIndex: $0.orderIndex,
                createdAt: $0.createdAt, assetID: $0.asset?.id, titleID: $0.title?.id,
                personID: $0.person?.id, collectionID: $0.collection?.id)
        }
        document.mediaCrops = try all(MediaCrop.self).map {
            MediaCropRecord(
                id: $0.id, contextRaw: $0.contextRaw, positionX: $0.positionX,
                positionY: $0.positionY, zoom: $0.zoom, updatedAt: $0.updatedAt,
                assetID: $0.asset?.id)
        }
        document.resourceLinks = try all(ResourceLink.self).map {
            ResourceLinkRecord(
                id: $0.id, urlString: $0.urlString, label: $0.label, summary: $0.summary,
                faviconData: $0.faviconData, orderIndex: $0.orderIndex,
                isArchived: $0.isArchived, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                titleID: $0.title?.id, personID: $0.person?.id, collectionID: $0.collection?.id)
        }
        document.savedLinks = try all(SavedLink.self).map {
            SavedLinkRecord(
                id: $0.id, urlString: $0.urlString, name: $0.name, notes: $0.notes,
                faviconData: $0.faviconData, kindRaw: $0.kindRaw, isPrivate: $0.isPrivate,
                isArchived: $0.isArchived, deletedAt: $0.deletedAt, createdAt: $0.createdAt,
                updatedAt: $0.updatedAt, libraryID: $0.library?.id, genreID: $0.genre?.id)
        }
        document.titleFlags = try all(TitleFlag.self).map {
            TitleFlagRecord(
                id: $0.id, isFavorite: $0.isFavorite, isInWatchlist: $0.isInWatchlist,
                isWatched: $0.isWatched, watchedAt: $0.watchedAt,
                personalRating: $0.personalRating, updatedAt: $0.updatedAt,
                profileID: $0.profile?.id, titleID: $0.title?.id)
        }
        document.personFlags = try all(PersonFlag.self).map {
            PersonFlagRecord(
                id: $0.id, isFavorite: $0.isFavorite, updatedAt: $0.updatedAt,
                profileID: $0.profile?.id, personID: $0.person?.id)
        }
        document.mediaFlags = try all(MediaFlag.self).map {
            MediaFlagRecord(
                id: $0.id, isFavorite: $0.isFavorite, updatedAt: $0.updatedAt,
                profileID: $0.profile?.id, assetID: $0.asset?.id)
        }
    }

    /// Ce qui n'appartient à aucune bibliothèque : le fil, les correspondances d'import,
    /// et le lien vers les données de la v1. Les trois sont dans l'archive parce que les
    /// perdre, c'est perdre un recours — pas seulement un affichage.
    private func readJournals(into document: inout ArchiveDocument) throws {
        document.activityEntries = try all(ActivityEntry.self).map {
            ActivityEntryRecord(
                id: $0.id, actionRaw: $0.actionRaw, entityTypeRaw: $0.entityTypeRaw,
                entityID: $0.entityID, summary: $0.summary, createdAt: $0.createdAt,
                payload: $0.payload, undoneAt: $0.undoneAt)
        }
        document.importMappings = try all(ImportMapping.self).map {
            ImportMappingRecord(
                id: $0.id, name: $0.name, headerSignature: $0.headerSignature,
                columnMapData: $0.columnMapData, isBuiltIn: $0.isBuiltIn,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt, libraryID: $0.library?.id)
        }
        document.legacyRecords = try all(LegacyRecord.self).map {
            LegacyRecordRecord(
                id: $0.id, entityTypeRaw: $0.entityTypeRaw, entityID: $0.entityID,
                legacyTable: $0.legacyTable, legacyID: $0.legacyID, importedAt: $0.importedAt)
        }
    }

    private func all<Model: PersistentModel>(_ type: Model.Type) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
    }

    /// Les identifiants d'une relation « plusieurs à plusieurs », triés.
    ///
    /// Triés parce que SwiftData ne garantit pas l'ordre d'un `to-many` : sans tri, deux
    /// archives du même catalogue diffèrent, et la propriété qui rend une archive
    /// diffable est perdue.
    static func sorted(_ genres: [Genre]?) -> [UUID] {
        (genres ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString }
    }

    private var schemaVersionText: String {
        let version = CineShelfSchemaV1.versionIdentifier
        return "\(version.major).\(version.minor).\(version.patch)"
    }
}

extension ArchiveDocument {
    // swiftlint:disable cyclomatic_complexity
    /// Encode le fichier demandé. Exhaustif et sans `default`, pour la même raison que
    /// `count(of:)` : une entité nouvelle ne peut pas être oubliée en silence, et la
    /// complexité mesurée est celle des dix-neuf cas, pas celle du code.
    func encodedEntities(for file: ArchiveEntityFile, using encoder: JSONEncoder) throws -> Data {
        switch file {
        case .libraries: try encoder.encode(libraries)
        case .profiles: try encoder.encode(profiles)
        case .titleFlags: try encoder.encode(titleFlags)
        case .personFlags: try encoder.encode(personFlags)
        case .mediaFlags: try encoder.encode(mediaFlags)
        case .titles: try encoder.encode(titles)
        case .people: try encoder.encode(people)
        case .socialHandles: try encoder.encode(socialHandles)
        case .collections: try encoder.encode(collections)
        case .genres: try encoder.encode(genres)
        case .credits: try encoder.encode(credits)
        case .mediaAssets: try encoder.encode(mediaAssets)
        case .mediaAttachments: try encoder.encode(mediaAttachments)
        case .mediaCrops: try encoder.encode(mediaCrops)
        case .resourceLinks: try encoder.encode(resourceLinks)
        case .savedLinks: try encoder.encode(savedLinks)
        case .activityEntries: try encoder.encode(activityEntries)
        case .importMappings: try encoder.encode(importMappings)
        case .legacyRecords: try encoder.encode(legacyRecords)
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
