import Foundation
import SwiftData

/// Un signet autonome, rattaché à une bibliothèque et non à une entité.
@Model
public final class SavedLink {
    public var id = UUID()
    public var urlString: String = ""
    public var name: String?
    public var notes: String?
    public var faviconData: Data?
    public var kindRaw: String = SavedLinkKind.website.rawValue
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    /// Maintenu par `refreshDerived()`.
    public var searchText: String = ""
    public var createdAt = Date()
    public var updatedAt = Date()

    public var library: Library?
    public var genre: Genre?

    public init(urlString: String = "") {
        self.urlString = urlString
        refreshDerived()
    }
}

extension SavedLink {
    public var kind: SavedLinkKind {
        get { SavedLinkKind(rawValue: kindRaw) ?? .website }
        set { kindRaw = newValue.rawValue }
    }

    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    public func refreshDerived() {
        searchText =
            [name, notes, urlString]
            .compactMap { $0 }
            .joined(separator: " ")
            .foldedForMatching
        updatedAt = .now
    }
}
