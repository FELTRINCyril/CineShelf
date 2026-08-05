import Foundation
import SwiftData

/// Écritures sur les médias.
///
/// `MediaAsset` n'a pas de dérivés textuels : il n'y a donc pas de
/// `refreshDerived()` à appeler, seulement `updatedAt` à tenir à jour.
///
/// **Le rattachement arrive avec `V2`**, parce que c'est la tâche qui importe des images et
/// qu'il n'y avait aucun moyen de les relier à quoi que ce soit. Il était inscrit à `L16`,
/// qui garde l'autre moitié du sujet — la vérification de l'invariante à l'échelle du
/// magasin, et la réparation des lignes qui l'auraient perdue.
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

    // MARK: - Rattachement

    /// Rattache un média à un titre, à une personne ou à une collection.
    ///
    /// **Un seul propriétaire, et c'est structurel.** `MediaAttachment.hasExactlyOneOwner`
    /// est l'invariante du modèle ; ces trois surcharges la rendent **impossible à violer
    /// depuis l'appelant**, puisqu'aucune ne laisse passer deux propriétaires. Une méthode
    /// unique à trois paramètres optionnels aurait permis d'en passer deux, et l'invariante
    /// n'aurait plus été vérifiable qu'à l'exécution.
    ///
    /// - Parameters:
    ///   - asset: le média, déjà créé et dédoublonné par `findOrCreate(_:)`.
    ///   - title: le propriétaire.
    ///   - slot: l'emplacement. `.gallery` par défaut : c'est le cas de loin le plus
    ///     fréquent, et le seul qui accepte plusieurs médias.
    /// - Returns: la pièce jointe créée.
    @discardableResult
    public func attach(
        _ asset: MediaAsset, to title: Title, slot: MediaSlot = .gallery
    ) -> MediaAttachment {
        let attachment = makeAttachment(asset, slot: slot, in: title.attachments?.count ?? 0)
        attachment.title = title
        return attachment
    }

    @discardableResult
    public func attach(
        _ asset: MediaAsset, to person: Person, slot: MediaSlot = .gallery
    ) -> MediaAttachment {
        let attachment = makeAttachment(asset, slot: slot, in: person.attachments?.count ?? 0)
        attachment.person = person
        return attachment
    }

    @discardableResult
    public func attach(
        _ asset: MediaAsset, to collection: TitleCollection, slot: MediaSlot = .gallery
    ) -> MediaAttachment {
        let attachment = makeAttachment(
            asset, slot: slot, in: collection.attachments?.count ?? 0)
        attachment.collection = collection
        return attachment
    }

    /// Détache un média de son propriétaire.
    ///
    /// **Le média n'est pas supprimé**, et c'est délibéré : il devient orphelin, ce que le
    /// filtre de galerie de `L1 bis` sait montrer. Supprimer ici ferait perdre une image
    /// qu'un autre écran est peut-être en train de recadrer, et le dédoublonnage la
    /// retrouverait de toute façon au prochain import du même fichier.
    public func detach(_ attachment: MediaAttachment) {
        context.delete(attachment)
    }

    /// Un emplacement à média unique n'en accepte qu'un : le remplacer détache l'ancien.
    ///
    /// `.primary`, `.portrait` et `.backdrop` désignent **une** image. Sans ce remplacement,
    /// un second import de jaquette laisserait deux pièces jointes `.primary` sur le même
    /// titre, et `TitleFormat.primaryAsset` en choisirait une au hasard de l'ordre de
    /// stockage — une jaquette qui change d'un lancement à l'autre.
    @discardableResult
    public func setSingle(
        _ asset: MediaAsset, on title: Title, slot: MediaSlot
    ) -> MediaAttachment {
        for existing in title.attachments ?? [] where existing.slot == slot {
            context.delete(existing)
        }
        return attach(asset, to: title, slot: slot)
    }

    private func makeAttachment(
        _ asset: MediaAsset, slot: MediaSlot, in count: Int
    ) -> MediaAttachment {
        let attachment = MediaAttachment(slot: slot, orderIndex: count)
        attachment.asset = asset
        context.insert(attachment)
        return attachment
    }

    // MARK: - Recadrage

    /// Enregistre le recadrage d'un média pour un contexte donné.
    ///
    /// **Une ligne par contexte, mise à jour et non dupliquée.** `MediaCrop` porte un
    /// `contextRaw`, et deux lignes pour le même couple `(média, contexte)` rendraient le
    /// recadrage indéterminé — `CropDisplay.of(_:in:)` en prendrait une au hasard. C'est le
    /// même défaut que deux pièces jointes sur un emplacement unique, et il se règle de la
    /// même façon : on cherche avant d'insérer.
    ///
    /// - Returns: la ligne, créée ou mise à jour.
    @discardableResult
    public func setCrop(
        _ values: CropValues, on asset: MediaAsset, in cropContext: CropContext
    ) -> MediaCrop {
        let existing = asset.crops?.first { $0.context == cropContext }
        let crop =
            existing
            ?? {
                let fresh = MediaCrop(context: cropContext)
                fresh.asset = asset
                context.insert(fresh)
                return fresh
            }()

        crop.positionX = values.x
        crop.positionY = values.y
        crop.zoom = values.zoom
        crop.updatedAt = .now
        asset.updatedAt = .now
        return crop
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
