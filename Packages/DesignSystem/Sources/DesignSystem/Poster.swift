import SwiftUI

// MARK: - Affiches : six crans, et la matrice contexte × disposition × taille
//
// **Ce n'est pas une préférence de design, c'est une fonctionnalité de l'app.**
// L'utilisateur choisit `portrait|paysage × compact|medium|large`, indépendamment
// sur huit contextes, et le réglage est mémorisé par contexte. La bascule de
// direction artistique conserve explicitement la matrice : le nouveau design doit
// la rendre, pas la remplacer.
//
// L'échelle sous-jacente s'exprime en **largeur de carte**, et le ratio dérive la
// hauteur. Le nombre de colonnes n'est jamais un réglage : la grille prend ce qui
// rentre à largeur de carte constante.

/// Les six crans de largeur d'affiche, en points.
public enum PosterScale: String, Codable, Sendable, CaseIterable, Identifiable {
    case xs, s, m, l, xl, xxl

    public var id: String { rawValue }

    public var width: CGFloat {
        switch self {
        case .xs: 32
        case .s: 56
        case .m: 92
        case .l: 140
        case .xl: 200
        case .xxl: 280
        }
    }

    /// La taille complète du cran dans une disposition donnée.
    public func size(_ layout: CardLayout) -> CGSize {
        CGSize(width: width, height: width / layout.aspectRatio)
    }
}

/// Les deux dispositions. Le ratio est fixé par la disposition, jamais par l'image.
public enum CardLayout: String, Codable, Sendable, CaseIterable, Identifiable {
    case portrait, landscape

    public var id: String { rawValue }

    /// largeur / hauteur. 2:3 en portrait, 16:9 en paysage.
    ///
    /// Le 16:9 a été retenu parce que l'éditeur de recadrage produit déjà 16:9 et
    /// 2:3, parce que les images larges arrivent en 16:9, et parce que 3:2 ne
    /// serait que 8 % plus haut à largeur égale — invisible en rangée, mais
    /// désaligné du fond de hero.
    public var aspectRatio: CGFloat {
        switch self {
        case .portrait: 2.0 / 3.0
        case .landscape: 16.0 / 9.0
        }
    }

    public var label: LocalizedStringKey {
        switch self {
        case .portrait: "Portrait"
        case .landscape: "Paysage"
        }
    }

    public var symbol: String {
        switch self {
        case .portrait: Icon.layoutPortrait
        case .landscape: Icon.layoutLandscape
        }
    }
}

/// Les trois crans réglables par contexte.
public enum CardSize: String, Codable, Sendable, CaseIterable, Identifiable {
    case compact, medium, large

    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .compact: "Compact"
        case .medium: "Moyen"
        case .large: "Grand"
        }
    }
}

/// Les huit contextes où la disposition se règle indépendamment.
public enum PosterContext: String, Codable, Sendable, CaseIterable, Identifiable {
    case homeTitles, homePeople, homeCollections, homeSocial
    case titles, people, collections, socialFeed

    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .homeTitles: "Accueil · rail titres"
        case .homePeople: "Accueil · rail personnes"
        case .homeCollections: "Accueil · rail collections"
        case .homeSocial: "Accueil · rail social"
        case .titles: "Titres · grille"
        case .people: "Personnes · grille"
        case .collections: "Collections · grille"
        case .socialFeed: "Social · fil"
        }
    }

    /// Les trois crans du contexte, dans l'ordre compact / medium / large.
    ///
    /// Une table plutôt qu'un `switch` sur le couple `(contexte, taille)` : les 24
    /// combinaisons se lisent alors ligne à ligne comme le tableau du handoff, et
    /// une correspondance se vérifie sans dérouler mentalement des cas groupés.
    ///
    /// Valeur nommée et non tuple à trois membres, comme `CropValues` : c'est la
    /// convention du dépôt, et il n'y aura pas de `swiftlint:disable large_tuple`.
    public var scales: Scales {
        switch self {
        case .homeTitles: Scales(.m, .l, .xl)
        case .homePeople: Scales(.s, .m, .l)
        case .homeCollections: Scales(.m, .l, .xl)
        case .homeSocial: Scales(.s, .m, .l)
        case .titles: Scales(.m, .l, .xxl)
        case .people: Scales(.s, .m, .xl)
        case .collections: Scales(.m, .l, .xxl)
        case .socialFeed: Scales(.m, .l, .xl)
        }
    }

    /// Les trois crans d'un contexte.
    public struct Scales: Sendable, Hashable {
        public let compact: PosterScale
        public let medium: PosterScale
        public let large: PosterScale

        init(_ compact: PosterScale, _ medium: PosterScale, _ large: PosterScale) {
            self.compact = compact
            self.medium = medium
            self.large = large
        }
    }

    /// Le cran d'échelle de ce contexte pour une taille donnée.
    public func scale(for size: CardSize) -> PosterScale {
        switch size {
        case .compact: scales.compact
        case .medium: scales.medium
        case .large: scales.large
        }
    }

    /// Le réglage par défaut du contexte.
    public var defaultSetting: PosterSetting {
        switch self {
        case .homeTitles, .titles: PosterSetting(layout: .portrait, size: .medium)
        case .homePeople, .people: PosterSetting(layout: .portrait, size: .compact)
        case .homeCollections, .collections, .socialFeed:
            PosterSetting(layout: .landscape, size: .medium)
        case .homeSocial: PosterSetting(layout: .landscape, size: .compact)
        }
    }
}

/// Le réglage d'un contexte : une disposition et une taille.
///
/// Ce que le store de préférences persiste, et **rien d'autre** : `pageSize` est
/// abandonné (la grille charge à la demande), `sort` et `dir` appartiennent au
/// filtre. Voir l'écart correspondant dans `docs/PROMPTS.md`.
public struct PosterSetting: Codable, Sendable, Hashable {
    public var layout: CardLayout
    public var size: CardSize

    public init(layout: CardLayout = .portrait, size: CardSize = .medium) {
        self.layout = layout
        self.size = size
    }

    public func scale(in context: PosterContext) -> PosterScale {
        context.scale(for: size)
    }

    /// La taille de carte rendue, pour un contexte donné.
    public func cardSize(in context: PosterContext) -> CGSize {
        scale(in: context).size(layout)
    }
}

// MARK: - Grille

extension PosterScale {
    /// Colonnes pour `LazyVGrid`, à largeur de carte constante.
    ///
    /// La virtualisation est native. Le nombre de colonnes se déduit de la largeur
    /// disponible : ce n'est jamais un réglage.
    public func gridColumns(gutter: CGFloat) -> [GridItem] {
        [GridItem(.adaptive(minimum: width), spacing: gutter)]
    }
}

// MARK: - Ce qu'il faut savoir avant de rendre une affiche en paysage
//
// Une affiche portrait recadrée en 16:9 perd le haut et le bas de la composition,
// donc souvent son titre imprimé. Le paysage n'a de sens que sur les contextes où
// l'image source est réellement large — c'est pour ça que `MediaSlot.backdrop`
// existe, et pour ça que le hero remplit toujours son cadre plutôt que de laisser
// des bandes noires.
