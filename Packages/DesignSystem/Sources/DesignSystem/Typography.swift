import SwiftUI

// MARK: - Typographie
//
// Onze rôles, planche 8 du handoff. Chacun est déclaré avec
// `Font.custom(_:size:relativeTo:)` : la taille écrite ici est le point de départ
// de Dynamic Type, jamais une taille finale. Aucune taille fixe, jamais.
//
// Deux règles du système que le code ne peut pas faire respecter tout seul :
// tout chiffre aligné en colonne est en IBM Plex Mono tabulaire (`numeric`), et
// les capitales ne servent qu'à deux rôles — `label` nomme un champ, `action` se
// clique. Jamais un titre de contenu.

public enum Typo {

    // MARK: Titrage — bascule à .accessibilityMedium
    //
    // Les trois styles de titrage passent de Bebas Neue à Archivo Narrow 700 à
    // partir de `.accessibilityMedium`. Bebas est une capitale étroite sans bas de
    // casse : elle tient jusqu'à `.xxLarge`, au-delà elle cesse d'être lisible.
    //
    // Ils s'exposent en fonction de la taille et **pas** en propriété statique :
    // une `Font` figée perdrait la bascule en silence, et c'est précisément le
    // genre de perte qu'on ne voit qu'en testant à AX5. Le chemin normal reste le
    // modificateur (`.displayStyle()`), qui lit l'environnement pour vous.

    public static func display(_ size: DynamicTypeSize) -> Font {
        titling(size, base: Size.display, relativeTo: .largeTitle)
    }

    public static func title1(_ size: DynamicTypeSize) -> Font {
        titling(size, base: Size.title1, relativeTo: .title)
    }

    public static func title2(_ size: DynamicTypeSize) -> Font {
        titling(size, base: Size.title2, relativeTo: .title2)
    }

    private static func titling(
        _ size: DynamicTypeSize,
        base: CGFloat,
        relativeTo style: Font.TextStyle
    ) -> Font {
        let face: DesignSystemFonts.Face = size.usesAccessibleTitling ? .narrowBold : .bebas
        return .custom(face.postScriptName, size: base, relativeTo: style)
    }

    // MARK: Interface et corps

    /// Archivo 600.
    public static let headline = Font.custom(
        DesignSystemFonts.Face.archivoSemiBold.postScriptName,
        size: Size.headline,
        relativeTo: .headline
    )

    /// Public Sans 300.
    public static let body = Font.custom(
        DesignSystemFonts.Face.publicSansLight.postScriptName,
        size: Size.body,
        relativeTo: .body
    )

    /// Archivo 400.
    public static let callout = Font.custom(
        DesignSystemFonts.Face.archivoRegular.postScriptName,
        size: Size.callout,
        relativeTo: .callout
    )

    /// Archivo Narrow 600, capitales. À composer avec `.labelStyle()`.
    public static let label = Font.custom(
        DesignSystemFonts.Face.narrowSemiBold.postScriptName,
        size: Size.label,
        relativeTo: .caption
    )

    /// Archivo Narrow 600, capitales. À composer avec `.actionStyle()`.
    public static let action = Font.custom(
        DesignSystemFonts.Face.narrowSemiBold.postScriptName,
        size: Size.action,
        relativeTo: .subheadline
    )

    // MARK: Chiffres et métadonnées — IBM Plex Mono

    /// IBM Plex Mono 400.
    public static let meta = Font.custom(
        DesignSystemFonts.Face.plexMono.postScriptName,
        size: Size.meta,
        relativeTo: .caption2
    )

    /// IBM Plex Mono 500, chiffres tabulaires. Tout chiffre aligné en colonne.
    public static let numeric = Font.custom(
        DesignSystemFonts.Face.plexMonoMedium.postScriptName,
        size: Size.numeric,
        relativeTo: .footnote
    ).monospacedDigit()

    /// IBM Plex Mono 400.
    public static let micro = Font.custom(
        DesignSystemFonts.Face.plexMono.postScriptName,
        size: Size.micro,
        relativeTo: .caption2
    )

    // MARK: Métriques

    /// Tailles de base, en points. Point de départ de Dynamic Type.
    public enum Size {
        public static let display: CGFloat = 56
        public static let title1: CGFloat = 34
        public static let title2: CGFloat = 22
        public static let headline: CGFloat = 15
        public static let body: CGFloat = 15
        public static let callout: CGFloat = 13
        public static let label: CGFloat = 11
        public static let action: CGFloat = 12
        public static let meta: CGFloat = 11
        public static let numeric: CGFloat = 12
        public static let micro: CGFloat = 10
    }

    /// Interlettrage, en points à la taille de base.
    ///
    /// La planche 8 le donne en `em`. `.tracking()` prend des points, donc la
    /// conversion se fait à la taille de base : sous Dynamic Type, l'interlettrage
    /// ne grandit pas avec le texte. Écart assumé — SwiftUI n'expose pas
    /// d'interlettrage relatif, et l'alternative serait de lire la taille rendue
    /// pour la recalculer à chaque passe de rendu.
    public enum Tracking {
        public static let display = Size.display * 0.02
        public static let title1 = Size.title1 * 0.02
        public static let title2 = Size.title2 * 0.03
        public static let label = Size.label * 0.12
        public static let action = Size.action * 0.08
        public static let meta = Size.meta * 0.02
        public static let micro = Size.micro * 0.04
    }

