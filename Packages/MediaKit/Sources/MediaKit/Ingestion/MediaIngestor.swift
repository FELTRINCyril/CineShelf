import CineShelfCore
import CoreGraphics
import CryptoKit
import Foundation

public enum MediaIngestionError: Error, Equatable {
    /// Les octets fournis ne sont pas une image lisible par ImageIO.
    case unreadableSource
    /// Le redimensionnement a échoué.
    case decodingFailed
    /// L'encodage HEIC a échoué.
    case encodingFailed
}

/// Le résultat de l'ingestion : tout ce qu'un `MediaAsset` a besoin de stocker.
public struct IngestedImage: Sendable, Equatable {
    /// L'original normalisé, en HEIC. C'est lui qui part en `CKAsset`.
    public let data: Data
    public let mimeType: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteSize: Int
    /// sha256 des octets **source**, pas du HEIC produit : voir `MediaIngestor`.
    public let checksum: String
    public let blurHash: String

    public var draft: MediaAssetDraft {
        MediaAssetDraft(
            kind: .image,
            data: data,
            mimeType: mimeType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteSize: byteSize,
            blurHash: blurHash,
            checksum: checksum
        )
    }
}

/// Le pipeline d'ingestion de `docs/04` §4.
///
/// Un original de 8 Mo n'apporte rien à un catalogue : tout est ramené à
/// 2 000 px sur le grand côté et ré-encodé en HEIC, ce qui divise le poids par
/// trois environ par rapport au JPEG source.
///
/// **Le checksum porte sur les octets source**, pas sur le HEIC produit : il est
/// ainsi calculable sans décoder, et surtout stable d'un appareil et d'une
/// version d'OS à l'autre. Un encodeur qui évolue donnerait sinon deux empreintes
/// pour la même image, et le dédoublonnage tomberait après une synchronisation.
public struct MediaIngestor: Sendable {
    public static let defaultMaxPixelSize = 2000
    public static let defaultQuality = 0.8

    public let maxPixelSize: Int
    public let quality: Double

    public init(maxPixelSize: Int = Self.defaultMaxPixelSize, quality: Double = Self.defaultQuality) {
        self.maxPixelSize = maxPixelSize
        self.quality = quality
    }

    public func ingest(data source: Data) throws -> IngestedImage {
        guard !source.isEmpty else { throw MediaIngestionError.unreadableSource }
        guard let resized = ImageDecoder.thumbnail(from: source, maxPixelSize: maxPixelSize) else {
            throw MediaIngestionError.unreadableSource
        }
        return try finish(resized, checksum: Self.checksum(of: source))
    }

    /// Lit le fichier en projection mémoire : un original volumineux n'est pas
    /// recopié dans le tas pour être ingéré.
    public func ingest(fileURL: URL) throws -> IngestedImage {
        let source = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try ingest(data: source)
    }

    public static func checksum(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func finish(_ image: CGImage, checksum: String) throws -> IngestedImage {
        let encoded = try HEICEncoder.encode(image, quality: quality)
        let blurHash = try BlurHash.encode(image)
        return IngestedImage(
            data: encoded,
            mimeType: HEICEncoder.mimeType,
            pixelWidth: image.width,
            pixelHeight: image.height,
            byteSize: encoded.count,
            checksum: checksum,
            blurHash: blurHash
        )
    }
}
