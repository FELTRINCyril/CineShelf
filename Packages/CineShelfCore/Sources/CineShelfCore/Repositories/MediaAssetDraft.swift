import Foundation

/// Les champs d'un `MediaAsset` produits hors du modèle, par le pipeline médias.
///
/// Le cœur ne sait pas redimensionner une image ; il sait quoi stocker. Ce type
/// est le contrat entre les deux, et il est `Sendable` pour traverser un
/// `ModelActor` pendant un import.
public struct MediaAssetDraft: Sendable, Equatable {
    public var kind: MediaKind
    public var data: Data?
    public var externalURLString: String?
    public var mimeType: String?
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var byteSize: Int
    public var blurHash: String?
    /// Empreinte de dédoublonnage. Vide : l'asset est toujours créé.
    public var checksum: String

    public init(
        kind: MediaKind = .image,
        data: Data? = nil,
        externalURLString: String? = nil,
        mimeType: String? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        byteSize: Int = 0,
        blurHash: String? = nil,
        checksum: String = ""
    ) {
        self.kind = kind
        self.data = data
        self.externalURLString = externalURLString
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteSize = byteSize
        self.blurHash = blurHash
        self.checksum = checksum
    }
}
