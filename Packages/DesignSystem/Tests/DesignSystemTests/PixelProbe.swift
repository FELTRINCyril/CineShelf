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
    await GraphicsWarmUp.once()

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
        return await settledStats(of: renderer)
    }
    guard let image = renderer.cgImage else { return nil }
    return pixelStats(of: image)
}

// MARK: - Attendre la fin du mouvement, plutôt qu'un délai fixe

/// Le pas entre deux relectures, une fois l'attente minimale écoulée.
private let stabilisationStep = Duration.milliseconds(50)

/// Le plafond de patience. Au-delà, on rend ce qu'on a — **un rendu qui n'aboutit jamais doit
/// faire rougir le test**, pas le faire attendre indéfiniment.
private let stabilisationLimit = 40

/// Relit le rendu jusqu'à ce qu'il cesse de changer.
///
/// **Pourquoi un délai fixe ne suffisait pas.** `settling` valait 250 ms, calées sur une mesure
/// locale — « le chargeur de sonde ne fait que décoder un PNG déjà en mémoire ». C'est vrai de
/// la machine de développement et faux d'un runner froid : mesuré le 2026-08-07, le catalogue
/// iOS est **rouge au premier passage et vert au second, sans changement de code**, avec
/// `IOSurfaceClientSetSurfaceNotify failed` dans le journal du passage rouge. La tuile chargée
/// rendait 2 couleurs au lieu des 9 attendues.
///
/// C'est la même famille que les seuils de performance calés en local que `CLAUDE.md` proscrit :
/// une durée constante n'est pas une condition, c'est un pari sur la vitesse de la machine. Et
/// un job instable rend le vert **non probant** — il coûte donc plus qu'il ne rapporte.
///
/// **Ce que cette boucle ne fait pas, et c'est le point délicat : elle n'attend pas un
/// résultat.** Elle attend que le rendu *cesse de bouger*, ce qui est vrai aussi bien d'une
/// image arrivée que d'une image qui n'arrivera jamais. Un `MediaFill` réellement cassé se
/// stabilise donc immédiatement sur son placeholder, et le test rougit comme il doit — c'est ce
/// qui distingue une stabilisation d'un « réessayer jusqu'à ce que ça passe », qui serait une
/// façon de rendre la porte aveugle.
@MainActor
private func settledStats(of renderer: ImageRenderer<some View>) async -> PixelStats? {
    guard var previous = renderer.cgImage.flatMap({ pixelStats(of: $0) }) else { return nil }
    for _ in 0..<stabilisationLimit {
        try? await Task.sleep(for: stabilisationStep)
        guard let current = renderer.cgImage.flatMap({ pixelStats(of: $0) }) else {
            return previous
        }
        if current.distinctColours == previous.distinctColours { return current }
        previous = current
    }
    return previous
}

/// Le préchauffage de la pile graphique, joué **une seule fois** par exécution de la suite.
///
/// Le premier `ImageRenderer` d'un processus initialise `IOSurface` et le service de rendu ; sur
/// un simulateur qui vient de démarrer, ce premier rendu peut aboutir à un bitmap dégradé sans
/// lever la moindre erreur. Le coût du remède est un rendu jetable de quelques millisecondes,
/// et il est payé par la première sonde qui s'exécute, quelle qu'elle soit.
///
/// **Même remède que le lancement iOS sous XCUITest**, préchauffé pour la même raison le
/// 2026-08-06 : chaque runner CI est froid, donc le cas rare en local est le cas nominal en CI.
@MainActor
enum GraphicsWarmUp {
    private static var done = false

    static func once() async {
        guard !done else { return }
        done = true
        let renderer = ImageRenderer(content: Color.black.frame(width: 8, height: 8))
        renderer.scale = 1
        _ = renderer.cgImage
        // Un tour de boucle après le premier rendu : c'est lui qui laisse le service graphique
        // finir de s'attacher, et il ne coûte rien quand tout est déjà chaud.
        try? await Task.sleep(for: .milliseconds(50))
        _ = renderer.cgImage
    }
}
