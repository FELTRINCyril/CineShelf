import CoreGraphics
import Foundation

/// Les trois tailles de vignette du cache.
///
/// La taille demandée par une vue est arrondie au preset qui la couvre : le nom
/// de fichier de `docs/04` §4 (`<assetID>-<preset>@<scale>`) suppose un nombre
/// borné d'entrées, pas une par largeur de grille.
///
/// Les valeurs viennent des métriques de cartes de `docs/01` : la plus grande
/// carte fait 340 pt de large, la portrait compacte 104 × 156 pt.
public enum ThumbnailPreset: String, CaseIterable, Sendable {
    /// Listes, casting, avatars.
    case thumb
    /// Grilles et rails de jaquettes.
    case card
    /// Bandeau d'accueil et fiches.
    case hero

    /// Côté long, en points.
    public var maxPointSize: CGFloat {
        switch self {
        case .thumb: 160
        case .card: 360
        case .hero: 1200
        }
    }

    /// Le plus petit preset qui couvre la taille demandée.
    public static func covering(_ size: CGSize) -> ThumbnailPreset {
        let longEdge = max(size.width, size.height)
        return allCases.first { $0.maxPointSize >= longEdge } ?? .hero
    }

    /// Côté long en pixels pour une échelle d'écran donnée.
    public func maxPixelSize(scale: CGFloat) -> Int {
        Int((maxPointSize * max(1, scale)).rounded())
    }
}
