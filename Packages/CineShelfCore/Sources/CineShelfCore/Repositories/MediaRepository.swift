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
        create(
            MediaAssetDraft(
                kind: kind,
                data: data,
                externalURLString: externalURLString,
                byteSize: data?.count ?? 0
            )
        )
    }

    @discardableResult
    public func create(_ draft: MediaAssetDraft) -> MediaAsset {
        let asset = MediaAsset(kind: draft.kind)
        apply(draft, to: asset)
        context.insert(asset)
        ActivityRecorder(context: context).record(.create, asset)
        return asset
    }

    /// Réutilise l'asset de même empreinte s'il en existe un : c'est notre
    /// remplacement de la contrainte d'unicité, comme `nameKey` pour les genres.
    ///
    /// Les assets à la corbeille sont ignorés : réimporter un fichier supprimé
    /// crée un asset neuf plutôt que de ressusciter l'ancien avec ses
    /// rattachements.
    public func findOrCreate(_ draft: MediaAssetDraft) throws -> MediaAsset {
        if let existing = try asset(withChecksum: draft.checksum) { return existing }
        return create(draft)
    }

    public func asset(withChecksum checksum: String) throws -> MediaAsset? {
        guard !checksum.isEmpty else { return nil }
        var descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.checksum == checksum && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func apply(_ draft: MediaAssetDraft, to asset: MediaAsset) {
        asset.kind = draft.kind
        asset.data = draft.data
        asset.externalURLString = draft.externalURLString
        asset.mimeType = draft.mimeType
        asset.pixelWidth = draft.pixelWidth
        asset.pixelHeight = draft.pixelHeight
        asset.byteSize = draft.byteSize
        asset.blurHash = draft.blurHash
        asset.checksum = draft.checksum
    }

    /// L'asset d'un identifiant, pour le cache de vignettes qui ne connaît que
    /// des `UUID`.
    public func asset(withID id: UUID) throws -> MediaAsset? {
        var descriptor = FetchDescriptor<MediaAsset>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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
