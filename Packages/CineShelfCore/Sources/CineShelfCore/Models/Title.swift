import Foundation
import SwiftData

/// Un titre : film **et** série, distingués par `kind`.
@Model
public final class Title {
    public var id = UUID()

    // Identité
    public var kindRaw: String = TitleKind.movie.rawValue
    public var name: String = ""
    public var originalName: String?
    /// Maintenu par `refreshDerived()`.
    public var sortName: String = ""
    public var summary: String?

    // Sortie
    public var releaseDate: Date?
    public var releasePrecisionRaw: String = DatePrecision.day.rawValue

    // Durée
    public var runtimeMinutes: Int?
    public var seasonCount: Int?
    public var episodeCount: Int?

    /// Note du catalogue, 0–10. La note personnelle est dans `TitleFlag`.
    public var rating: Double?

    // Visibilité
    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    /// Corbeille : une suppression synchronisée est irréversible.
    public var deletedAt: Date?

    /// Maintenu par `refreshDerived()`. Remplace l'index FTS5.
    public var searchText: String = ""

    public var createdAt = Date()
    public var updatedAt = Date()

    // Relations
    public var library: Library?
    public var collection: TitleCollection?
    @Relationship(inverse: \Genre.titles)
    public var genres: [Genre]? = []
    @Relationship(deleteRule: .cascade, inverse: \Credit.title)
    public var credits: [Credit]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.title)
    public var attachments: [MediaAttachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.title)
    public var links: [ResourceLink]? = []
    /// Un flag par profil, créé à la demande.
    @Relationship(deleteRule: .cascade, inverse: \TitleFlag.title)
    public var flags: [TitleFlag]? = []

    public init(name: String = "", kind: TitleKind = .movie) {
        self.name = name
        self.kindRaw = kind.rawValue
        refreshDerived()
    }
}

extension Title {
    public var kind: TitleKind {
        get { TitleKind(rawValue: kindRaw) ?? .movie }
        set { kindRaw = newValue.rawValue }
    }

    public var releasePrecision: DatePrecision {
        get { DatePrecision(rawValue: releasePrecisionRaw) ?? .day }
        set { releasePrecisionRaw = newValue.rawValue }
    }

    public var releaseYear: Int? {
        releaseDate.map { Calendar.current.component(.year, from: $0) }
    }

    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    public func refreshDerived() {
        sortName =
            name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = [name, originalName, summary]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        updatedAt = .now
    }
}
