import SwiftUI

// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Les symboles que la correspondance de la section 8 ne reprend pas, et le
// mécanisme de paire état-inactif / état-actif que le banc d'essai utilise.
//
// La direction courante n'expose que des `String`, comme la table du handoff : un
// état plein est l'affaire du composant qui le rend, pas du token. Quand `Legacy/`
// partira avec `V12`, `Icon.rating` et `Icon.watched` redeviendront libres et
// pourront reprendre les noms courts de `ratingStar` et `watchedMark`.
//
// Rien de neuf ne doit lire ce fichier. Voir README.md de ce dossier.

extension Icon {

    // Entités que la nouvelle navigation ne nomme pas comme telles.
    public static let series = "tv"
    public static let genres = "tag"
    public static let library = "books.vertical"
    public static let archived = "archivebox"

    // Sélecteur de disposition de l'ancienne direction. La nouvelle utilise
    // `rectangle.portrait` et `rectangle`, qui disent la forme de la carte plutôt
    // que la forme de la liste.
    public static let layoutGrid = "square.grid.2x2"
    public static let layoutList = "rectangle.grid.1x2"

    // Paires état inactif / actif.
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
