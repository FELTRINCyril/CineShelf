import Foundation
import SwiftData

/// Écritures sur les médias.
///
/// `MediaAsset` n'a pas de dérivés textuels : il n'y a donc pas de
/// `refreshDerived()` à appeler, seulement `updatedAt` à tenir à jour. Le
/// rattachement à une entité (`MediaAttachment`) et le pipeline d'import
/// (redimensionnement, HEIC, blurHash, checksum) arrivent avec `MediaKit`.
@MainActor
public struct MediaRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(
        kind: MediaKind = .image,
        data: Data? = nil,
        externalURLString: String? = nil
    ) -> MediaAsset {
        let asset = MediaAsset(kind: kind)
        asset.data = data
        asset.externalURLString = externalURLString
        asset.byteSize = data?.count ?? 0
        context.insert(asset)
        ActivityRecorder(context: context).record(.create, asset)
        return asset
    }

    public func update(_ asset: MediaAsset, _ mutate: (MediaAsset) -> Void) {
        mutate(asset)
        asset.updatedAt = .now
        ActivityRecorder(context: context).record(.update, asset)
    }

    public func softDelete(_ asset: MediaAsset) {
        asset.deletedAt = .now
        asset.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, asset)
    }

    public func restore(_ asset: MediaAsset) {
        asset.deletedAt = nil
        asset.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, asset)
    }
}
