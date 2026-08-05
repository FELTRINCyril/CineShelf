import DesignSystem
import SwiftUI

// MARK: - catalogue-images · Le chargeur du catalogue, et les trois états
//
// **Ce que cette tâche répare, et ce n'est pas un manque de confort.** Les échantillons du
// catalogue avaient `imageURL: nil`. Une tuile **sans** image et une tuile dont le chargement
// **échoue** rendaient donc le même aplat, et la porte de bloc était aveugle sur le seul
// composant qui compte dans un catalogue de films. C'est ce qui a laissé `MediaFill` charger
// par `AsyncImage` pendant quatre sessions sans qu'une seule affiche s'affiche.
//
// **Les trois états doivent se distinguer à l'œil**, sinon la porte reste aveugle sur deux
// d'entre eux :
//
// | État | Ce que le chargeur fait | Ce qu'on doit voir |
// |---|---|---|
// | chargée | rend l'image dessinée | l'affiche |
// | en cours | n'aboutit jamais | le blurhash, ou l'aplat s'il n'y en a pas |
// | en échec | lève | l'aplat **et un symbole** |
//
// Le troisième a demandé une correction de `MediaFill` : il n'avait aucun rendu d'échec, donc
// « en cours » et « en échec » étaient indistinguables. Voir son en-tête.
//
// **L'URL porte l'état**, ce qui permet à un seul chargeur de servir les trois : le catalogue
// n'a pas de magasin, donc pas de vrai identifiant d'asset à décoder. La convention est
// locale au catalogue et ne ressemble volontairement pas à `cineshelf-asset://` — confondre
// les deux serait recréer le piège d'un cran plus haut.

/// L'état qu'un échantillon doit exercer.
enum SampleLoadState: String, CaseIterable, Identifiable {
    case loaded
    case loading
    case failing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loaded: "chargée"
        case .loading: "chargement en cours"
        case .failing: "chargement en échec"
        }
    }
}

enum SampleImageURL {
    static let scheme = "catalog-sample"

    /// Ce qu'une URL d'échantillon porte.
    ///
    /// Valeur nommée et non tuple à trois membres : c'est la convention du dépôt, comme
    /// `CropValues` et `PosterContext.Scales`, et `large_tuple` la fait respecter.
    struct Sample {
        let state: SampleLoadState
        let seed: Int
        /// La proportion à dessiner. `nil` donne le 2:3 d'une affiche.
        let aspect: Double?
    }

    /// - Parameters:
    ///   - state: l'état à exercer.
    ///   - seed: la graine du dégradé. Des graines différentes donnent des images différentes,
    ///     ce qui rend une grille lisible plutôt qu'un damier uniforme.
    ///   - aspect: la proportion de l'image **dessinée**. `nil` donne le 2:3 d'une affiche.
    ///
    ///     **Ajouté par `V3`, et ce n'est pas cosmétique.** La planche de maçonnerie juge des
    ///     ratios mêlés : si toutes les images dessinées sont des 2:3 recadrées dans des cadres
    ///     21:9, on valide un remplissage et non une maçonnerie. Le cas nul à éviter était
    ///     ici « toutes les images ont la même forme ».
    /// - Returns: l'URL, ou `nil` si `URLComponents` refuse — ce qui n'arrive pas avec un hôte
    ///   issu d'un `rawValue` clos, mais un `!` serait un force unwrap.
    static func url(_ state: SampleLoadState, seed: Int, aspect: Double? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = state.rawValue
        components.queryItems = [
            URLQueryItem(name: "seed", value: String(seed)),
            aspect.map { URLQueryItem(name: "aspect", value: String($0)) }
        ].compactMap { $0 }
        return components.url
    }

    static func decode(_ url: URL) -> Sample? {
        guard url.scheme == scheme,
            let host = url.host(),
            let state = SampleLoadState(rawValue: host)
        else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let seed = items?.first { $0.name == "seed" }?.value.flatMap(Int.init) ?? 0
        let aspect = items?.first { $0.name == "aspect" }?.value.flatMap(Double.init)
        return Sample(state: state, seed: seed, aspect: aspect)
    }
}

extension ImageLoader {

    /// Le chargeur du catalogue : dessine, retarde, ou lève, selon l'URL.
    ///
    /// **Un délai avant de rendre l'image chargée, et il est délibéré.** Sans lui, l'image
    /// apparaît au premier frame et on ne voit jamais le blurhash ni la transition — donc on
    /// ne peut pas juger le seul moment où un défilement se remarque. 400 ms est assez pour
    /// voir, assez court pour ne pas gêner.
    static func catalogSamples(delay: Duration = .milliseconds(400)) -> ImageLoader {
        ImageLoader { url in
            guard let decoded = SampleImageURL.decode(url) else {
                throw SampleLoadError.unsupported
            }

            switch decoded.state {
            case .loading:
                // N'aboutit jamais : c'est l'état, pas un échec. Annulé quand la vue part.
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            case .failing:
                try await Task.sleep(for: delay)
                throw SampleLoadError.refused
            case .loaded:
                try await Task.sleep(for: delay)
                guard
                    let data = SampleArtwork.png(
                        for: "Échantillon \(decoded.seed)", seed: decoded.seed,
                        size: drawnSize(aspect: decoded.aspect)),
                    let image = PlatformImage(data: data)
                else { throw SampleLoadError.refused }
                return Image(platformImage: image)
            }
        }
    }
}

