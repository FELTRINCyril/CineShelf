import CoreGraphics
import ImageIO
import SwiftUI
import Testing

@testable import DesignSystem

// MARK: - Ce que l'œil couvrait, et que personne ne regardait
//
// **Le cas qui décide.** Une tuile dont l'image ne s'affiche pas rend un aplat ; une tuile qui
// affiche son affiche rend des dizaines de couleurs. `MediaFill` a chargé par `AsyncImage`
// pendant **quatre sessions** sans qu'une seule affiche apparaisse, et rien ne l'a vu : les
// tests d'empreinte distinguaient deux rendus sans jamais demander s'il y avait quelque chose
// dedans, et le catalogue montrait des échantillons à `imageURL: nil`, donc un aplat attendu.
//
// Ces tests posent la question manquante : **est-ce que ça rend autre chose que du vide ?**
//
// **Ils ne jugent pas la beauté**, et ne le prétendent pas. Ce qu'ils prouvent est plus
// modeste et jamais acquis : que le pixel n'est pas uniforme là où une image est attendue, et
// que deux états censés se distinguer se distinguent pour de vrai.
//
// **Ils tournent dans la cible du catalogue**, seule à compiler `Colors.xcassets` — même
// condition que `RenderTests`, et pour la même raison.

// MARK: - Le chargeur de test
//
// Il rend une image **réellement dessinée**, par le même générateur que le catalogue et les
// données de démonstration. Un `Image(systemName:)` aurait suffi à faire de la variance, et
// c'est justement ce qu'il ne faut pas : on veut le chemin que l'app emprunte.

private func decodedSample(seed: Int, size: (width: Int, height: Int)) -> Image? {
    guard let data = SampleArtwork.png(for: "sonde \(seed)", seed: seed, size: size),
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    return Image(decorative: image, scale: 1)
}

/// Un chargeur qui aboutit, un qui n'aboutit jamais, un qui échoue.
private enum Probe {
    static let loads = ImageLoader { _ in
        guard let image = decodedSample(seed: 140, size: (width: 200, height: 300)) else {
            throw ProbeError.undrawable
        }
        return image
    }
    static let never = ImageLoader { _ in
        try await Task.sleep(for: .seconds(3_600))
        throw CancellationError()
    }
    static let fails = ImageLoader { _ in throw ProbeError.refused }

    enum ProbeError: Error { case refused, undrawable }
}

private let sampleURL = URL(string: "cineshelf-asset://probe?preset=card")

/// Le temps laissé aux `.task` d'aboutir avant de capter le rendu.
///
/// 250 ms : le chargeur de sonde ne fait que décoder un PNG déjà en mémoire, donc il n'a
/// besoin que d'un tour de boucle. La marge est là pour le runner, pas pour le travail.
private let settling = Duration.milliseconds(250)

// MARK: - Contrôle négatif — la sonde sait-elle ce qu'elle prétend savoir ?

@MainActor
@Test("La sonde distingue un aplat d'un contenu", .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason))
func probeSeparatesFlatFromDrawn() async throws {
    // **Sans ce contrôle, toutes les assertions de non-uniformité seraient sans valeur** :
    // elles passeraient tout aussi bien si `isUniform` était toujours faux.
    let flat = try #require(await renderStats(Color.bgSurface.frame(height: 80)))
    #expect(flat.isUniform, "Un aplat doit être uniforme, sinon la sonde ne mesure rien")
    #expect(flat.distinctColours == 1)

    let drawn = try #require(
        await renderStats(Text("CineShelf").font(Typo.title1(.large)).frame(height: 80)))
    #expect(!drawn.isUniform)
    #expect(drawn.luminanceSpread > 0)
}

// MARK: - Le cas qui décide : une tuile avec image n'est pas un aplat

@MainActor
@Test(
    "Une tuile chargée n'est pas uniforme, une tuile sans image l'est",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func loadedTileIsNotFlat() async throws {
    // C'est **le** test qui aurait attrapé les quatre sessions d'affiches invisibles.
    let loaded = try #require(
        await renderStats(
            MediaFill(
                imageURL: sampleURL, crop: .neutral, targetAspect: Ratio.poster,
                background: .bgSurface
            )
            .frame(width: 140, height: 210)
            .environment(\.imageLoader, Probe.loads),
            settling: settling))

    #expect(
        !loaded.isUniform,
        """
        Une tuile dont le chargeur aboutit rend un aplat : l'image n'arrive pas jusqu'au pixel. \
        C'est le défaut de MediaFill qui a tenu quatre sessions.
        """)
    // **Le seuil compte, et la preuve d'échec l'a montré.** Avec la faute historique
    // réinjectée — `MediaFill` qui n'atteint pas son chargeur —, la tuile rend **deux**
    // couleurs et non une : le symbole d'échec en dessine une seconde. `isUniform` seul ne
    // mordait donc pas ; c'est ce seuil qui attrape le défaut.
    #expect(loaded.distinctColours > 8, "Une affiche dessinée porte un dégradé, pas deux teintes")

    // Le témoin : sans URL du tout, la même tuile est un aplat. Les deux assertions ne valent
    // que l'une avec l'autre.
    let empty = try #require(
        await renderStats(
            MediaFill(
                imageURL: nil, crop: .neutral, targetAspect: Ratio.poster, background: .bgSurface
            )
            .frame(width: 140, height: 210)
            .environment(\.imageLoader, Probe.loads),
            settling: settling))
    #expect(empty.distinctColours < loaded.distinctColours)
}

