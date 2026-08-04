import SwiftUI

// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Les largeurs, gouttières, rayons et « affiche avec métadonnées dessous » de la
// direction abandonnée. La direction courante pose six crans de largeur
// (`PosterScale`), aucune bordure, aucun rayon sur une image, et aucune
// métadonnée sous une affiche au repos.
//
// Ne survivent que pour le banc d'essai des prompts 10 et 11. Rien de neuf ne
// doit les lire : utiliser `PosterScale`, `PosterContext` et `PosterSetting`.
// Disparaissent en bloc avec `V12`. Voir README.md de ce dossier.
//
// `CardLayout` et `CardSize` ne sont **pas** ici : ce sont les deux axes de la
// matrice, une fonctionnalité de l'app que la bascule conserve explicitement.
// Ils vivent dans Poster.swift et servent aux deux directions.

/// Les 8 contextes de l'ancienne direction.
///
/// Remplacé par `PosterContext`, qui suit le découpage réel des écrans du nouveau
/// design (les rails de l'accueil se règlent séparément de la grille). Sert encore
/// de clé de préférence dans `App/Features/Titles/TitlesView.swift` ; le
/// déménagement du store est la tâche `L1 bis`.
public enum CardDisplayContext: String, Codable, Sendable, CaseIterable, Identifiable {
    case home, titles, people, collections, gallery, bookmarks, genre, filmography
    public var id: String { rawValue }
}

public struct CardMetrics: Sendable, Hashable {
    public let width: CGFloat
    public let aspect: CGFloat
    public let spacing: CGFloat
    public let radius: CGFloat
    public let showsMeta: Bool
    public let titleLineLimit: Int

    public init(
        width: CGFloat,
        aspect: CGFloat,
        spacing: CGFloat,
        radius: CGFloat,
        showsMeta: Bool,
        titleLineLimit: Int
    ) {
        self.width = width
        self.aspect = aspect
        self.spacing = spacing
        self.radius = radius
        self.showsMeta = showsMeta
        self.titleLineLimit = titleLineLimit
    }

    public var height: CGFloat { width / aspect }

    public static func metrics(_ layout: CardLayout, _ size: CardSize) -> CardMetrics {
        switch (layout, size) {
        case (.portrait, .compact):
            .init(
                width: 104, aspect: layout.aspectRatio, spacing: 8, radius: LegacyRadius.md,
                showsMeta: false, titleLineLimit: 1)
        case (.portrait, .medium):
            .init(
                width: 148, aspect: layout.aspectRatio, spacing: 12, radius: LegacyRadius.lg,
                showsMeta: true, titleLineLimit: 2)
        case (.portrait, .large):
            .init(
                width: 196, aspect: layout.aspectRatio, spacing: 16, radius: LegacyRadius.lg,
                showsMeta: true, titleLineLimit: 2)
        case (.landscape, .compact):
            .init(
                width: 200, aspect: layout.aspectRatio, spacing: 10, radius: LegacyRadius.md,
                showsMeta: true, titleLineLimit: 1)
        case (.landscape, .medium):
            .init(
                width: 264, aspect: layout.aspectRatio, spacing: 14, radius: LegacyRadius.lg,
                showsMeta: true, titleLineLimit: 2)
        case (.landscape, .large):
            .init(
                width: 340, aspect: layout.aspectRatio, spacing: 18, radius: LegacyRadius.lg,
                showsMeta: true, titleLineLimit: 2)
        }
    }

    public static func portrait(_ size: CardSize) -> CardMetrics { metrics(.portrait, size) }
    public static func landscape(_ size: CardSize) -> CardMetrics { metrics(.landscape, size) }

    /// Colonnes adaptatives pour `LazyVGrid` — la virtualisation est native.
    public var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: width), spacing: spacing)]
    }
}

/// Réglage persistable d'un contexte de l'ancienne direction.
///
/// Remplacé par `PosterSetting`.
public struct CardDisplaySetting: Codable, Sendable, Hashable {
    public var layout: CardLayout
    public var size: CardSize

    public init(layout: CardLayout = .portrait, size: CardSize = .medium) {
        self.layout = layout
        self.size = size
    }

    public var metrics: CardMetrics { .metrics(layout, size) }

    public static let `default` = CardDisplaySetting()
}
