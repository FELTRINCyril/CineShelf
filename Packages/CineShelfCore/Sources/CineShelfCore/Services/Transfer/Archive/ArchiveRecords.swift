import Foundation

// Les dix-neuf enregistrements du format d'archive : une structure `Codable` par entité
// du schéma. Trois règles valent pour toutes, et elles expliquent la plupart des
// absences qu'on pourrait prendre pour des oublis.
//
// **1. Les champs dérivés ne sont pas écrits.** `sortName`, `searchText`, `filterKeys`,
// `nameKey`, `displayName` et `ageAtDeath` sont absents de ces structures : ils sont
// recalculés par `refreshDerived()` à la restauration. Les écrire créerait une seconde
// source de vérité qui divergerait de la fonction au premier changement de règle de
// repliage — et il y en a déjà eu un, l'invariance de locale du 2026-08-04. En prime,
// `filterKeys` dérive des identifiants des relations, qui sont préservés tels quels :
// le recalcul rend donc exactement la même valeur, et l'aller-retour le vérifie.
//
// **2. Les énumérations sont écrites en `rawValue`, jamais typées.** Décoder en
// `TitleKind` refuserait — ou remplacerait par le défaut — une valeur écrite par une
// version future de l'app et rapatriée par CloudKit. Le modèle tolère exprès ce cas
// (`Title.kind` replie sur `.movie` à la lecture sans écraser `kindRaw`) ; une
// sauvegarde qui normaliserait au passage perdrait l'information au lieu de la garder.
// Une archive conserve ce qu'elle trouve.
//
// **3. Une relation est portée par son côté « vers un ».** Un `Credit` porte son titre
// et sa personne ; `Title.credits` n'est écrit nulle part, il se reconstruit. Les deux
// seules relations sans côté « vers un » — `Title.genres` et `Person.genres`, qui sont
// des « plusieurs à plusieurs » — sont portées par le titre et par la personne, par
// convention, et pas par le genre.

public struct LibraryRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var isDefault: Bool
    public var isSandbox: Bool
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date
}

public struct ProfileRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var avatarSymbol: String
    public var avatarEmoji: String?
    public var accentRaw: String
    public var isDefault: Bool
    public var sortIndex: Int
    public var requiresBiometry: Bool
    public var hidesPrivateContent: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
}

public struct TitleFlagRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var isFavorite: Bool
    public var isInWatchlist: Bool
    public var isWatched: Bool
    public var watchedAt: Date?
    public var personalRating: Double?
    public var updatedAt: Date
    public var profileID: UUID?
    public var titleID: UUID?
}

public struct PersonFlagRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var isFavorite: Bool
    public var updatedAt: Date
    public var profileID: UUID?
    public var personID: UUID?
}

public struct MediaFlagRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var isFavorite: Bool
    public var updatedAt: Date
    public var profileID: UUID?
    public var assetID: UUID?
}

public struct TitleRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var kindRaw: String
    public var name: String
    public var originalName: String?
    public var summary: String?
    public var releaseDate: Date?
    public var releasePrecisionRaw: String
    public var runtimeMinutes: Int?
    public var seasonCount: Int?
    public var episodeCount: Int?
    public var rating: Double?
    public var isPrivate: Bool
    public var isArchived: Bool
    /// La corbeille est **dans** l'archive : une sauvegarde qui la perdrait supprimerait
    /// définitivement, à la restauration, ce que l'utilisateur avait seulement jeté.
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
    public var collectionID: UUID?
    public var genreIDs: [UUID]
}

public struct PersonRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var firstName: String
    public var lastName: String
    public var birthDate: Date?
    public var deathDate: Date?
    public var bio: String?
    public var roleValues: [String]
    public var isPrivate: Bool
    public var isArchived: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
    public var genreIDs: [UUID]
}

public struct SocialHandleRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var platform: String
    public var handle: String
    public var urlString: String?
    public var createdAt: Date
    public var personID: UUID?
}

public struct CollectionRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var summary: String?
    public var isPrivate: Bool
    public var isArchived: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
}

public struct GenreRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var targetRaw: String
    public var colorToken: String?
    public var isPinned: Bool
    public var pinIndex: Int
    public var isPrivate: Bool
    public var isArchived: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
}

