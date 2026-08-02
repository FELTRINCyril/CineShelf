import Foundation
import SwiftData

/// Une collection de titres. Nommée `TitleCollection` et non `Collection`,
/// pour ne pas masquer le protocole de la bibliothèque standard.
@Model
public final class TitleCollection {
    public var id = UUID()
    public var name: String = ""
    /// Maintenu par `refreshDerived()`.
    public var sortName: String = ""
    public var summary: String?
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    /// Maintenu par `refreshDerived()`.
    public var searchText: String = ""
    public var createdAt = Date()
    public var updatedAt = Date()

    public var library: Library?
    @Relationship(inverse: \Title.collection)
    public var titles: [Title]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.collection)
    public var attachments: [MediaAttachment]? = []
    /// Absent de `docs/02` §3.5, alors que `ResourceLink.collection` existe :
    /// sans ce côté, la relation n'a pas d'inverse et CloudKit refuse le schéma.
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.collection)
    public var links: [ResourceLink]? = []

    public init(name: String = "") {
        self.name = name
        refreshDerived()
    }
}

extension TitleCollection {
    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    public func refreshDerived() {
        sortName =
            name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = [name, summary]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        updatedAt = .now
    }
}
