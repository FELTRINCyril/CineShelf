import Foundation
import SwiftData

/// Un genre, rattaché à une ou plusieurs cibles.
///
/// CloudKit interdit `@Attribute(.unique)` : le dédoublonnage passe par
/// `nameKey` et un `GenreRepository.findOrCreate(name:target:in:)`.
@Model
public final class Genre {
    public var id = UUID()
    public var name: String = ""
    /// Clé de dédoublonnage applicatif, maintenue par `refreshDerived()`.
    public var nameKey: String = ""
    public var targetRaw: String = GenreTarget.title.rawValue
    /// Jeton du catalogue de couleurs, jamais un hexadécimal.
    public var colorToken: String?
    public var isPinned: Bool = false
    public var pinIndex: Int = 0
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var createdAt = Date()
    public var updatedAt = Date()

    public var library: Library?
    public var titles: [Title]? = []
    public var people: [Person]? = []
    @Relationship(inverse: \SavedLink.genre)
    public var savedLinks: [SavedLink]? = []

    public init(name: String = "", target: GenreTarget = .title) {
        self.name = name
        self.targetRaw = target.rawValue
        self.nameKey = Genre.key(for: name)
    }

    public static func key(for name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Genre {
    public var target: GenreTarget {
        get { GenreTarget(rawValue: targetRaw) ?? .title }
        set { targetRaw = newValue.rawValue }
    }

    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    public func refreshDerived() {
        nameKey = Genre.key(for: name)
        updatedAt = .now
    }
}
