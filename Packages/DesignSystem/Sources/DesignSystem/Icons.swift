import SwiftUI

// MARK: - SF Symbols
//
// Constantes typées : aucune chaîne de symbole dispersée dans les vues.
// Rendu hiérarchique par défaut ; `.palette` pour les états à deux couleurs.

public enum Icon {

    // Navigation / entités
    public static let titles = "film.stack"
    public static let series = "tv"
    public static let people = "person.2"
    public static let collections = "square.stack"
    public static let genres = "tag"
    public static let gallery = "photo.on.rectangle.angled"
    public static let bookmarks = "bookmark"
    public static let search = "magnifyingglass"
    public static let library = "books.vertical"
    public static let settings = "gearshape"

    // Actions
    public static let crop = "crop"
    public static let importItem = "square.and.arrow.down"
    public static let exportItem = "square.and.arrow.up"
    public static let merge = "arrow.triangle.merge"
    public static let sort = "arrow.up.arrow.down"
    public static let filter = "line.3.horizontal.decrease.circle"
    public static let sync = "arrow.triangle.2.circlepath"

    // Affichage
    public static let layoutGrid = "square.grid.2x2"
    public static let layoutList = "rectangle.grid.1x2"

    // États d'élément
    public static let isPrivate = "lock"
    public static let archived = "archivebox"

    // Paires état inactif / actif
    public static let favorite = SymbolPair("heart", "heart.fill")
    public static let watchlist = SymbolPair("bookmark.circle", "bookmark.circle.fill")
    public static let watched = SymbolPair("checkmark.circle", "checkmark.circle.fill")
    public static let rating = SymbolPair("star", "star.fill", partial: "star.leadinghalf.filled")
}

/// Symbole à deux (ou trois) états, pour piloter `.contentTransition(.symbolEffect(.replace))`.
public struct SymbolPair: Sendable, Hashable {
    public let off: String
    public let on: String
    public let partial: String?

    public init(_ off: String, _ on: String, partial: String? = nil) {
        self.off = off
        self.on = on
        self.partial = partial
    }

    public func name(isOn: Bool) -> String { isOn ? on : off }

    /// Pour une note : plein, à moitié, vide.
    public func name(fill: Double) -> String {
        switch fill {
        case ..<0.25: off
        case ..<0.75: partial ?? on
        default: on
        }
    }
}

// MARK: - Confort

extension Image {
    /// Symbole du design system, rendu hiérarchique par défaut.
    public static func ds(_ symbol: String) -> some View {
        Image(systemName: symbol).symbolRenderingMode(.hierarchical)
    }
}

extension View {
    /// Remplacement animé d'un symbole d'état, sous réserve de Reduce Motion.
    public func dsSymbolReplace<V: Equatable>(value: V) -> some View {
        contentTransition(.symbolEffect(.replace))
            .dsAnimation(Motion.quick, value: value)
    }
}
