import SwiftUI

// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Ce fichier porte trois choses que la direction courante a **supprimées**, pas
// renommées : les ombres, les bordures, et les proportions autres que 2:3 et 16:9.
//
//   - `shadow: none` est une règle du système. Une vue qui semble avoir besoin
//     d'une ombre est un écran hors-système, pas un token manquant.
//   - « Aucune affiche n'a de bordure, d'ombre, ni de coin arrondi. La couleur de
//     l'écran vient de l'image. »
//   - Le 3:2 a été explicitement écarté : 8 % plus haut que le 16:9 à largeur
//     égale, invisible en rangée, mais désaligné du fond de hero.
//
// Rien de neuf ne doit lire ce fichier. Il disparaît en bloc avec `V12`.
// Voir README.md de ce dossier.
//
// Les crans d'espacement et de rayon de la direction courante gagnent sur les noms
// communs : `Radius.xs` vaut désormais 2 pt et non 4, et `Motion.base` 220 ms au
// lieu de 240. Le banc d'essai s'en trouve très légèrement différent — c'est
// voulu, et c'est à ça qu'il sert.

extension Space {
    // Crans de l'ancienne échelle, qui commençait à 2 pt.
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    // Alias par usage. La direction courante n'en a pas : un cran se désigne par
    // son rang, parce qu'un nom d'usage finit toujours par mentir.
    public static let inlineTight = xs
    public static let inline = sm
    public static let stackTight = sm
    public static let stack = lg
    public static let section = xxl
    public static let cardPadding = md
    public static let panelPadding = xl

    public static func pageMargin(compact: Bool) -> CGFloat {
        compact ? lg : xxl
    }
}

extension Radius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20

    public static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// Les rayons de l'ancienne direction sous un nom sans ambiguïté, pour les
/// endroits qui doivent explicitement dire « valeur d'avant ».
public enum LegacyRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
}

extension Motion {
    public static let quick = Animation.snappy(duration: 0.16)
    public static let emphasis = Animation.bouncy(duration: 0.4, extraBounce: 0.08)
}

/// Proportions de l'ancienne direction.
///
/// La direction courante n'expose que 2:3 et 16:9, par `CardLayout.aspectRatio`.
public enum Ratio {
    public static let poster: CGFloat = 2 / 3
    public static let backdrop: CGFloat = 16 / 9
    public static let landscape: CGFloat = 3 / 2
    public static let avatar: CGFloat = 1
    public static let tile: CGFloat = 4 / 5
}

// MARK: - Ombres — supprimées par la direction courante

public struct ShadowSpec: Sendable, Hashable {
    public let radius: CGFloat
    public let y: CGFloat
    public let opacity: Double

    public init(radius: CGFloat, y: CGFloat, opacity: Double) {
        self.radius = radius
        self.y = y
        self.opacity = opacity
    }
}

public enum Elevation {
    public static let card = ShadowSpec(radius: 2, y: 1, opacity: 0.28)
    public static let media = ShadowSpec(radius: 12, y: 6, opacity: 0.45)
    public static let sheet = ShadowSpec(radius: 32, y: 12, opacity: 0.50)

    /// Remplacé par `Layer`, qui porte des plans de superposition et non des ombres.
    public enum Level: Int, Sendable, CaseIterable {
        case canvas = 0
        case surface = 1
        case floating = 2
        case sheet = 3
        case fullScreen = 4
    }
}

extension View {
    public func dsShadow(_ spec: ShadowSpec) -> some View {
        shadow(color: .black.opacity(spec.opacity), radius: spec.radius, x: 0, y: spec.y)
    }

    public func dsBorder(
        _ color: Color = .borderSubtle,
        radius: CGFloat,
        width: CGFloat = 1
    ) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: width)
        }
    }

    public func dsElevation(_ level: Elevation.Level, radius: CGFloat = Radius.lg) -> some View {
        switch level {
        case .canvas:
            return AnyView(self)
        case .surface:
            return AnyView(background(.bgSurface).dsClip(radius))
        case .floating:
            return AnyView(background(.bgSurfaceRaised).dsClip(radius).dsShadow(Elevation.card))
        case .sheet:
            return AnyView(
                background(.regularMaterial, in: .rect(cornerRadius: radius, style: .continuous))
                    .dsShadow(Elevation.sheet)
            )
        case .fullScreen:
            return AnyView(background(.bgCanvas))
        }
    }
}
