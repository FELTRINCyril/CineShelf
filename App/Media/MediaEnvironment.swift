import CineShelfCore
import DesignSystem
import MediaKit
import SwiftData
import SwiftUI

/// Le cache de vignettes de l'app, et le pont vers `DesignSystem`.
///
/// `ThumbnailCache` est un `actor` de `MediaKit` : il ne connaît que des `UUID`
/// et rend des `CGImage`. `MediaThumbnail` attend une closure
/// `(URL) async throws -> Image`. C'est ici que les deux se rejoignent, et c'est
/// aussi ici que le cache est **instancié** — jusqu'au prompt 11 personne ne le
/// créait, donc rien n'était mis en cache.
@MainActor
@Observable
final class MediaEnvironment {

    let cache: ThumbnailCache

    /// L'échelle d'écran est lue par les vues et transmise au cache : générer
    /// une vignette @1x pour un écran @3x donne une image floue, et l'inverse
    /// gaspille de la mémoire.
    var displayScale: CGFloat = 2

    init(container: ModelContainer) {
        let provider = AssetDataProvider(modelContainer: container)
        cache = ThumbnailCache(source: { assetID in
            await provider.data(for: assetID)
        })
    }

    /// La closure que `DesignSystem` attend, branchée sur le cache.
    func imageLoader() -> ImageLoader {
        let cache = cache
        let scale = displayScale

        return ImageLoader { url in
            guard let decoded = AssetURL.decode(url) else {
                // Pas une URL d'asset : rien à charger ici. Les médias distants
                // arriveront au prompt 13b, avec leur propre chemin.
                throw MediaImageError.unsupportedURL
            }

            guard
                let image = await cache.thumbnail(
                    for: decoded.assetID,
                    targetSize: decoded.preset.targetSize,
                    scale: scale
                )
            else { throw MediaImageError.notFound }

            return Image(decorative: image, scale: scale)
        }
    }

    /// À appeler une fois l'app affichée : la pression mémoire n'a de sens que
    /// lorsqu'il y a quelque chose à purger.
    func startObservingMemoryPressure() {
        Task { await cache.startObservingMemoryPressure() }
    }
}

enum MediaImageError: Error {
    case unsupportedURL
    case notFound
}

/// Lit les octets d'un `MediaAsset` hors du thread principal.
///
/// `@ModelActor` plutôt qu'un accès direct au contexte principal : le décodage
/// d'une image de 2000 × 3000 ne doit pas bloquer l'interface, et
/// `ThumbnailCache` appelle sa source depuis son propre exécuteur.
@ModelActor
actor AssetDataProvider {

    func data(for assetID: UUID) -> Data? {
        var descriptor = FetchDescriptor<MediaAsset>(predicate: MediaQuery.asset(withID: assetID))
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.data
    }
}
