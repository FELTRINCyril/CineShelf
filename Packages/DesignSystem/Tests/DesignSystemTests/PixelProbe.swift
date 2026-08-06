import CoreGraphics
import SwiftUI

@testable import DesignSystem

// MARK: - La sonde de pixels
//
// **Ce que `RenderTests` ne savait pas faire, et qui a coûté quatre sessions.** Ses empreintes
// FNV distinguent deux rendus, ce qui suffit à prouver qu'une couleur suit le thème — mais
// **deux aplats de couleurs différentes ont deux empreintes différentes**, donc rien n'y
// distinguait une tuile qui montre une affiche d'une tuile qui n'en montre aucune. C'est
// exactement le défaut qui a laissé `MediaFill` charger par `AsyncImage` pendant quatre
// sessions : la porte de bloc était aveugle, et l'empreinte l'était aussi.
//
// Ce qu'il fallait est plus grossier et bien plus utile : **une image a de la variance, un
// aplat n'en a aucune**. Un fond uni rend un seul triplet de couleur ; une affiche, un
// dégradé, un liseré, un texte en rendent plusieurs.
//
// **Aucune permission n'est demandée**, et c'est tout l'intérêt : rendre une vue dans un
// bitmap ne passe par aucune API de capture d'écran. `screencapture` est refusé sur cette
// machine depuis quatre sessions ; `ImageRenderer` a toujours marché.

/// Ce qu'on retient d'un rendu : sa taille, une empreinte, et de quoi juger son contenu.
struct PixelStats {
    let width: Int
    let height: Int
    /// FNV-1a des octets. Distingue deux rendus, ne dit rien de leur contenu.
    let fingerprint: Int
    /// Combien de couleurs distinctes, échantillonnées sur une grille.
    let distinctColours: Int
    /// La variance moyenne de luminance, en unités de 0 à 255.
    let luminanceSpread: Double

    /// **Un aplat, au sens de cette sonde** : une seule couleur sur tout l'échantillon.
    ///
    /// C'est délibérément strict. Un dégradé, un liseré d'un pixel, une lettre — n'importe
    /// quoi de dessiné — fait sortir de ce cas. Ce qui reste dedans est ce qu'on veut
    /// attraper : la tuile qui n'a rien affiché du tout.
    var isUniform: Bool { distinctColours <= 1 }
}

/// Les statistiques d'une image, échantillonnée sur une grille de `steps × steps`.
///
/// Échantillonnée et non lue en entier : une tuile de 200 × 300 à l'échelle 2 fait 240 000
/// pixels, et les lire tous pour compter des couleurs distinctes coûte plus que tout le reste
/// de la suite réunie. Une grille de 32 × 32 suffit largement à séparer « uni » de « pas
/// uni », qui est la seule question posée.
func pixelStats(of image: CGImage, steps: Int = 32) -> PixelStats? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }

    // Redessiné dans un contexte à format connu : `image.dataProvider` rend les octets tels
    // que l'encodeur les a écrits — ordre des composantes, alignement de ligne et espace
    // colorimétrique compris — et les interpréter à l'aveugle donnerait des couleurs fausses.
    guard
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = context.data else { return nil }
    let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var colours: Set<UInt32> = []
    var luminances: [Double] = []
    var hash = 14_695_981_039_346_656_037 as UInt64

    for row in 0..<steps {
        for column in 0..<steps {
            let x = min(width - 1, column * width / steps)
            let y = min(height - 1, row * height / steps)
            let offset = (y * width + x) * 4
            let red = bytes[offset]
            let green = bytes[offset + 1]
            let blue = bytes[offset + 2]

            colours.insert(
                UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
            // Luminance perceptuelle approchée. Les coefficients exacts n'importent pas : on
            // compare des écarts entre rendus, pas des valeurs absolues.
            luminances.append(0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue))
            for byte in [red, green, blue] {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
    }

    let mean = luminances.reduce(0, +) / Double(luminances.count)
    let variance = luminances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(luminances.count)

    return PixelStats(
        width: width,
        height: height,
        fingerprint: Int(bitPattern: UInt(hash)),
        distinctColours: colours.count,
        luminanceSpread: variance.squareRoot())
}

// MARK: - Rendre une vue, et attendre qu'elle ait fini de charger

/// Rend une vue et rend ses statistiques de pixels.
///
/// - Parameters:
///   - content: la vue.
///   - scheme: l'apparence.
///   - width: la largeur imposée. La hauteur suit le contenu.
///   - settling: combien de temps laisser aux chargements asynchrones avant de rendre.
///
///     **C'est le paramètre qui change tout, et il mérite son explication.** `ImageRenderer`
///     rend **de façon synchrone** : un `.task` attaché à la vue n'a pas tourné au moment où
///     le bitmap est produit, donc un composant qui charge son image de façon asynchrone rend
///     forcément son état initial. Sans attente, « chargée », « en cours » et « en échec »
///     rendent tous le même placeholder — la porte serait aveugle exactement comme avant.
///
///     L'attente consiste à instancier le rendu **deux fois** : une première fois pour que la
///     vue existe et que ses tâches démarrent, puis, après avoir laissé tourner la boucle
///     d'exécution, une seconde qui capte l'état atteint. C'est possible parce que
///     `ImageRenderer` conserve son `content` entre deux lectures de `cgImage`.
/// - Returns: les statistiques du rendu, ou `nil` si le bitmap n'a pas pu être produit.
@MainActor
func renderStats(
    _ content: some View,
    scheme: ColorScheme = .dark,
    width: CGFloat = 200,
    settling: Duration? = nil
) async -> PixelStats? {
    let renderer = ImageRenderer(
        content:
            content
            .frame(width: width)
            .environment(\.colorScheme, scheme)
    )
    renderer.scale = 1

    if let settling {
        _ = renderer.cgImage
        try? await Task.sleep(for: settling)
    }
    guard let image = renderer.cgImage else { return nil }
    return pixelStats(of: image)
}
