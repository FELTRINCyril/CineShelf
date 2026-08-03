import SwiftUI

// MARK: - Bundle

extension Bundle {
    /// Bundle de ressources du package (Colors.xcassets, Archivo).
    public static let designSystem: Bundle = .module
}

// MARK: - Accès typé aux jeux sémantiques
//
// Niveau 2 uniquement : aucune vue ne référence une primitive (Graphite/900…),
// et aucune couleur littérale n'existe hors de ce fichier.
// Clair / sombre / contraste élevé sont résolus par les apparences du catalogue,
// jamais par du code conditionnel.

extension ShapeStyle where Self == Color {

    // Fonds
    public static var bgCanvas: Color { .ds("bg/canvas") }
    public static var bgSurface: Color { .ds("bg/surface") }
    public static var bgSurfaceRaised: Color { .ds("bg/surfaceRaised") }
    public static var bgInset: Color { .ds("bg/inset") }
    public static var bgSelected: Color { .ds("bg/selected") }

    // Texte
    public static var textPrimary: Color { .ds("text/primary") }
    public static var textSecondary: Color { .ds("text/secondary") }
    public static var textTertiary: Color { .ds("text/tertiary") }
    public static var textOnAccent: Color { .ds("text/onAccent") }

    // Traits
    public static var borderSubtle: Color { .ds("border/subtle") }
    public static var borderDefault: Color { .ds("border/default") }
    public static var borderStrong: Color { .ds("border/strong") }

    // Accent — un seul rôle : sélection, action principale, état actif.
    public static var accentText: Color { .ds("accent/text") }
    public static var accentSolid: Color { .ds("accent/solid") }
    public static var accentSoft: Color { .ds("accent/soft") }

    // États — `statusDanger` est en Crimson, distinct de l'accent.
    public static var statusSuccess: Color { .ds("status/success") }
    public static var statusWarning: Color { .ds("status/warning") }
    public static var statusDanger: Color { .ds("status/danger") }
    public static var statusInfo: Color { .ds("status/info") }

    // Média
    public static var mediaPlaceholder: Color { .ds("media/placeholder") }
    public static var mediaRing: Color { .ds("media/ring") }

    // États d'élément
    public static var statePrivate: Color { .ds("state/private") }
    public static var stateArchived: Color { .ds("state/archived") }
}

// Miroir sur `Color` : utilisable là où le contexte n'infère pas un `ShapeStyle`
// (`Color` stocké dans un modèle, `.tint(Color)`, interpolations…).
extension Color {
    public static var bgCanvas: Color { .ds("bg/canvas") }
    public static var bgSurface: Color { .ds("bg/surface") }
    public static var bgSurfaceRaised: Color { .ds("bg/surfaceRaised") }
    public static var bgInset: Color { .ds("bg/inset") }
    public static var bgSelected: Color { .ds("bg/selected") }
    public static var textPrimary: Color { .ds("text/primary") }
    public static var textSecondary: Color { .ds("text/secondary") }
    public static var textTertiary: Color { .ds("text/tertiary") }
    public static var textOnAccent: Color { .ds("text/onAccent") }
    public static var borderSubtle: Color { .ds("border/subtle") }
    public static var borderDefault: Color { .ds("border/default") }
    public static var borderStrong: Color { .ds("border/strong") }
    public static var accentText: Color { .ds("accent/text") }
    public static var accentSolid: Color { .ds("accent/solid") }
    public static var accentSoft: Color { .ds("accent/soft") }
    public static var statusSuccess: Color { .ds("status/success") }
    public static var statusWarning: Color { .ds("status/warning") }
    public static var statusDanger: Color { .ds("status/danger") }
    public static var statusInfo: Color { .ds("status/info") }
    public static var mediaPlaceholder: Color { .ds("media/placeholder") }
    public static var mediaRing: Color { .ds("media/ring") }
    public static var statePrivate: Color { .ds("state/private") }
    public static var stateArchived: Color { .ds("state/archived") }
}

extension Color {
    fileprivate static func ds(_ name: String) -> Color { Color(name, bundle: .designSystem) }
}
