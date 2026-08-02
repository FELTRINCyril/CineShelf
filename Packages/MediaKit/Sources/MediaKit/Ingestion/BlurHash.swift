import CoreGraphics
import Foundation

public enum BlurHashError: Error, Equatable {
    case unsupportedComponentCount
    case unreadablePixels
}

/// Encodeur BlurHash : quelques dizaines d'octets qui remplacent l'image le
/// temps qu'elle arrive, sans saut de mise en page.
public enum BlurHash {
    /// Côté long du buffer sur lequel les coefficients sont calculés.
    ///
    /// Un blurhash ne décrit que les très basses fréquences : au-delà de cette
    /// taille, les coefficients ne bougent plus et le coût grimpe en O(pixels).
    static let samplingSide = 64

    private static let alphabet = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    )

    /// - Parameters:
    ///   - image: l'image à résumer.
    ///   - componentsX: composantes horizontales, 1 à 9.
    ///   - componentsY: composantes verticales, 1 à 9.
    /// - Returns: le hash en base 83.
    /// - Throws: `BlurHashError` si le nombre de composantes est hors bornes ou
    ///   si l'image ne peut pas être lue.
    public static func encode(_ image: CGImage, componentsX: Int = 4, componentsY: Int = 3) throws -> String {
        guard (1...9).contains(componentsX), (1...9).contains(componentsY) else {
            throw BlurHashError.unsupportedComponentCount
        }

        let bitmap = try Bitmap(image: image, maxSide: samplingSide)
        var factors: [Component] = []
        factors.reserveCapacity(componentsX * componentsY)

        for row in 0..<componentsY {
            for column in 0..<componentsX {
                let normalisation: Double = (column == 0 && row == 0) ? 1 : 2
                factors.append(bitmap.component(column: column, row: row, normalisation: normalisation))
            }
        }

        let direct = factors[0]
        let alternating = Array(factors.dropFirst())

        var hash = ""
        hash += base83(componentsX - 1 + (componentsY - 1) * 9, length: 1)

        let peak = alternating.flatMap { [abs($0.red), abs($0.green), abs($0.blue)] }.max() ?? 0
        let quantisedPeak = max(0, min(82, Int(floor(peak * 166 - 0.5))))
        let maximum = alternating.isEmpty ? 1 : Double(quantisedPeak + 1) / 166
        hash += base83(alternating.isEmpty ? 0 : quantisedPeak, length: 1)

        hash += base83(direct.packedDC, length: 4)
        for component in alternating {
            hash += base83(component.packedAC(maximum: maximum), length: 2)
        }
        return hash
    }

    private static func base83(_ value: Int, length: Int) -> String {
        var result = ""
        for power in 1...length {
            let digit = (value / Int(pow(83, Double(length - power)))) % 83
            result.append(alphabet[digit])
        }
        return result
    }
}

/// Un coefficient, une valeur par canal, en lumière linéaire.
private struct Component {
    var red: Double
    var green: Double
    var blue: Double

    var packedDC: Int {
        (Self.linearTo8Bit(red) << 16) + (Self.linearTo8Bit(green) << 8) + Self.linearTo8Bit(blue)
    }

    func packedAC(maximum: Double) -> Int {
        quantise(red, maximum: maximum) * 19 * 19
            + quantise(green, maximum: maximum) * 19
            + quantise(blue, maximum: maximum)
    }

    private func quantise(_ value: Double, maximum: Double) -> Int {
        let signed = copysign(pow(abs(value / maximum), 0.5), value)
        return max(0, min(18, Int(floor(signed * 9 + 9.5))))
    }

    private static func linearTo8Bit(_ value: Double) -> Int {
        let clamped = max(0, min(1, value))
        let encoded = clamped <= 0.003_130_8 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        return Int((encoded * 255).rounded())
    }
}

/// Pixels sRGB non prémultipliés, réduits à une taille de travail.
private struct Bitmap {
    let bytes: [UInt8]
    let width: Int
    let height: Int
    let bytesPerRow: Int

    init(image: CGImage, maxSide: Int) throws {
        let longEdge = max(image.width, image.height)
        let ratio = longEdge > maxSide ? Double(maxSide) / Double(longEdge) : 1
        let width = max(1, Int((Double(image.width) * ratio).rounded()))
        let height = max(1, Int((Double(image.height) * ratio).rounded()))

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw BlurHashError.unreadablePixels }
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)

        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard
                let context = CGContext(
                    data: raw.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                )
            else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw BlurHashError.unreadablePixels }

        self.bytes = buffer
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
    }

    func component(column: Int, row: Int, normalisation: Double) -> Component {
        var red = 0.0
        var green = 0.0
        var blue = 0.0

        for pixelY in 0..<height {
            let vertical = cos(.pi * Double(row) * Double(pixelY) / Double(height))
            for pixelX in 0..<width {
                let basis =
                    normalisation
                    * cos(.pi * Double(column) * Double(pixelX) / Double(width))
                    * vertical
                let offset = pixelY * bytesPerRow + pixelX * 4
                red += basis * Self.linear(bytes[offset])
                green += basis * Self.linear(bytes[offset + 1])
                blue += basis * Self.linear(bytes[offset + 2])
            }
        }

        let scale = 1 / Double(width * height)
        return Component(red: red * scale, green: green * scale, blue: blue * scale)
    }

    private static func linear(_ value: UInt8) -> Double {
        let normalised = Double(value) / 255
        return normalised <= 0.040_45
            ? normalised / 12.92
            : pow((normalised + 0.055) / 1.055, 2.4)
    }
}
