import SwiftUI

// MARK: - Matrice layout × size
//
// 2 dispositions × 3 tailles, réglables indépendamment sur 8 contextes.
// `CardDisplayContext` porte la persistance (Codable) sans dépendre d'un modèle métier.

public enum CardLayout: String, Codable, Sendable, CaseIterable, Identifiable {
    case portrait, landscape
    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .portrait: "Portrait"
        case .landscape: "Paysage"
        }
    }

    public var symbol: String {
        switch self {
        case .portrait: Icon.layoutGrid
        case .landscape: Icon.layoutList
        }
    }
}

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

/// Les 8 contextes où la disposition est réglable indépendamment.
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
            .init(width: 104, aspect: Ratio.poster, spacing: 8, radius: Radius.md, showsMeta: false, titleLineLimit: 1)
        case (.portrait, .medium):
            .init(width: 148, aspect: Ratio.poster, spacing: 12, radius: Radius.lg, showsMeta: true, titleLineLimit: 2)
        case (.portrait, .large):
            .init(width: 196, aspect: Ratio.poster, spacing: 16, radius: Radius.lg, showsMeta: true, titleLineLimit: 2)
        case (.landscape, .compact):
            .init(
                width: 200, aspect: Ratio.landscape, spacing: 10, radius: Radius.md, showsMeta: true, titleLineLimit: 1)
        case (.landscape, .medium):
            .init(
                width: 264, aspect: Ratio.landscape, spacing: 14, radius: Radius.lg, showsMeta: true, titleLineLimit: 2)
        case (.landscape, .large):
            .init(
                width: 340, aspect: Ratio.landscape, spacing: 18, radius: Radius.lg, showsMeta: true, titleLineLimit: 2)
        }
    }

    public static func portrait(_ size: CardSize) -> CardMetrics { metrics(.portrait, size) }
    public static func landscape(_ size: CardSize) -> CardMetrics { metrics(.landscape, size) }

    /// Colonnes adaptatives pour `LazyVGrid` — la virtualisation est native.
    public var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: width), spacing: spacing)]
    }
}

/// Réglage persistable d'un contexte : `@AppStorage` côté app, sans dépendance ici.
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
