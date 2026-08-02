import Foundation
import SwiftData

/// Un média : l'original, et lui seul.
///
/// Les vignettes ne sont **jamais** dans le modèle : elles sont reconstructibles
/// et le quota iCloud appartient à l'utilisateur. Ce qui reste ici est minuscule
/// et sert à l'affichage instantané : `blurHash` et les dimensions en pixels.
@Model
public final class MediaAsset {
    public var id = UUID()
    public var kindRaw: String = MediaKind.image.rawValue

    /// Original. `.externalStorage` → mappé en `CKAsset` par le miroir CloudKit.
    @Attribute(.externalStorage) public var data: Data?
    /// Alternative : média hébergé ailleurs (ancien `medias.url` en http).
    public var externalURLString: String?

    public var mimeType: String?
    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var byteSize: Int = 0
    /// ~30 octets, pour un affichage immédiat sans saut de mise en page.
    public var blurHash: String?
    /// Dédoublonnage applicatif : CloudKit interdit `@Attribute(.unique)`.
    public var checksum: String = ""

    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    public var createdAt = Date()
    public var updatedAt = Date()

    @Relationship(deleteRule: .cascade, inverse: \MediaFlag.asset)
    public var flags: [MediaFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaCrop.asset)
    public var crops: [MediaCrop]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.asset)
    public var attachments: [MediaAttachment]? = []

    public init(kind: MediaKind = .image) {
        self.kindRaw = kind.rawValue
    }
}

extension MediaAsset {
    public var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .image }
        set { kindRaw = newValue.rawValue }
    }

    /// Reprend la sémantique v1 : contexte demandé → défaut → neutre.
    public func crop(for context: CropContext) -> CropValues {
        let all = crops ?? []
        if let match = all.first(where: { $0.contextRaw == context.rawValue }) {
            return CropValues(x: match.positionX, y: match.positionY, zoom: match.zoom)
        }
        if let fallback = all.first(where: { $0.contextRaw == CropContext.standard.rawValue }) {
            return CropValues(x: fallback.positionX, y: fallback.positionY, zoom: fallback.zoom)
        }
        return .neutral
    }
}