public struct CreditRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var roleRaw: String
    public var characterName: String?
    public var orderIndex: Int
    public var createdAt: Date
    public var titleID: UUID?
    public var personID: UUID?
}

public struct MediaAssetRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var kindRaw: String
    /// Vrai si les octets sont dans `media/<id>.bin`.
    ///
    /// Les octets ne sont **pas** en base64 ici : `MediaAsset.data` est en
    /// `.externalStorage` parce qu'une affiche pèse des centaines de kilooctets, et un
    /// `entities/media_assets.json` de trente mégaoctets ne s'ouvrirait plus.
    ///
    /// Le fichier est nommé par l'**identifiant de l'asset**, pas par son `checksum`.
    /// Le checksum vaut `""` sur tout asset dont personne ne l'a calculé — c'est le cas
    /// de `DemoCatalog`, écart connu — donc nommer par checksum ferait écrire deux
    /// assets distincts dans le même fichier, et le second écraserait le premier sans
    /// qu'aucun compte ne bouge.
    public var hasMediaFile: Bool
    public var externalURLString: String?
    public var mimeType: String?
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var byteSize: Int
    public var blurHash: String?
    public var checksum: String
    public var isGenerated: Bool
    public var isPrivate: Bool
    public var isArchived: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
}

public struct MediaAttachmentRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var slotRaw: String
    public var orderIndex: Int
    public var createdAt: Date
    public var assetID: UUID?
    /// Un seul des trois est non nul — invariant `hasExactlyOneOwner`. L'archive ne le
    /// corrige pas à l'écriture : elle écrit ce qu'elle trouve, et la restauration
    /// compte les rattachements qui le violent au lieu de les taire.
    public var titleID: UUID?
    public var personID: UUID?
    public var collectionID: UUID?
}

public struct MediaCropRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var contextRaw: String
    public var positionX: Double
    public var positionY: Double
    public var zoom: Double
    public var updatedAt: Date
    public var assetID: UUID?
}

public struct ResourceLinkRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var urlString: String
    public var label: String?
    public var summary: String?
    /// Un favicon fait quelques kilooctets et n'est pas en `.externalStorage` dans le
    /// modèle : il reste en base64 dans le JSON, où il ne gêne personne.
    public var faviconData: Data?
    public var orderIndex: Int
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var titleID: UUID?
    public var personID: UUID?
    public var collectionID: UUID?
}

public struct SavedLinkRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var urlString: String
    public var name: String?
    public var notes: String?
    public var faviconData: Data?
    public var kindRaw: String
    public var isPrivate: Bool
    public var isArchived: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
    public var genreID: UUID?
}

public struct ActivityEntryRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var actionRaw: String
    public var entityTypeRaw: String
    public var entityID: UUID
    public var summary: String
    public var createdAt: Date
    /// Le diff d'annulation de `L10`, en base64.
    ///
    /// Il est dans l'archive parce qu'une sauvegarde qui le perdrait rendrait
    /// **inannulable** tout lot antérieur à la restauration, sans le dire. Le format du
    /// diff a sa propre version (`BulkEditDiff.currentVersion`), indépendante de celle
    /// de l'archive : l'archive transporte ces octets, elle ne les interprète pas.
    public var payload: Data?
    public var undoneAt: Date?
}

public struct ImportMappingRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var headerSignature: String
    public var columnMapData: Data?
    public var isBuiltIn: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var libraryID: UUID?
}

public struct LegacyRecordRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var entityTypeRaw: String
    public var entityID: UUID
    public var legacyTable: String
    public var legacyID: String
    public var importedAt: Date
}