    /// Interlignage relatif de la planche 8, en multiple de la taille.
    ///
    /// SwiftUI n'a pas de « line height » : `.lineSpacing()` ajoute de l'espace
    /// **entre** les lignes, en plus de l'interligne naturel de la police. Ces
    /// valeurs servent donc à calculer un `lineSpacing`, pas à le remplacer — voir
    /// `Leading.spacing(for:at:)`.
    public enum Leading {
        public static let display: CGFloat = 1.0
        public static let title1: CGFloat = 1.05
        public static let title2: CGFloat = 1.15
        public static let headline: CGFloat = 1.3
        public static let body: CGFloat = 1.55
        public static let callout: CGFloat = 1.45
        public static let label: CGFloat = 1.0
        public static let action: CGFloat = 1.0
        public static let meta: CGFloat = 1.35
        public static let numeric: CGFloat = 1.3
        public static let micro: CGFloat = 1.4

        /// L'espace à ajouter entre deux lignes pour atteindre `ratio` à `size`.
        ///
        /// Approximation assumée : l'interligne naturel d'une police est proche de
        /// 1,2 fois sa taille. En dessous de ce rapport il n'y a rien à ajouter —
        /// resserrer demanderait un `TextRenderer`, hors périmètre des tokens.
        public static func spacing(for ratio: CGFloat, at size: CGFloat) -> CGFloat {
            max(0, (ratio - 1.2) * size)
        }
    }
}

// MARK: - Bascule accessible

extension DynamicTypeSize {
    /// À la première taille d'accessibilité, le titrage quitte Bebas Neue.
    ///
    /// La planche 8 écrit `.accessibilityMedium`, qui est le nom de cette taille
    /// dans `ContentSizeCategory`. `DynamicTypeSize` — l'énumération que SwiftUI
    /// met dans l'environnement — n'a pas ce cas : la même taille s'y appelle
    /// `.accessibility1`. `isAccessibilitySize` la teste directement, ce qui évite
    /// d'avoir à traduire entre les deux échelles à chaque lecture.
    ///
    /// Conséquences validées par le design, à retenir avant de s'en étonner : les
    /// formulaires en regard passent en libellé-au-dessus, les grilles perdent une
    /// à deux colonnes, la densité bascule en ample **y compris sur Mac**, et le
    /// mot CINESHELF perd son allure de logotype.
    public var usesAccessibleTitling: Bool { isAccessibilitySize }
}

// MARK: - Rôles composés
//
// Un rôle typographique n'est pas qu'une `Font` : il porte aussi son
// interlettrage, son interlignage et sa casse. Ces modificateurs sont le chemin
// normal — ils évitent d'avoir à se souvenir que `label` est en capitales ou que
// le titrage bascule à AX.

extension View {

    public func displayStyle() -> some View { modifier(TitlingStyle(role: .display)) }
    public func title1Style() -> some View { modifier(TitlingStyle(role: .title1)) }
    public func title2Style() -> some View { modifier(TitlingStyle(role: .title2)) }

    public func headlineStyle() -> some View {
        font(Typo.headline)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.headline, at: Typo.Size.headline))
    }

    public func bodyStyle() -> some View {
        font(Typo.body)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.body, at: Typo.Size.body))
    }

    public func calloutStyle() -> some View {
        font(Typo.callout)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.callout, at: Typo.Size.callout))
    }

    /// Nomme un champ. Capitales, interlettrage large.
    public func labelStyle() -> some View {
        font(Typo.label).textCase(.uppercase).tracking(Typo.Tracking.label)
    }

    /// Se clique. Capitales, interlettrage moyen.
    public func actionStyle() -> some View {
        font(Typo.action).textCase(.uppercase).tracking(Typo.Tracking.action)
    }

    public func metaStyle() -> some View {
        font(Typo.meta)
            .tracking(Typo.Tracking.meta)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.meta, at: Typo.Size.meta))
    }

    public func numericStyle() -> some View {
        font(Typo.numeric)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.numeric, at: Typo.Size.numeric))
    }

    public func microStyle() -> some View {
        font(Typo.micro)
            .tracking(Typo.Tracking.micro)
            .lineSpacing(Typo.Leading.spacing(for: Typo.Leading.micro, at: Typo.Size.micro))
    }
}

/// Les trois titrages, qui doivent lire l'environnement pour basculer.
private struct TitlingStyle: ViewModifier {

    enum Role {
        case display, title1, title2

        var size: CGFloat {
            switch self {
            case .display: Typo.Size.display
            case .title1: Typo.Size.title1
            case .title2: Typo.Size.title2
            }
        }

        var tracking: CGFloat {
            switch self {
            case .display: Typo.Tracking.display
            case .title1: Typo.Tracking.title1
            case .title2: Typo.Tracking.title2
            }
        }

        var leading: CGFloat {
            switch self {
            case .display: Typo.Leading.display
            case .title1: Typo.Leading.title1
            case .title2: Typo.Leading.title2
            }
        }

        func font(_ size: DynamicTypeSize) -> Font {
            switch self {
            case .display: Typo.display(size)
            case .title1: Typo.title1(size)
            case .title2: Typo.title2(size)
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: Role

    func body(content: Content) -> some View {
        content
            .font(role.font(dynamicTypeSize))
            .tracking(role.tracking)
            .lineSpacing(Typo.Leading.spacing(for: role.leading, at: role.size))
    }
}