// MARK: - Les quatre états de chargement de la planche I2, distincts deux à deux

@MainActor
@Test(
    "Les quatre états de chargement rendent quatre choses différentes",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func fourLoadStatesAreDistinct() async throws {
    func tile(_ loader: ImageLoader, url: URL?, blurHash: String?) -> some View {
        MediaFill(
            imageURL: url, blurHash: blurHash, crop: .neutral, targetAspect: Ratio.poster,
            background: .bgSurface
        )
        .frame(width: 140, height: 210)
        .environment(\.imageLoader, loader)
    }

    func stats(_ loader: ImageLoader, url: URL?, blurHash: String? = nil) async -> PixelStats? {
        await renderStats(tile(loader, url: url, blurHash: blurHash), settling: settling)
    }

    let states = [
        ("chargée", try #require(await stats(Probe.loads, url: sampleURL))),
        ("en cours", try #require(await stats(Probe.never, url: sampleURL, blurHash: "L6PZfSjE.A"))),
        ("en échec", try #require(await stats(Probe.fails, url: sampleURL))),
        ("sans image", try #require(await stats(Probe.loads, url: nil)))
    ]

    // **Deux à deux**, et c'est la seule formulation utile : c'est la paire « en cours » /
    // « en échec » qui était indistinguable avant `catalogue-images`, et une assertion sur
    // l'ensemble n'aurait pas dit laquelle.
    for (leftName, left) in states {
        for (rightName, right) in states where leftName < rightName {
            #expect(
                left.fingerprint != right.fingerprint,
                "« \(leftName) » et « \(rightName) » rendent exactement le même pixel")
        }
    }
}

// MARK: - Le liseré de sélection est réellement dessiné

@MainActor
@Test(
    "Une vignette sélectionnée ne rend pas comme une vignette au repos",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func selectionRingIsDrawn() async throws {
    let model = MediaThumbnailModel(id: "s", aspect: Ratio.poster)
    let plain = try #require(await renderStats(GalleryThumb(model, width: 120) {}, width: 140))
    let selected = try #require(
        await renderStats(GalleryThumb(model, width: 120, isSelected: true) {}, width: 140))

    #expect(plain.fingerprint != selected.fingerprint, "Le liseré de sélection n'est pas rendu")
    // Le liseré et la pastille ajoutent de l'ambre sur un fond uni : la sélection porte donc
    // **plus** de couleurs distinctes que le repos, jamais moins.
    #expect(selected.distinctColours > plain.distinctColours)
}

// MARK: - La maçonnerie coule bien en colonnes indépendantes

@MainActor
@Test(
    "Les colonnes d'une maçonnerie n'ont pas toutes la même hauteur",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func masonryColumnsHaveDifferentHeights() async throws {
    // **C'est ce qui sépare une maçonnerie d'une grille**, et rien d'autre ne le montre : à
    // ratios égaux les deux sont indistinguables, et un `LazyVGrid` posé par erreur passerait
    // tous les tests de `MasonryColumns`, qui ne teste que la répartition.
    let ratios = [2.4, 0.46, 1.0, 16.0 / 9, 2.0 / 3, 0.5]
    let items = ratios.enumerated().map {
        MediaThumbnailModel(id: "m\($0.offset)", aspect: $0.element)
    }

    let grid = MasonryGrid(items, cardWidth: PosterScale.m.width, aspect: \.aspect) { thumb in
        GalleryThumb(thumb) {}
    }
    .breakpoint(forWidth: 400)
    .background(Color.bgCanvas)

    let image = try #require(await renderedImage(grid, width: 400))
    let edges = bottomEdges(of: image, columns: 2)

    #expect(edges.count == 2)
    #expect(
        edges[0] != edges[1],
        """
        Les deux colonnes se terminent à la même hauteur : la grille aligne ses lignes, \
        donc ce n'est pas une maçonnerie.
        """)
}

// MARK: - Aides

@MainActor
private func renderedImage(_ content: some View, width: CGFloat) async -> CGImage? {
    let renderer = ImageRenderer(
        content: content.frame(width: width).environment(\.colorScheme, .dark))
    renderer.scale = 1
    _ = renderer.cgImage
    try? await Task.sleep(for: settling)
    return renderer.cgImage
}

/// Pour chaque bande verticale, la dernière rangée qui porte quelque chose.
///
/// « Quelque chose » se mesure par rapport au **coin haut gauche**, qui est du fond par
/// construction : on cherche la rangée la plus basse dont le pixel diffère de lui. Une bande
/// entièrement vide rend 0.
private func bottomEdges(of image: CGImage, columns: Int) -> [Int] {
    let width = image.width
    let height = image.height
    guard
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return [] }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = context.data else { return [] }
    let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    func pixel(_ x: Int, _ y: Int) -> UInt32 {
        let offset = (y * width + x) * 4
        return UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2])
    }

    let background = pixel(0, 0)
    return (0..<columns).map { column in
        let x = min(width - 1, (column * 2 + 1) * width / (columns * 2))
        for y in stride(from: height - 1, through: 0, by: -1) where pixel(x, y) != background {
            return y
        }
        return 0
    }
}
