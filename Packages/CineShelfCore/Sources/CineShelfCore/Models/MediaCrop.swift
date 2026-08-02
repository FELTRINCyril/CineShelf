import Foundation
import SwiftData

/// Recadrage résolu, prêt à appliquer à l'affichage.
///
/// `docs/02` §3.7 renvoie un tuple `(x:, y:, zoom:)` ; une valeur nommée porte
/// les mêmes membres, laisse les appels de `docs/04` §4 inchangés et satisfait
/// la règle `large_tuple`.
public struct CropValues: Sendable, Equatable {
    /// 0–100.
    public var x: Double
    /// 0–100.
    public var y: Double
    /// 50–400.
    public var zoom: Double

    public init(x: Double, y: Double, zoom: Double) {
        self.x = x
        self.y = y
        self.zoom = zoom
    }

    /// Le recadrage neutre : centré, sans agrandissement.
    public static let neutral = CropValues(x: 50, y: 50, zoom: 100)
}

/// Recadrage d'un média pour un contexte d'affichage donné.
/// Remplace les 21 colonnes `*_position_x/_y/_zoom` de la version web.
@Model
public final class MediaCrop {
    public var id = UUID()
    public var contextRaw: String = CropContext.standard.rawValue
    /// 0–100.
    public var positionX: Double = 50
    /// 0–100.
    public var positionY: Double = 50
    /// 50–400.
    public var zoom: Double = 100
    public var updatedAt = Date()

    public var asset: MediaAsset?

    public init(context: CropContext = .standard) {
        self.contextRaw = context.rawValue
    }
}

extension MediaCrop {
    public var context: CropContext {
        get { CropContext(rawValue: contextRaw) ?? .standard }
        set { contextRaw = newValue.rawValue }
    }
}