/// La taille à dessiner pour une proportion donnée.
///
/// Largeur fixe et hauteur dérivée : c'est la même convention que l'échelle d'affiche, où le
/// cran est une largeur et le ratio donne la hauteur. Bornée à 4000 pt de haut pour qu'un
/// ratio dégénéré n'aille pas allouer un bitmap démesuré — un 9:21 fait déjà 1400.
private func drawnSize(aspect: Double?) -> (width: Int, height: Int) {
    guard let aspect, aspect > 0, aspect.isFinite else { return SampleArtwork.size }
    return (width: 600, height: min(4_000, max(1, Int(600 / aspect))))
}

enum SampleLoadError: Error {
    case unsupported
    case refused
}

// MARK: - Le pont vers `Image`

#if canImport(AppKit)
    typealias PlatformImage = NSImage
#else
    typealias PlatformImage = UIImage
#endif

extension Image {
    /// `Image` n'a pas d'initialiseur multiplateforme depuis des octets.
    fileprivate init(platformImage: PlatformImage) {
        #if canImport(AppKit)
            self.init(nsImage: platformImage)
        #else
            self.init(uiImage: platformImage)
        #endif
    }
}

// MARK: - Les échantillons, avec leurs images

extension PosterCardModel {

    /// Le même échantillon, doté d'une URL qui exerce cet état.
    ///
    /// Les échantillons de `DesignSystem` restent sans image : ils servent aux previews du
    /// package, qui n'ont pas de chargeur injecté. C'est le catalogue qui les habille, parce
    /// que c'est lui qui porte la porte d'acceptation.
    func exercising(_ state: SampleLoadState, seed: Int) -> PosterCardModel {
        PosterCardModel(
            id: "\(id)-\(state.rawValue)",
            title: title,
            kind: kind,
            meta: meta,
            rating: rating,
            imageURL: SampleImageURL.url(state, seed: seed),
            // Un blurhash **seulement** sur les états qui n'ont pas encore d'image : c'est ce
            // qui rend « en cours » distinguable de « en échec », le second n'ayant aucun
            // placeholder coloré à montrer.
            blurHash: state == .loading ? Self.sampleBlurHash : blurHash,
            crop: crop,
            isFavorite: isFavorite,
            isInWatchlist: isInWatchlist,
            isWatched: isWatched,
            isPrivate: isPrivate,
            isArchived: isArchived
        )
    }

    /// Un blurhash réel, celui des données de démonstration.
    static let sampleBlurHash = "L6PZfSjE.A"

    /// Les dix échantillons, tous chargés, avec des images **différentes**.
    ///
    /// Des graines distinctes exprès : dix fois la même image ferait un damier uniforme, où un
    /// défaut de recadrage ou de cadre ne se verrait pas.
    static var artworkSamples: [PosterCardModel] {
        samples.enumerated().map { $0.element.exercising(.loaded, seed: $0.offset * 37 + 11) }
    }

    /// L'échantillon unique, avec son image.
    static var artworkSample: PosterCardModel { sample.exercising(.loaded, seed: 140) }

    /// **Les personnes n'en ont pas, et c'est le design qui le dit.** Le §11 du handoff :
    /// « Portraits de personnes : aucun. » `PersonTile` se replie sur les initiales, et
    /// l'habiller d'une image ici ferait valider un rendu que l'app ne produira jamais.
    static var artworkPeople: [PosterCardModel] { people }
}

// MARK: - Les vignettes de galerie, avec de vraies images à leur propre ratio

extension MediaThumbnailModel {

    /// Les sept ratios de `galleryRatios`, dotés d'images **dessinées à ce ratio**.
    ///
    /// Les échantillons du package portent une URL `https://exemple.test/…` que le chargeur du
    /// catalogue refuse : rendus tels quels, les sept auraient affiché le symbole d'échec, et
    /// la planche de maçonnerie aurait validé la forme d'une grille d'erreurs. C'est le même
    /// motif que `catalogue-images` a corrigé sur les affiches, et il se reproduit à chaque
    /// composant neuf tant qu'on ne le vérifie pas.
    static var galleryArtwork: [MediaThumbnailModel] {
        galleryRatios.enumerated().map { offset, model in
            MediaThumbnailModel(
                id: model.id,
                imageURL: SampleImageURL.url(
                    .loaded, seed: offset * 53 + 7, aspect: model.aspect),
                blurHash: model.blurHash,
                aspect: model.aspect,
                caption: model.caption,
                crop: model.crop)
        }
    }
}
