import Foundation

// MARK: - Modèles de présentation
//
// DesignSystem ne dépend de RIEN : ni SwiftData, ni le modèle métier.
// Les composants consomment ces petites structures ; l'app fournira plus tard
// un mapping `Title -> PosterCardModel`. `Sendable` + valeurs immuables :
// utilisables tels quels sous concurrence stricte.

public struct PosterCardModel: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, Codable { case movie, series, person, collection }

    public let id: String
    public let title: String
    public let kind: Kind
    /// Métadonnées déjà formatées, affichées en chiffres tabulaires. Ex. « 1994 · 2 h 22 ».
    public let meta: String?
    /// Note sur 5, `nil` si non notée.
    public let rating: Double?
    public let imageURL: URL?
    /// Placeholder blurhash le temps du chargement, pour éviter tout saut de mise en page.
    public let blurHash: String?
    public let isFavorite: Bool
    public let isInWatchlist: Bool
    public let isWatched: Bool
    public let isPrivate: Bool
    public let isArchived: Bool

    public init(
        id: String,
        title: String,
        kind: Kind = .movie,
        meta: String? = nil,
        rating: Double? = nil,
        imageURL: URL? = nil,
        blurHash: String? = nil,
        isFavorite: Bool = false,
        isInWatchlist: Bool = false,
        isWatched: Bool = false,
        isPrivate: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.meta = meta
        self.rating = rating
        self.imageURL = imageURL
        self.blurHash = blurHash
        self.isFavorite = isFavorite
        self.isInWatchlist = isInWatchlist
        self.isWatched = isWatched
        self.isPrivate = isPrivate
        self.isArchived = isArchived
    }

    /// « {titre}, {méta}, {états} » — base de l'annonce VoiceOver.
    public var accessibilityDescription: String {
        var parts = [title]
        if let meta { parts.append(meta) }
        if isFavorite { parts.append("favori") }
        if isInWatchlist { parts.append("dans la watchlist") }
        if isWatched { parts.append("vu") }
        if isPrivate { parts.append("privé") }
        if isArchived { parts.append("archivé") }
        return parts.joined(separator: ", ")
    }
}

public struct ShelfRailModel: Identifiable, Hashable, Sendable {
    public let id: String
    /// Libellé du rail, affiché en majuscules. Ex. « Action ».
    public let label: String
    public let items: [PosterCardModel]
    /// Total réel de la collection, souvent > `items.count` (page chargée).
    public let totalCount: Int

    public init(id: String, label: String, items: [PosterCardModel], totalCount: Int? = nil) {
        self.id = id
        self.label = label
        self.items = items
        self.totalCount = totalCount ?? items.count
    }

    /// Compteur monospace du filet : « 01–08 / 24 ».
    public func counter(visible range: ClosedRange<Int>) -> String {
        let lo = String(format: "%02d", max(1, range.lowerBound + 1))
        let hi = String(format: "%02d", min(totalCount, range.upperBound + 1))
        return "\(lo)–\(hi) / \(totalCount)"
    }

    /// Portion visible, matérialisée en Ember sous le filet.
    public func progress(visible range: ClosedRange<Int>) -> ClosedRange<Double> {
        guard totalCount > 0 else { return 0...0 }
        let total = Double(totalCount)
        return Double(range.lowerBound) / total...min(1, Double(range.upperBound + 1) / total)
    }

    public var accessibilityLabel: String { "\(label), \(totalCount) titres" }
}

public struct MediaThumbnailModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let imageURL: URL?
    public let blurHash: String?
    public let aspect: Double
    public let caption: String?

    public init(
        id: String, imageURL: URL? = nil, blurHash: String? = nil, aspect: Double = 2.0 / 3.0, caption: String? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.blurHash = blurHash
        self.aspect = aspect
        self.caption = caption
    }
}

public enum SyncState: Sendable, Hashable {
    case upToDate(Date)
    case syncing(Double?)
    case offline
    case failed(String)
}

// MARK: - Données d'exemple (previews)
//
// Aucune image réseau : les previews s'appuient sur le placeholder,
// ce qui teste aussi l'état de chargement.

extension PosterCardModel {
    public static let sample = PosterCardModel(
        id: "s1", title: "Le Conformiste", meta: "1970 · 1 h 51",
        rating: 4.5, isFavorite: true, isWatched: true
    )

    public static let samples: [PosterCardModel] = [
        .init(id: "1", title: "Le Conformiste", meta: "1970 · 1 h 51", rating: 4.5, isFavorite: true, isWatched: true),
        .init(id: "2", title: "Stalker", meta: "1979 · 2 h 41", rating: 5, isWatched: true),
        .init(id: "3", title: "Chungking Express", meta: "1994 · 1 h 42", rating: 4, isInWatchlist: true),
        .init(id: "4", title: "Une séparation", meta: "2011 · 2 h 03", rating: 4.5),
        .init(id: "5", title: "Les Ailes du désir", meta: "1987 · 2 h 08", isInWatchlist: true),
        .init(id: "6", title: "Portrait de la jeune fille en feu", meta: "2019 · 2 h 02", rating: 5, isFavorite: true),
        .init(id: "7", title: "Voyage à Tokyo", meta: "1953 · 2 h 16", isPrivate: true),
        .init(id: "8", title: "Le Samouraï", meta: "1967 · 1 h 45", rating: 4, isArchived: true),
        .init(id: "9", title: "Répulsion", meta: "1965 · 1 h 45"),
        .init(id: "10", title: "La Nuit du chasseur", meta: "1955 · 1 h 32", rating: 5)
    ]
}

extension ShelfRailModel {
    public static let sample = ShelfRailModel(
        id: "action", label: "Action", items: PosterCardModel.samples, totalCount: 24)

    public static let samples: [ShelfRailModel] = [
        .init(id: "recent", label: "Ajouts récents", items: Array(PosterCardModel.samples.prefix(6)), totalCount: 6),
        .init(id: "action", label: "Action", items: PosterCardModel.samples, totalCount: 24),
        .init(id: "docs", label: "Documentaires", items: Array(PosterCardModel.samples.suffix(4)), totalCount: 11)
    ]
}
