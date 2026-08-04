import SwiftUI

// MARK: - Espacement
//
// Base 4 pt, huit crans. Les noms sont ceux de la planche 8 : un cran se désigne
// par son rang, pas par un usage. Un espacement nommé « padding de carte » finit
// toujours par mentir quand la carte change.

public enum Space {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24
    public static let s6: CGFloat = 32
    public static let s7: CGFloat = 48
    public static let s8: CGFloat = 64

    /// Cible tactile minimale. Contrainte d'accessibilité, pas un choix de design :
    /// tout élément interactif fait au moins 44 pt et reste atteignable au clavier.
    public static let minHitTarget: CGFloat = 44
}

// MARK: - Densité
//
// **La seule valeur dynamique du système**, posée une fois par plateforme dans
// l'environnement : dense sur macOS, ample sur iOS. Sur iPadOS, ample par défaut
// et dense dès qu'un pointeur est détecté, avec une transition en `dur.base` et un
// réglage manuel dans les préférences.
//
// Deux crans, pas trois. `docs/03` annonçait « compacte / standard / confortable » ;
// ce sont deux crans qui ont été dessinés, et c'est `docs/03` qui a été corrigé.

public enum Density: String, Codable, Sendable, CaseIterable, Identifiable {
    case dense, roomy

    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .dense: "Dense"
        case .roomy: "Ample"
        }
    }

    /// Hauteur d'une ligne de tableau.
    public var rowHeight: CGFloat { self == .dense ? 28 : 44 }
    /// Hauteur d'une barre d'outils.
    public var toolbarHeight: CGFloat { self == .dense ? 44 : 60 }
    /// Marge horizontale d'écran.
    public var screenMargin: CGFloat { self == .dense ? 24 : 36 }
    /// Espacement vertical entre deux champs de formulaire.
    public var formSpacing: CGFloat { self == .dense ? 10 : 20 }
    /// Hauteur d'un champ.
    public var fieldHeight: CGFloat { self == .dense ? 28 : 38 }
    /// Gouttière de grille.
    public var gridGutter: CGFloat { self == .dense ? 16 : 24 }
    /// Interlignage du corps de texte, en multiple de la taille.
    public var bodyLeading: CGFloat { self == .dense ? 1.45 : 1.6 }

    /// Le cran par défaut de la plateforme.
    public static var platformDefault: Density {
        #if os(macOS)
            .dense
        #else
            .roomy
        #endif
    }
}

extension EnvironmentValues {
    /// Le cran de densité courant.
    @Entry public var density: Density = .platformDefault
}

// MARK: - Rayons
//
// `radius.none` sur tout ce qui est photographique : une affiche n'a ni cadre, ni
// coin arrondi, ni ombre. C'est une règle du système, pas un réglage.

public enum Radius {
    /// Affiches, images, tout ce qui est photographique.
    public static let none: CGFloat = 0
    /// Jetons, champs, boutons.
    public static let xs: CGFloat = 2
    /// Cartes non-affiche.
    public static let s: CGFloat = 4
    /// Popover, menu, notification.
    public static let m: CGFloat = 10
    /// Feuille modale.
    public static let l: CGFloat = 14

    /// Rayon d'une feuille : `l`, appliqué **aux deux coins hauts seulement**, et
    /// uniquement sur iOS et iPadOS. Sur macOS la feuille est un dialogue centré à
    /// angles francs, donc `none`.
    public static var sheet: CGFloat {
        #if os(macOS)
            none
        #else
            l
        #endif
    }
}

// MARK: - Trait
//
// Une seule épaisseur, une seule couleur par défaut. `emphasis` n'existe que pour
// le récapitulatif de refus d'un formulaire — seule entorse nommée par le design.

public enum Stroke {
    public static let hairline: CGFloat = 1
    /// Récapitulatif de refus en tête de formulaire, et rien d'autre.
    public static let emphasis: CGFloat = 2
}

// MARK: - Mouvement

