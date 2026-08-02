import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodage HEIC, partagé par l'ingestion et le cache de vignettes.
///
/// Vérifié disponible sur simulateur iOS comme sur macOS : il n'y a donc pas de
/// repli vers JPEG, un échec d'encodage est une vraie erreur.
enum HEICEncoder {
    static let mimeType = "image/heic"

    static func encode(_ image: CGImage, quality: Double) throws -> Data {
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.heic.identifier as CFString,
                1,
                nil
            )
        else {
            throw MediaIngestionError.encodingFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { throw MediaIngestionError.encodingFailed }
        return output as Data
    }
}

/// Décodage partiel : jamais l'image entière en mémoire quand une vignette suffit.
enum ImageDecoder {
    /// - Parameters:
    ///   - data: les octets d'origine.
    ///   - maxPixelSize: côté long maximal, en pixels.
    ///   - cacheImmediately: décode tout de suite, hors du thread appelant.
    /// - Returns: la vignette, ou `nil` si les octets ne sont pas une image.
    static func thumbnail(from data: Data, maxPixelSize: Int, cacheImmediately: Bool = false) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize, cacheImmediately: cacheImmediately)
    }

    static func thumbnail(from url: URL, maxPixelSize: Int, cacheImmediately: Bool = false) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize, cacheImmediately: cacheImmediately)
    }

    private static func thumbnail(
        from source: CGImageSource,
        maxPixelSize: Int,
        cacheImmediately: Bool
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: cacheImmediately
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
