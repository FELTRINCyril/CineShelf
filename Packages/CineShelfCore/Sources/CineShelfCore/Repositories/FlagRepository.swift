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
        guard let flag = flag(for: title, createIfNeeded: true) else { return }
        flag.isFavorite.toggle()
        flag.updatedAt = .now
        if flag.isEmpty { context.delete(flag) }
    }
}
