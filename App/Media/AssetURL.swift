import CineShelfCore
import Foundation

/// La convention d'URL qui relie le design system au cache de vignettes.
///
/// `MediaThumbnail` et `PosterCard` ne connaissent qu'une `URL?` — c'est
/// volontaire : leur donner un `MediaAsset` ferait dépendre `DesignSystem` du
/// modèle métier. `ThumbnailCache`, lui, ne connaît que des `UUID`. Cette URL
/// synthétique porte l'un jusqu'à l'autre :
///
///     cineshelf-asset://<uuid>?preset=card
///
/// Elle n'est jamais résolue par le réseau. `MediaImageLoader` la décode et
/// appelle le cache. Toute URL d'un autre schéma est chargée normalement, ce qui
/// laisse la porte ouverte aux médias distants (`MediaAsset.externalURLString`).
enum AssetURL {

    static let scheme = "cineshelf-asset"

    static func url(for assetID: UUID, preset: AssetPreset) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = assetID.uuidString.lowercased()
        components.queryItems = [URLQueryItem(name: "preset", value: preset.rawValue)]
        // Le `host` est un UUID et le preset une valeur close : la construction
        // ne peut pas échouer, mais on ne force pas pour autant.
        return components.url ?? URL(fileURLWithPath: "/dev/null")
    }

    /// Décode une URL produite par `url(for:preset:)`.
    static func decode(_ url: URL) -> (assetID: UUID, preset: AssetPreset)? {
        guard url.scheme == scheme,
            let host = url.host(),
            let assetID = UUID(uuidString: host)
        else { return nil }

        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "preset" }?
            .value

        return (assetID, raw.flatMap(AssetPreset.init(rawValue:)) ?? .card)
    }
}

/// Le gabarit demandé, exprimé côté app.
///
/// Double volontaire de `ThumbnailPreset` : `AssetURL` est lu par la couche vue,
/// qui n'a pas à importer `MediaKit`. La correspondance est faite une fois, dans
/// `MediaImageLoader`.
enum AssetPreset: String, Sendable {
    case thumb
    case card
    case hero

    /// La taille en points visée. Le cache arrondit ensuite à son propre preset.
    var targetSize: CGSize {
        switch self {
        case .thumb: CGSize(width: 104, height: 156)
        case .card: CGSize(width: 196, height: 294)
        case .hero: CGSize(width: 1200, height: 675)
        }
    }
}