public enum Motion {
    /// Sélection dans un tableau dense : aucune animation.
    public static let instant = Animation.linear(duration: 0)
    /// Survol, focus, bascule d'état.
    public static let fast = Animation.easeOut(duration: 0.12)
    /// Panneau, bandeau, bascule de densité.
    public static let base = Animation.easeInOut(duration: 0.22)
    /// Feuille, changement de palier.
    public static let sheet = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Affiche vers visionneuse plein écran.
    public static let zoom = Animation.spring(response: 0.38, dampingFraction: 0.9)
    /// Fondu du hero au changement de titre.
    public static let slow = Animation.easeInOut(duration: 0.6)
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

// MARK: - Plans
//
// Deux règles : un seul plan modal à la fois — une feuille ne s'ouvre pas au-dessus
// d'un dialogue, elle le remplace ; et la notification passe au-dessus de tout, y
// compris de la visionneuse.

public enum Layer {
    public static let content: Double = 0
    public static let sticky: Double = 10
    public static let menu: Double = 30
    public static let scrim: Double = 40
    public static let modal: Double = 50
    public static let viewer: Double = 60
    public static let notification: Double = 80
}

// MARK: - Points de rupture
//
// Sur **largeur de fenêtre**, pas sur classe de taille.
//
// **Le nombre de colonnes ne figure pas ici, et c'est délibéré : il se calcule, il ne
// se déclare pas.** La règle arrêtée est celle de l'addendum 2 bloc `13c` — « le nombre
// de colonnes n'est pas un réglage : la largeur de carte est fixe par le cran de la
// matrice, la grille prend ce qui rentre ». `GridMetrics.columnCount` est le seul
// endroit où ce compte existe.
//
// La colonne « Colonnes » du tableau des points de rupture de `docs/design/README.md`
// §4.6 reste dans le document, comme la référence indicative qu'elle dit être. Elle a
// été transcrite ici par `I1` en constante, et `I4` l'a retirée : une constante que
// personne ne lit et qui contredit le calcul finit par se faire « respecter » par
// quelqu'un qui croit corriger un oubli.

public enum Breakpoint: String, Sendable, CaseIterable, Identifiable {
    case phonePortrait, phoneLandscape, padPortrait, padLandscape, macStandard, macWide

    public var id: String { rawValue }

    /// La largeur minimale de fenêtre qui active ce cran.
    public var minWidth: CGFloat {
        switch self {
        case .phonePortrait: 0
        case .phoneLandscape: 430
        case .padPortrait: 744
        case .padLandscape: 1024
        case .macStandard: 1280
        case .macWide: 1680
        }
    }

    /// Marge horizontale d'écran de ce cran.
    ///
    /// Elle ne se déduit pas de la densité : le design la donne par point de
    /// rupture, et les deux valeurs ne coïncident pas partout.
    public var screenMargin: CGFloat {
        switch self {
        case .phonePortrait: 20
        case .phoneLandscape: 20
        case .padPortrait: 28
        case .padLandscape: 24
        case .macStandard: 32
        case .macWide: 64
        }
    }

    /// La gouttière de grille de ce cran, à une densité donnée.
    ///
    /// C'est celle de la densité partout, **sauf en `macWide`** : le tableau des points
    /// de rupture y écrit « marges 64, gouttière 24 » alors que la densité par défaut
    /// du Mac est dense, donc 16. Une fenêtre de 1680 pt aère, elle ne resserre pas.
    /// Même raison d'être que `screenMargin` — le design donne ces deux mesures par
    /// point de rupture, pas seulement par densité.
    public func gridGutter(_ density: Density) -> CGFloat {
        self == .macWide ? Density.roomy.gridGutter : density.gridGutter
    }

    /// L'inspecteur est une colonne à partir de 1024 pt, une feuille en dessous.
    public var showsInspectorAsColumn: Bool { minWidth >= Self.padLandscape.minWidth }

    /// Le cran correspondant à une largeur de fenêtre.
    public static func forWidth(_ width: CGFloat) -> Breakpoint {
        allCases.last { width >= $0.minWidth } ?? .phonePortrait
    }
}

// MARK: - Confort

extension View {
    /// Coins continus — jamais `.cornerRadius()`, qui produit un arrondi circulaire.
    public func dsClip(_ radius: CGFloat) -> some View {
        clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}