/// Une archive relue, en mémoire, sans qu'aucun magasin n'ait été touché.
///
/// La séparation compte : `ArchiveReader` produit cette valeur et rien d'autre, donc
/// tout le travail de format se teste sans conteneur SwiftData. `ArchiveRestorer` est
/// le seul à écrire.
public struct ArchiveDocument: Sendable, Equatable {
    public var manifest: ArchiveManifest
    public var libraries: [LibraryRecord] = []
    public var profiles: [ProfileRecord] = []
    public var titleFlags: [TitleFlagRecord] = []
    public var personFlags: [PersonFlagRecord] = []
    public var mediaFlags: [MediaFlagRecord] = []
    public var titles: [TitleRecord] = []
    public var people: [PersonRecord] = []
    public var socialHandles: [SocialHandleRecord] = []
    public var collections: [CollectionRecord] = []
    public var genres: [GenreRecord] = []
    public var credits: [CreditRecord] = []
    public var mediaAssets: [MediaAssetRecord] = []
    public var mediaAttachments: [MediaAttachmentRecord] = []
    public var mediaCrops: [MediaCropRecord] = []
    public var resourceLinks: [ResourceLinkRecord] = []
    public var savedLinks: [SavedLinkRecord] = []
    public var activityEntries: [ActivityEntryRecord] = []
    public var importMappings: [ImportMappingRecord] = []
    public var legacyRecords: [LegacyRecordRecord] = []

    /// Les fichiers de `entities/` que le format courant ne connaît pas.
    ///
    /// Pas une erreur — l'archive reste lisible — mais **comptés**. La boucle de relecture
    /// n'itère que sur `ArchiveEntityFile.allCases` : sans ce relevé, un fichier écrit par
    /// une version plus récente est parfaitement invisible.
    public var unknownEntityFiles: [String] = []

    /// Le nombre de fichiers réellement présents dans `media/`, relevé à la relecture.
    ///
    /// À comparer à `manifest.mediaFileCount` — c'est ce qui permet de savoir **avant
    /// d'écrire** qu'une archive a perdu ses images, sans pour autant la refuser : un média
    /// manquant n'annule pas une restauration, et un orphelin n'est pas une erreur.
    /// `mediaFileDelta` fait la soustraction.
    public var mediaFilesFound = 0

    public init(manifest: ArchiveManifest) {
        self.manifest = manifest
    }

    // swiftlint:disable cyclomatic_complexity
    /// Le compte réel, par fichier. Comparé à celui du manifeste par la relecture.
    ///
    /// Le `switch` est exhaustif et sans `default` : une entité ajoutée au schéma sans
    /// être comptée ici cesse de compiler.
    ///
    /// La complexité que SwiftLint mesure est celle des dix-neuf cas, pas celle du code :
    /// il n'y a aucune branche, aucune condition, et découper ce `switch` en deux
    /// détruirait précisément la propriété qui le justifie — l'exhaustivité vérifiée par
    /// le compilateur. Même arbitrage que `ColorTokens.generated.swift`.
    public func count(of file: ArchiveEntityFile) -> Int {
        switch file {
        case .libraries: libraries.count
        case .profiles: profiles.count
        case .titleFlags: titleFlags.count
        case .personFlags: personFlags.count
        case .mediaFlags: mediaFlags.count
        case .titles: titles.count
        case .people: people.count
        case .socialHandles: socialHandles.count
        case .collections: collections.count
        case .genres: genres.count
        case .credits: credits.count
        case .mediaAssets: mediaAssets.count
        case .mediaAttachments: mediaAttachments.count
        case .mediaCrops: mediaCrops.count
        case .resourceLinks: resourceLinks.count
        case .savedLinks: savedLinks.count
        case .activityEntries: activityEntries.count
        case .importMappings: importMappings.count
        case .legacyRecords: legacyRecords.count
        }
    }
    // swiftlint:enable cyclomatic_complexity

    public var counts: [String: Int] {
        Dictionary(uniqueKeysWithValues: ArchiveEntityFile.allCases.map { ($0.rawValue, count(of: $0)) })
    }

    /// Les assets dont les octets doivent se trouver dans `media/`.
    public var assetIDsWithMediaFile: [UUID] {
        mediaAssets.filter(\.hasMediaFile).map(\.id)
    }

    /// L'écart entre les fichiers d'octets attendus et ceux trouvés.
    ///
    /// Négatif : des images ont été perdues. Positif : des octets sont en trop, ce qui
    /// signale un asset perdu à l'écriture. Zéro dans une archive saine.
    public var mediaFileDelta: Int { mediaFilesFound - manifest.mediaFileCount }
}
