import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - catalogue-images · Des jaquettes dessinées par code
//
// **Pourquoi ce générateur vit ici, et pas seulement dans l'app.** `DesignSystem` porte déjà
// tout le matériel d'échantillon du dépôt — `PosterCardModel.samples`, `ImageLoader.stubbed`,
// `BlurHashPreview`. Il manquait la seule chose qui compte dans un catalogue de films : une
// **image**. Le générateur était dans `App/DemoData`, invisible depuis le catalogue, et c'est
// une des raisons pour lesquelles la porte de bloc a été aveugle quatre sessions.
//
// **Dessiné, jamais embarqué.** Aucun fichier binaire dans le dépôt : pas de licence à
// vérifier, pas de poids qui grossit, et une image déterministe — la même graine donne le
// même pixel, donc deux captures d'écran se comparent.
//
// **Il remplace `App/DemoData/PosterArtwork`**, qui faisait exactement ça pour les données de
// démonstration. Un seul générateur pour l'app et pour le catalogue : deux auraient divergé,
// et le catalogue aurait fini par valider des images que l'app ne produit pas.

// `no_literal_color` interdit les couleurs littérales hors du design system — nous y sommes,
// et de toute façon ces valeurs ne teignent aucune vue : elles remplissent le bitmap d'un
// fichier PNG. Un jeu de couleurs sémantique n'aurait rien à dire ici.

/// Des jaquettes générées : dégradé déterministe et repère central.
public enum SampleArtwork {

    /// 2:3 exact, la proportion d'une affiche.
    public static let size = (width: 600, height: 900)

    /// Un PNG déterministe pour ce nom et cette graine.
    ///
    /// - Returns: `nil` si CoreGraphics ne peut pas produire le contexte, ce qui n'arrive pas
    ///   en pratique — mais un `!` serait un force unwrap, et l'appelant a un repli.
    public static func png(
        for title: String, seed: Int, size: (width: Int, height: Int) = size
    ) -> Data? {
        guard
            let context = CGContext(
                data: nil,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        let bounds = CGSize(width: size.width, height: size.height)
        drawGradient(in: context, size: bounds, hue: seed)
        drawMark(of: title, in: context, size: bounds)

        guard let image = context.makeImage() else { return nil }
        return encodePNG(image)
    }

    private static func drawGradient(in context: CGContext, size: CGSize, hue: Int) {
        let base = CGFloat(hue % 360) / 360
        let colors =
            [
                CGColor(red: base, green: 0.35, blue: 0.55, alpha: 1),
                CGColor(red: base * 0.4, green: 0.12, blue: 0.28, alpha: 1)
            ] as CFArray

        guard
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
        else { return }

        context.drawLinearGradient(
            gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
    }

    /// Un repère central, et **pas du texte**.
    ///
    /// CoreText demanderait une police, or ce générateur tourne avant tout enregistrement de
    /// police — y compris dans un test, où `DesignSystemFonts.register()` n'a pas été appelé.
    /// Deux barres et un disque suffisent à juger un cadrage, un recadrage et une grille.
    private static func drawMark(of title: String, in context: CGContext, size: CGSize) {
        let letters =
            title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .count

        let side = size.width * 0.42
        let rect = CGRect(
            x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
        context.fillEllipse(in: rect)

        let barHeight = side * 0.12
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
        context.fill(
            CGRect(
                x: rect.minX + side * 0.2, y: rect.midY + barHeight * 0.4,
                width: side * 0.6 * CGFloat(max(1, letters)) / 2, height: barHeight))
        context.fill(
            CGRect(
                x: rect.minX + side * 0.2, y: rect.midY - barHeight * 1.6,
                width: side * 0.35, height: barHeight))
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

// MARK: - Aléa reproductible

/// Générateur déterministe : deux exécutions donnent le même catalogue.
///
/// C'est ce qui rend les mesures de performance comparables d'une session à l'autre, et les
/// captures d'écran stables.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { state = seed == 0 ? 0x4d59_5df4_d0f3_3173 : seed }

    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    public mutating func next(upTo bound: Int) -> Int {
        bound <= 0 ? 0 : Int(next() % UInt64(bound))
    }
}
