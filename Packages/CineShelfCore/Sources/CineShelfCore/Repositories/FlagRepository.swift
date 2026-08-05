import Foundation
import SwiftData

/// Accès aux états par profil (`docs/02` §3.2 ter).
///
/// Règle d'hygiène : un flag repassé à `isEmpty` est supprimé, sinon la base se
/// remplit d'enregistrements vides et le quota iCloud avec.
@MainActor
public struct FlagRepository {
    let context: ModelContext
    let profile: Profile

    public init(context: ModelContext, profile: Profile) {
        self.context = context
        self.profile = profile
    }

    public func flag(for title: Title, createIfNeeded: Bool = false) -> TitleFlag? {
        if let existing = title.flags?.first(where: { $0.profile?.id == profile.id }) {
            return existing
        }
        guard createIfNeeded else { return nil }
        let flag = TitleFlag()
        flag.profile = profile
        flag.title = title
        context.insert(flag)
        return flag
    }

    public func toggleFavorite(_ title: Title) {
        mutate(title) { $0.isFavorite.toggle() }
    }

    public func toggleWatchlist(_ title: Title) {
        mutate(title) { $0.isInWatchlist.toggle() }
    }

    /// Bascule « vu », en horodatant : `watchedAt` sert au fil d'activité et au
    /// tri « vus récemment ». Le remettre à `nil` en dévisionnant évite une date
    /// orpheline qui survivrait au flag.
    public func toggleWatched(_ title: Title) {
        mutate(title) { flag in
            flag.isWatched.toggle()
            flag.watchedAt = flag.isWatched ? .now : nil
        }
    }

    /// Note personnelle sur 10, comme `Title.rating`. `nil` efface la note.
    public func setPersonalRating(_ rating: Double?, on title: Title) {
        mutate(title) { $0.personalRating = rating.map { min(max($0, 0), 10) } }
    }

    /// Applique une mutation puis fait le ménage : un flag redevenu vide est
    /// supprimé, sinon la base se remplit d'enregistrements sans information.
    private func mutate(_ title: Title, _ change: (TitleFlag) -> Void) {
        guard let flag = flag(for: title, createIfNeeded: true) else { return }
        change(flag)
        flag.updatedAt = .now
        if flag.isEmpty { context.delete(flag) }
    }
}

// MARK: - V3 · Le favori d'une image
//
// `MediaFlag` existait depuis le premier jour et **personne ne l'écrivait** : la visionneuse
// du bloc `6c` porte un « ♥ Favori » en ambre, et la barre de sélection du bloc `6f` le
// répète. C'est le premier appelant.
//
// Une extension et non trois lignes de plus dans le corps principal : le flag d'un titre a
// cinq propriétés et une sémantique de visionnage, celui d'un média n'en a qu'une. Les mêler
// aurait donné un `mutate` générique dont les deux moitiés n'ont rien en commun.

extension FlagRepository {

    public func flag(for asset: MediaAsset, createIfNeeded: Bool = false) -> MediaFlag? {
        if let existing = asset.flags?.first(where: { $0.profile?.id == profile.id }) {
            return existing
        }
        guard createIfNeeded else { return nil }
        let flag = MediaFlag()
        flag.profile = profile
        flag.asset = asset
        context.insert(flag)
        return flag
    }

    public func isFavorite(_ asset: MediaAsset) -> Bool {
        flag(for: asset)?.isFavorite ?? false
    }

    /// Même règle d'hygiène que pour un titre : un flag redevenu vide est supprimé.
    ///
    /// Elle compte davantage ici, et c'est arithmétique : une bibliothèque a des centaines de
    /// titres et des **milliers** d'images. Un `MediaFlag` vide par image défavorisée serait la
    /// plus grosse table de la base, et elle traverserait CloudKit.
    public func toggleFavorite(_ asset: MediaAsset) {
        guard let flag = flag(for: asset, createIfNeeded: true) else { return }
        flag.isFavorite.toggle()
        flag.updatedAt = .now
        if flag.isEmpty { context.delete(flag) }
    }
}
