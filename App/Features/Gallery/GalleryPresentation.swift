import CineShelfCore
import DesignSystem
import Foundation

// MARK: - V3 · Ce que la galerie montre d'un média
//
// **Hors de la vue, et pour les deux raisons habituelles.** La première est la règle :
// l'arithmétique et le formatage ne vivent pas dans une `View`, et une `View` est
// `@MainActor` donc tout ce qu'on y écrit devient intestable depuis un test non isolé. La
// seconde est plus terre à terre — la visionneuse, la maçonnerie et la section de la fiche
// titre affichent **les mêmes** libellés, et trois copies auraient divergé au premier
// changement.

enum GalleryFormat {

    /// La proportion d'un média, largeur / hauteur, déjà bornée.
    ///
    /// **Bornée ici et pas seulement dans la maçonnerie**, parce que deux consommateurs
    /// utilisent cette valeur : `MasonryColumns` pour équilibrer les colonnes, et
    /// `GalleryThumb` pour poser son `aspectRatio`. Le second n'a aucune borne de son côté, et
    /// un `nan` y produit une hauteur indéfinie — donc une tuile invisible. Un média sans
    /// dimensions lues arrive en 0/0, ce qui est exactement ce cas : `MediaAsset.pixelWidth`
    /// et `pixelHeight` valent 0 par défaut, le schéma fermé l'exige.
    static func aspect(of asset: MediaAsset) -> Double {
        guard asset.pixelHeight > 0 else { return MasonryColumns.fallbackAspect }
        return MasonryColumns.clamped(
            aspect: Double(asset.pixelWidth) / Double(asset.pixelHeight))
    }

    /// Le modèle de vignette d'un média.
    ///
    /// **Aucun recadrage** — `crop: .neutral` par défaut du modèle — et c'est le sujet de la
    /// galerie : elle montre l'image **entière**, à sa proportion propre. Un recadrage y
    /// afficherait le cadrage choisi pour une carte, donc mentirait sur ce qu'on est en train
    /// de recadrer. C'est l'inverse de la grille des titres, qui affiche des jaquettes dans un
    /// cadre imposé.
    static func thumbnail(
        for asset: MediaAsset, preset: AssetPreset, caption: String? = nil
    ) -> MediaThumbnailModel {
        MediaThumbnailModel(
            id: asset.id.uuidString,
            imageURL: AssetURL.url(for: asset.id, preset: preset),
            blurHash: asset.blurHash,
            aspect: aspect(of: asset),
            caption: caption)
    }

    // MARK: Libellés

    /// La source d'un média, déduite de sa pièce jointe.
    ///
    /// `nil` n'existe pas : un média sans pièce jointe **est** un orphelin, et c'est
    /// précisément la quatrième source. C'est aussi la seule lecture de `attachments` qui soit
    /// sûre — en Swift, sur un objet déjà chargé. En `#Predicate`, la même expression tue le
    /// processus (`L1 bis`).
    static func source(of asset: MediaAsset) -> MediaSource {
        guard let attachment = asset.attachments?.first else { return .orphan }
        if attachment.title != nil { return .title }
        if attachment.person != nil { return .person }
        if attachment.collection != nil { return .collection }
        return .orphan
    }

    static func label(for source: MediaSource) -> String {
        switch source {
        case .title: "Titres"
        case .person: "Personnes"
        case .collection: "Collections"
        case .orphan: "Sans rattachement"
        }
    }

    static func label(for slot: MediaSlot) -> String {
        switch slot {
        case .primary: "affiche"
        case .portrait: "portrait"
        case .backdrop: "image large"
        case .gallery: "galerie"
        }
    }

    /// Le nom du propriétaire, tel que la visionneuse l'affiche — bloc `6c`,
    /// « Oppenheimer · affiche · 2000 × 3000 ».
    static func owner(of asset: MediaAsset) -> String? {
        guard let attachment = asset.attachments?.first else { return nil }
        if let title = attachment.title { return title.name }
        if let person = attachment.person { return person.displayName }
        if let collection = attachment.collection { return collection.name }
        return nil
    }

    /// La ligne de description d'une image : propriétaire, emplacement, dimensions.
    ///
    /// Les parties absentes sont omises plutôt que remplacées par un tiret : un média orphelin
    /// dont on ignore les dimensions doit afficher « Sans rattachement », pas « — · — ».
    static func caption(of asset: MediaAsset) -> String {
        var parts: [String] = []
        parts.append(owner(of: asset) ?? label(for: source(of: asset)))
        if let attachment = asset.attachments?.first {
            parts.append(label(for: attachment.slot))
        }
        if let size = dimensions(of: asset) {
            parts.append(size)
        }
        return parts.joined(separator: " · ")
    }

    /// « 2000 × 3000 », ou `nil` si les dimensions ne sont pas connues.
    ///
    /// **Le `×` est un vrai signe multiplication et pas un `x`** : c'est du texte d'interface
    /// lu par un humain, pas un identifiant. La règle ASCII du dépôt vise le code, les commits
    /// et les journaux.
    static func dimensions(of asset: MediaAsset) -> String? {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return nil }
        return "\(asset.pixelWidth) × \(asset.pixelHeight)"
    }

    /// « 6 images · 18,4 Mo » — la ligne de gauche de la barre de sélection, bloc `6f`.
    static func selectionSummary(_ assets: [MediaAsset]) -> String {
        let bytes = assets.reduce(0) { $0 + $1.byteSize }
        let count = assets.count
        let images = count == 1 ? "1 image" : "\(count) images"
        guard bytes > 0 else { return images }
        return "\(images) · \(byteCount(bytes))"
    }

    /// « Image 14 sur 47 » — le compteur du mode immersif, bloc `6d`.
    static func position(_ index: Int, of total: Int) -> String {
        "Image \(index + 1) sur \(total)"
    }

    /// « 12 / 47 » — le compteur compact de la visionneuse, bloc `6c`.
    static func counter(_ index: Int, of total: Int) -> String {
        "\(index + 1) / \(total)"
    }

    static func byteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - L'ordre d'affichage, hors de la vue

enum GalleryOrder {

    /// Les médias retenus, mélangés si une graine est posée.
    ///
    /// - Parameters:
    ///   - assets: tout ce que le `@Query` a rendu, déjà trié du plus récent au plus ancien.
    ///   - restriction: les identifiants du filtre de source, ou `nil` pour aucune
    ///     restriction.
    ///   - filter: porte la graine. **`shuffled` est appliqué après la restriction**, et
    ///     l'ordre des deux compte : mélanger d'abord puis filtrer donnerait un ordre différent
    ///     selon le filtre à graine égale, donc un « même mélange » qui n'en serait pas un.
    /// - Returns: les médias à afficher, dans l'ordre.
    static func arrange(
        _ assets: [MediaAsset], restrictedTo restriction: Set<UUID>?, filter: GalleryFilter
    ) -> [MediaAsset] {
        let kept = restriction.map { ids in assets.filter { ids.contains($0.id) } } ?? assets
        return filter.shuffled(kept)
    }
}
