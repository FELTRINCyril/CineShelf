import Foundation

/// Les énumérations du modèle (`docs/02` §3.1).
///
/// Motif employé partout : la propriété **persistée** est le `rawValue`
/// (`String`), l'énumération est exposée en propriété calculée. C'est ce qui
/// rend les `#Predicate` fiables et évite les surprises de miroir CloudKit.

public enum TitleKind: String, Codable, CaseIterable, Sendable {
    case movie, series, documentary, short, other
}

public enum DatePrecision: String, Codable, CaseIterable, Sendable {
    case year, month, day
}

public enum PersonRole: String, Codable, CaseIterable, Sendable {
    case actor, social, director, writer, crew
}

public enum CreditRole: String, Codable, CaseIterable, Sendable {
    case cast, director, writer, producer, composer, crew
}

public enum GenreTarget: String, Codable, CaseIterable, Sendable {
    case title, person, savedLink, collection
}

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case image, video, embed
}

public enum MediaSlot: String, Codable, CaseIterable, Sendable {
    case primary, portrait, backdrop, gallery
}

public enum CropContext: String, Codable, CaseIterable, Sendable {
    case standard, card, list, hero, side, detail, coverCard, coverHero, avatar
}

public enum SavedLinkKind: String, Codable, CaseIterable, Sendable {
    case website, video, article, store, social, other
}
