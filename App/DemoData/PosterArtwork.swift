#if DEBUG

    import CoreGraphics
    import Foundation
    import ImageIO
    import UniformTypeIdentifiers

    // MARK: - Jaquettes dessinées

    // `no_literal_color` interdit les couleurs littérales hors du design system.
    // La règle vise le **style de l'interface** ; ici on synthétise les pixels
    // d'un fichier PNG, ce qui n'est pas la même chose : ces valeurs ne teintent
    // aucune vue, elles remplissent un bitmap de données de démonstration. Aller
    // les chercher dans le design system reviendrait à faire dépendre le
    // générateur d'un jeu de couleurs sémantique, qui n'a rien à dire ici.
    // swiftlint:disable no_literal_color

    /// Des jaquettes générées : dégradé déterministe et initiales du titre.
    enum PosterArtwork {

        static let size = (width: 600, height: 900)

        static func png(for title: String, seed: Int) -> Data? {
            let width = size.width
            let height = size.height

            guard
                let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return nil }

            drawGradient(in: context, size: CGSize(width: width, height: height), hue: seed)
            drawInitials(of: title, in: context, size: CGSize(width: width, height: height))

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
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 1]
                )
            else { return }

            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        /// Les initiales, en aplat clair. Pas de police custom : le générateur
        /// tourne avant tout enregistrement de police.
        private static func drawInitials(of title: String, in context: CGContext, size: CGSize) {
            let initials =
                title
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)
                .map(String.init)
                .joined()
                .uppercased()

            guard !initials.isEmpty else { return }

            let side = size.width * 0.42
            let rect = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
            context.fillEllipse(in: rect)

            // Deux barres pour évoquer les initiales sans dépendre du texte :
            // CoreText demanderait une police, et l'échelle varie selon la
            // plateforme. Le repère visuel suffit pour juger une grille.
            let barHeight = side * 0.12
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
            context.fill(
                CGRect(
                    x: rect.minX + side * 0.2,
                    y: rect.midY + barHeight * 0.4,
                    width: side * 0.6 * CGFloat(initials.count) / 2,
                    height: barHeight
                ))
            context.fill(
                CGRect(
                    x: rect.minX + side * 0.2,
                    y: rect.midY - barHeight * 1.6,
                    width: side * 0.35,
                    height: barHeight
                ))
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

    // swiftlint:enable no_literal_color

    // MARK: - Aléa reproductible

    /// Générateur déterministe : deux exécutions donnent le même catalogue.
    ///
    /// C'est ce qui rend les mesures de performance comparables d'une session à
    /// l'autre, et les captures d'écran stables.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) { state = seed == 0 ? 0x4d59_5df4_d0f3_3173 : seed }

        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }

        mutating func next(upTo bound: Int) -> Int {
            bound <= 0 ? 0 : Int(next() % UInt64(bound))
        }
    }

#endif
