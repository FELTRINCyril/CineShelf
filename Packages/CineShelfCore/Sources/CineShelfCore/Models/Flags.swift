import Foundation
import SwiftData

/// État d'un titre pour un profil donné (`docs/02` §3.2 ter).
///
/// La watchlist de Cyril n'est pas celle d'Invité : ces états ne peuvent pas
/// vivre sur `Title`. Un flag repassé à `isEmpty` est supprimé, sinon la base
/// se remplit d'enregistrements vides et le quota iCloud avec.
@Model
public final class TitleFlag {
    public var id = UUID()
    public var isFavorite: Bool = false
    public var isInWatchlist: Bool = false
    public var isWatched: Bool = false
    public var watchedAt: Date?
    /// Note du profil, distincte de `Title.rating` qui est celle du catalogue.
    public var personalRating: Double?
    public var updatedAt = Date()

    public var profile: Profile?
    public var title: Title?

    public init() {}

    /// Vrai si l'objet ne porte plus aucune information : à supprimer.
    public var isEmpty: Bool {
        !isFavorite && !isInWatchlist && !isWatched && personalRating == nil
    }
}

/// État d'une personne pour un profil donné.
@Model
public final class PersonFlag {
    public var id = UUID()
    public var isFavorite: Bool = false
    public var updatedAt = Date()

    public var profile: Profile?
    public var person: Person?

    public init() {}

    public var isEmpty: Bool { !isFavorite }
}

/// État d'un média pour un profil donné : le favori de galerie.
@Model
public final class MediaFlag {
    public var id = UUID()
    public var isFavorite: Bool = false
    public var updatedAt = Date()

    public var profile: Profile?
    public var asset: MediaAsset?

    public init() {}

    public var isEmpty: Bool { !isFavorite }
}
