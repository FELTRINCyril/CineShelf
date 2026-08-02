import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Images de test générées par code : rien n'est embarqué dans le dépôt, et le
/// contenu reste identique d'une exécution à l'autre.
///
/// Les pixels sont écrits octet par octet plutôt que par `CGContext.setFillColor`
/// — c'est exactement déterministe, et ça évite d'écrire une couleur en dur, ce
/// que la règle de lint interdit hors du `DesignSystem`.
enum TestImage {
    /// Un pixel sRGB, canaux entre 0 et 1.
    struct Pixel {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// Dégradé diagonal, un rectangle sombre en haut à gauche, un disque clair
    /// au centre droit.
    static func make(width: Int, height: Int) throws -> CGImage {
        try makeImage(width: width, height: height) { column, row in
            let horizontal = Double(column) / Double(max(1, width - 1))
            let vertical = Double(row) / Double(max(1, height - 1))

            if column < width / 4, row < height / 3 {
                return Pixel(red: 0.05, green: 0.05, blue: 0.08)
            }

            let radius = Double(width) / 10
            let offsetX = Double(column) - Double(width) * 0.6
            let offsetY = Double(row) - Double(height) * 0.6
            if offsetX * offsetX + offsetY * offsetY < radius * radius {
                return Pixel(red: 0.95, green: 0.85, blue: 0.2)
            }

            return Pixel(red: horizontal, green: vertical, blue: 1 - horizontal * vertical)
        }
    }

    /// Un aplat.
    static func makeSolid(red: Double, green: Double, blue: Double, side: Int = 64) throws -> CGImage {
        try makeImage(width: side, height: side) { _, _ in Pixel(red: red, green: green, blue: blue) }
    }

    /// Moitié sombre, moitié claire, coupée dans un sens ou dans l'autre.
    static func makeSplit(vertical: Bool, side: Int = 64) throws -> CGImage {
        try makeImage(width: side, height: side) { column, row in
            let inBrightHalf = vertical ? row < side / 2 : column < side / 2
            let level = inBrightHalf ? 0.95 : 0.05
            return Pixel(red: level, green: level, blue: level)
        }
    }

    /// Les mêmes pixels, encodés en PNG : une source d'ingestion sans perte.
    static func makePNGData(width: Int, height: Int) throws -> Data {
        let image = try make(width: width, height: height)
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    /// Un dossier de travail propre, supprimé par l'appelant.
    static func makeScratchDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appendingPathComponent("MediaKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// - Parameters:
    ///   - width: largeur en pixels.
    ///   - height: hauteur en pixels.
    ///   - channels: les canaux sRGB d'un pixel, entre 0 et 1.
    /// - Returns: l'image correspondante.
    /// - Throws: si le contexte graphique ne peut pas être créé.
    private static func makeImage(
        width: Int,
        height: Int,
        channels: (Int, Int) -> Pixel
    ) throws -> CGImage {
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 255, count: bytesPerRow * height)

        for row in 0..<height {
            for column in 0..<width {
                let pixel = channels(column, row)
                let offset = row * bytesPerRow + column * 4
                bytes[offset] = Self.byte(pixel.red)
                bytes[offset + 1] = Self.byte(pixel.green)
                bytes[offset + 2] = Self.byte(pixel.blue)
            }
        }

        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try bytes.withUnsafeMutableBytes { raw in
            try #require(
                CGContext(
                    data: raw.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                )
            )
        }
        return try #require(context.makeImage())
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}
