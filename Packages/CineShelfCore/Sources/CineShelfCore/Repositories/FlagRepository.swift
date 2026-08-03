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
