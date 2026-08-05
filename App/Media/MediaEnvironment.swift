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
    ///
    /// **Le 2 n'est qu'un point de départ, plus un aveu.** Jusqu'à `L5` personne n'écrivait
    /// cette propriété (écart connu) : toutes les vignettes sortaient en @2x, floues sur
    /// une dalle @3x et deux fois trop grosses sur un écran @1x. `.displayScale(_:)` la
    /// renseigne depuis l'environnement SwiftUI, qui est le seul à la connaître.
    var displayScale: CGFloat = 2 {
        didSet {
            // Changer d'échelle change la clé de cache, donc rien n'est invalidé : les
            // vignettes de l'ancienne échelle restent valides et seront purgées par la
            // limite disque comme les autres.
            guard displayScale != oldValue else { return }
            Task { await cache.cancelAllPrefetches() }
        }
    }

    init(container: ModelContainer) {
        let provider = AssetDataProvider(modelContainer: container)
        cache = ThumbnailCache(source: { assetID in
            await provider.data(for: assetID)
        })
    }

    /// La closure que `DesignSystem` attend, branchée sur le cache.
    ///
    /// **L'échelle est lue à l'appel, pas capturée à la construction.** Une capture aurait
    /// figé la valeur du moment où la scène a évalué son corps : déplacer la fenêtre d'un
    /// écran Retina vers un écran @1x aurait continué à produire du @2x jusqu'à la
    /// prochaine invalidation, et rien ne l'aurait signalé.
    func imageLoader() -> ImageLoader {
        let cache = cache

        return ImageLoader { [weak self] url in
            let scale = await MainActor.run { self?.displayScale ?? 2 }

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

    /// Prépare les vignettes des médias qui vont entrer à l'écran.
    ///
    /// `assetIDs` est déjà la tranche calculée par `PrefetchWindow` : cette méthode ne
    /// décide rien, elle transporte. C'est la vue qui sait où elle a défilé, et c'est le
    /// travail de `V3` et `V6` de l'appeler — `L5` ne livre que le chemin.
    func prefetch(_ assetIDs: [UUID], context: AssetPreset) {
        let scale = displayScale
        Task {
            await cache.prefetch(assetIDs, targetSize: context.targetSize, scale: scale)
        }
    }

    func cancelPrefetch(_ assetIDs: [UUID], context: AssetPreset) {
        let scale = displayScale
        Task {
            await cache.cancelPrefetch(assetIDs, targetSize: context.targetSize, scale: scale)
        }
    }
}

extension View {

    /// Renseigne l'échelle d'écran du cache de vignettes depuis l'environnement.
    ///
    /// Un modificateur plutôt qu'une lecture dans `RootView` : l'échelle est une donnée
    /// d'environnement SwiftUI, donc seule une vue peut la lire, et la poser au plus haut
    /// évite qu'une sous-vue en propose une autre.
    func displayScale(feeding media: MediaEnvironment) -> some View {
        modifier(DisplayScaleFeed(media: media))
    }
}

private struct DisplayScaleFeed: ViewModifier {
    let media: MediaEnvironment

    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        content
            .onAppear { media.displayScale = displayScale }
            .onChange(of: displayScale) { _, new in media.displayScale = new }
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
