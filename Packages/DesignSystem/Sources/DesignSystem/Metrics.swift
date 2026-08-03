import SwiftUI

// MARK: - Espacement

public enum Space {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    // Sémantiques
    public static let inlineTight = xs
    public static let inline = sm
    public static let stackTight = sm
    public static let stack = lg
    public static let section = xxl
    public static let cardPadding = md
    public static let panelPadding = xl

    /// Marge de page adaptative. Sur Mac, préférer `.scenePadding()` quand c'est possible.
    public static func pageMargin(compact: Bool) -> CGFloat {
        #if os(macOS)
            20
        #else
            compact ? 16 : 24
        #endif
    }

    /// Cible tactile minimale (plancher de qualité).
    public static let minHitTarget: CGFloat = 44
}

// MARK: - Rayons — toujours continus

public enum Radius {
    public static let xs: CGFloat = 4  // badges, cases à cocher
    public static let sm: CGFloat = 6  // champs, petits contrôles
    public static let md: CGFloat = 10  // boutons, cartes de liste
    public static let lg: CGFloat = 14  // jaquettes, panneaux
    public static let xl: CGFloat = 20  // feuilles, blocs hero

    /// Squircle Apple. Ne jamais construire un `RoundedRectangle` sans `.continuous`.
    public static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

extension View {
    public func dsClip(_ radius: CGFloat) -> some View {
        clipShape(.rect(cornerRadius: radius, style: .continuous))
    }

    /// Trait de 1 pt aligné à l'intérieur du rayon.
    public func dsBorder(_ color: Color = .borderSubtle, radius: CGFloat, width: CGFloat = 1) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: width)
        }
    }
}

// MARK: - Élévation — matériaux, pas ombres

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
    /// Jaquette survolée — Mac uniquement.
    public static let media = ShadowSpec(radius: 12, y: 6, opacity: 0.45)
    public static let sheet = ShadowSpec(radius: 32, y: 12, opacity: 0.50)

    /// Niveaux 0–4. Au-delà du niveau 1, la profondeur vient d'un matériau,
    /// pas d'une ombre : c'est la règle du système.
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

    /// Applique le traitement d'élévation. Sur iOS, les feuilles et popovers système
    /// gèrent leur propre élévation : `.sheet` n'y ajoute pas d'ombre.
    @ViewBuilder
    public func dsElevation(_ level: Elevation.Level, radius: CGFloat = Radius.lg) -> some View {
        switch level {
        case .canvas:
            background(.bgCanvas)
        case .surface:
            background(.bgSurface, in: .rect(cornerRadius: radius, style: .continuous))
                .dsBorder(.borderSubtle, radius: radius)
        case .floating:
            background(.regularMaterial, in: .rect(cornerRadius: radius, style: .continuous))
        case .sheet:
            #if os(macOS)
                background(.thickMaterial, in: .rect(cornerRadius: radius, style: .continuous))
                    .dsShadow(Elevation.sheet)
            #else
                background(.thickMaterial, in: .rect(cornerRadius: radius, style: .continuous))
            #endif
        case .fullScreen:
            background(.bgCanvas)
        }
    }
}

// MARK: - Mouvement

public enum Motion {
    public static let quick = Animation.snappy(duration: 0.16)
    public static let base = Animation.smooth(duration: 0.24)
    public static let sheet = Animation.smooth(duration: 0.32)
    public static let emphasis = Animation.bouncy(duration: 0.4, extraBounce: 0.08)
}

extension View {
    /// Anime en respectant `accessibilityReduceMotion`.
    public func dsAnimation<V: Equatable>(_ animation: Animation = Motion.base, value: V) -> some View {
        modifier(ReduceMotionAware(animation: animation, value: value))
    }
}

private struct ReduceMotionAware<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Proportions

public enum Ratio {
    public static let poster: CGFloat = 2 / 3
    public static let backdrop: CGFloat = 16 / 9
    public static let landscape: CGFloat = 3 / 2
    public static let avatar: CGFloat = 1
    public static let tile: CGFloat = 4 / 5
}
