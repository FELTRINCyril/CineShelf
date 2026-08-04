import Foundation

/// La disposition d'un paquet `.cineshelfarchive`.
///
/// C'est un **dossier**, pas une archive compressée (`docs/04` §7). Le motif est celui
/// qui a fait retirer le `.zip` du handoff de design : un binaire ne se diffe pas, ne
/// s'inspecte pas, et ne se répare pas à la main. Une sauvegarde dont on ne peut pas
/// ouvrir un fichier pour vérifier ce qu'elle contient n'inspire aucune confiance, et
/// c'est précisément le moment où on en a besoin qu'on voudrait regarder dedans.
///
/// ```
/// MonCatalogue.cineshelfarchive/
///   manifest.json          version du format, date, comptes par entité
///   entities/*.json        un fichier par entité, dix-neuf en tout
///   media/<uuid>.bin       les octets des MediaAsset, un fichier par asset
/// ```
public enum ArchiveLayout {
    public static let fileExtension = "cineshelfarchive"
    public static let manifestFileName = "manifest.json"
    public static let entitiesDirectoryName = "entities"
    public static let mediaDirectoryName = "media"
    public static let mediaFileExtension = "bin"
}

/// Le manifeste : ce qu'il faut lire **avant** de toucher au reste.
///
/// Il porte les comptes par entité pour que la relecture puisse dire « le fichier
/// annonce 320 titres, j'en ai relu 318 » au lieu de rendre un catalogue amputé sans
/// rien signaler. C'est la leçon du lecteur CSV, qui annonçait « 7 lignes analysées »
/// sur 15 sans un mot sur les huit autres.
public struct ArchiveManifest: Codable, Sendable, Equatable {
    /// Version de **ce format d'archive**, indépendante de celle du schéma SwiftData.
    ///
    /// Elles bougent pour des raisons différentes : le format change quand on décide
    /// d'écrire les médias autrement, le schéma quand une entité gagne un champ.
    public static let currentVersion = 1

    public var formatVersion: Int
    /// Version du schéma SwiftData au moment de l'écriture — `CineShelfSchemaV1` rend
    /// `1.0.0`. Consignée pour qu'une archive écrite par une version future de l'app
    /// puisse être **reconnue** comme telle plutôt que relue de travers.
    public var schemaVersion: String
    public var createdAt: Date
    /// Comptes annoncés, par nom de collection d'entité. Voir `ArchiveEntityFile`.
    public var counts: [String: Int]
    /// Nombre de fichiers attendus dans `media/`.
    public var mediaFileCount: Int

    public init(
        formatVersion: Int = ArchiveManifest.currentVersion,
        schemaVersion: String,
        createdAt: Date,
        counts: [String: Int],
        mediaFileCount: Int
    ) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.counts = counts
        self.mediaFileCount = mediaFileCount
    }
}

/// Les dix-neuf fichiers d'entité, et le nom sous lequel chacun est écrit.
///
/// L'énumération est exhaustive et sans `default` nulle part : ajouter une entité au
/// schéma sans lui donner son fichier ici **cesse de compiler**. C'est le filet qui
/// remplace la vigilance, et c'est le seul qui tienne — une archive qui oublie
/// silencieusement une entité perd des données sans qu'aucun compte ne bouge, puisque
/// le manifeste est écrit depuis cette même liste.
public enum ArchiveEntityFile: String, CaseIterable, Sendable {
    case libraries
    case profiles
    case titleFlags = "title_flags"
    case personFlags = "person_flags"
    case mediaFlags = "media_flags"
    case titles
    case people
    case socialHandles = "social_handles"
    case collections
    case genres
    case credits
    case mediaAssets = "media_assets"
    case mediaAttachments = "media_attachments"
    case mediaCrops = "media_crops"
    case resourceLinks = "resource_links"
    case savedLinks = "saved_links"
    case activityEntries = "activity_entries"
    case importMappings = "import_mappings"
    case legacyRecords = "legacy_records"

    public var fileName: String { "\(rawValue).json" }
}

/// Les dates sont en ISO 8601 **avec les millisecondes**.
///
/// Arbitrage assumé : lisibilité du fichier contre fidélité absolue. Le défaut de
/// `JSONEncoder` écrit un `Double` depuis 2001, exact au bit mais illisible dans un
/// fichier qu'on ouvre justement pour vérifier ce qu'il contient. Le coût de l'ISO est
/// une perte **sous la milliseconde** sur `createdAt` et `updatedAt`, ce qui n'a aucune
/// conséquence : rien dans le modèle ne compare deux dates à cette résolution.
/// `ArchiveRoundTripTests` compare donc les dates à 1 ms près, et le dit.
///
/// `Date.ISO8601FormatStyle` et non `ISO8601DateFormatter` : le second n'est pas
/// `Sendable`, donc inutilisable en global sous concurrence stricte.
enum ArchiveDate {
    static let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Clés triées : deux archives du même catalogue donnent deux fichiers identiques
        // octet pour octet. C'est ce qui rend une archive diffable, et c'est la même
        // raison que pour `BulkEditDiff.encoded()`.
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, container in
            var container = container.singleValueContainer()
            try container.encode(style.format(date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { container in
            let text = try container.singleValueContainer().decode(String.self)
            guard let date = try? style.parse(text) else {
                throw ArchiveError.malformedDate(text)
            }
            return date
        }
        return decoder
    }
}

public enum ArchiveError: Error, Equatable, Sendable {
    /// L'archive a été écrite dans un format qu'on ne sait pas relire. Refuser
    /// explicitement plutôt que de deviner, comme `BulkEditDiff.decoded(from:)`.
    case unsupportedFormatVersion(Int)
    /// L'archive vient d'un **schéma** plus récent que celui de l'app.
    ///
    /// Distinct de la version de format : une archive de schéma V2 a le même format, donc
    /// se relisait sans un mot en perdant les champs que V2 a ajoutés. Le schéma étant
    /// fermé, c'est le chemin de la prochaine version de l'app.
    case unsupportedSchemaVersion(String)
    /// Le manifeste est absent : ce dossier n'est pas une archive.
    case missingManifest
    /// Un fichier d'entité annoncé par le manifeste est absent.
    case missingEntityFile(String)
    /// Le fichier est là mais ne se lit pas : disque, permission, volume démonté.
    ///
    /// Distinct de `missingEntityFile` exprès. Les confondre donne un refus nommé et un
    /// diagnostic faux, donc on cherche le mauvais coupable.
    case unreadableEntityFile(String)
    /// Le fichier existe mais ne se décode pas.
    case malformedEntityFile(String)
    case malformedDate(String)
    /// Le manifeste annonce un compte que le contenu ne tient pas. L'écart est chiffré
    /// des deux côtés : c'est la seule forme utile quand on cherche ce qui manque.
    ///
    /// `entity` vaut un `ArchiveEntityFile.rawValue`, ou `media` pour les octets.
    case countMismatch(entity: String, announced: Int, found: Int)
}
