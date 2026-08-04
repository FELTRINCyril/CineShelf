import Foundation

/// Les recherches récentes, par profil.
///
/// **Hors du modèle CloudKit, et pas par commodité.** `docs/02` §3.10 range les
/// préférences d'appareil hors du schéma ; les recherches récentes le sont pour une
/// raison de plus : ce qu'on a cherché est une trace d'usage, pas une donnée du
/// catalogue. La synchroniser ferait apparaître les recherches d'un appareil sur un
/// autre, et celles d'un profil dans la session d'un autre. Elles vivent donc dans
/// `UserDefaults`, jamais dans `NSUbiquitousKeyValueStore`.
///
/// Bornées et dédoublonnées : une liste de suggestions n'a de valeur que courte, et
/// retaper trois fois le même terme ne doit pas remplir l'écran de trois lignes
/// identiques.
/// Non `Sendable`, parce que `UserDefaults` ne l'est pas — et il n'y a pas lieu de
/// forcer : le store se construit là où on s'en sert, il ne traverse aucune frontière
/// d'isolation.
public struct RecentSearchStore {

    /// Au-delà, les plus anciennes tombent. Dix tient dans une section de
    /// suggestions sans défilement.
    public static let limit = 10

    private let defaults: UserDefaults
    private let profileID: UUID?

    /// - Parameters:
    ///   - profileID: le profil concerné. `nil` recouvre le cas où aucun profil n'est
    ///     ouvert — le sélecteur n'a pas encore tranché — et lui donne son propre
    ///     casier plutôt que de polluer celui d'un profil réel.
    ///   - defaults: injecté pour que les tests n'écrivent pas dans le domaine de
    ///     l'application. Sans ça, une exécution de la suite laisserait des
    ///     recherches fictives dans l'app installée.
    public init(profileID: UUID?, defaults: UserDefaults = .standard) {
        self.profileID = profileID
        self.defaults = defaults
    }

    private var key: String {
        "search.recent.\(profileID?.uuidString ?? "none")"
    }

    /// Les termes, du plus récent au plus ancien.
    public var terms: [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    /// Enregistre un terme en tête.
    ///
    /// Le dédoublonnage se fait sur la forme **repliée** — sans accents ni casse —
    /// mais c'est la forme **saisie** qui est conservée : « Amélie » et « amelie »
    /// sont la même recherche, et il vaut mieux réafficher ce que l'utilisateur a
    /// tapé en dernier que la version décapitalisée.
    ///
    /// Un terme vide, ou réduit à des espaces, n'est pas enregistré : c'est l'état
    /// `SearchOutcome.idle`, et il n'y a rien à retenir d'une recherche qui n'a pas eu
    /// lieu.
    public func record(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let folded = Self.folded(trimmed)
        var updated = terms.filter { Self.folded($0) != folded }
        updated.insert(trimmed, at: 0)
        defaults.set(Array(updated.prefix(Self.limit)), forKey: key)
    }

    /// Retire un terme précis, sur sa forme repliée.
    public func remove(_ term: String) {
        let folded = Self.folded(term.trimmingCharacters(in: .whitespacesAndNewlines))
        defaults.set(terms.filter { Self.folded($0) != folded }, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }

    private static func folded(_ term: String) -> String {
        term.foldedForMatching
    }
}
