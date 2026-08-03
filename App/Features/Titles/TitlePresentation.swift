import CineShelfCore
import DesignSystem
import Foundation

// MARK: - La frontière entre le modèle métier et le design system
//
// `DesignSystem` ne connaît pas `Title` : c'est ce qui lui permet d'être testé
// et catalogué sans SwiftData. `CineShelfCore` ne connaît pas SwiftUI : c'est ce
// qui lui permet de tourner dans un `@ModelActor`. Les deux se rencontrent ici,
// et **uniquement** ici.
//
// Ce fichier est le patron des prompts 14 à 17 : Personnes, Collections,
// Galerie et Signets auront chacun le leur, dans leur propre dossier `Features`.
// Trois règles à reprendre telles quelles :
//
//   1. La conversion est un `init` sur le type de présentation, pas une méthode
//      sur le `@Model`. Un modèle qui sait se dessiner finit par importer SwiftUI.
//   2. Tout ce qui est formaté pour l'œil — durée, année, note — l'est ici. Une
//      vue qui formate est une vue qui duplique.
//   3. Les données propres au profil (favori, vu, note perso) sont passées en
//      paramètre, jamais lues depuis le titre : `Title.flags` contient les flags
//      de *tous* les profils.

extension PosterCardModel {

    /// Construit la carte d'un titre pour un profil donné.
    ///
    /// - Parameters:
    ///   - title: le titre à présenter.
    ///   - flag: son état **pour le profil courant**. `nil` si le titre n'a
    ///     jamais été marqué : c'est le cas le plus fréquent, et il ne coûte rien.
    init(_ title: Title, flag: TitleFlag?) {
        self.init(
            id: title.id.uuidString,
            title: title.name,
            kind: .init(title.kind),
            meta: TitleFormat.meta(for: title),
            rating: TitleFormat.fiveStarRating(title.rating),
            imageURL: AssetURL.poster(for: title),
            blurHash: TitleFormat.primaryAsset(of: title)?.blurHash,
            isFavorite: flag?.isFavorite ?? false,
            isInWatchlist: flag?.isInWatchlist ?? false,
            isWatched: flag?.isWatched ?? false,
            isPrivate: title.isPrivate,
            isArchived: title.isArchived
        )
    }
}

extension PosterCardModel.Kind {

    /// `TitleKind` a cinq cas, la carte quatre.
    ///
    /// Documentaires, courts métrages et « autre » se replient sur `.movie` :
    /// la carte ne s'en sert que pour choisir un symbole de repli, et un
    /// documentaire se présente comme un film. Le vrai genre reste sur le titre.
    init(_ kind: TitleKind) {
        switch kind {
        case .series: self = .series
        case .movie, .documentary, .short, .other: self = .movie
        }
    }
}

// MARK: - Formatage

/// Les conversions d'affichage d'un titre. Regroupées pour que la fiche, la
/// carte et la ligne de tableau disent exactement la même chose.
enum TitleFormat {

    /// La ligne de métadonnées d'une carte : « 1994 · 2 h 22 ».
    ///
    /// Les séries annoncent leurs saisons plutôt que leur durée, qui pour elles
    /// ne veut rien dire.
    static func meta(for title: Title) -> String? {
        var parts: [String] = []

        if let year = title.releaseYear {
            parts.append(String(year))
        }

        switch title.kind {
        case .series:
            if let seasons = title.seasonCount, seasons > 0 {
                parts.append(seasons == 1 ? "1 saison" : "\(seasons) saisons")
            }
        default:
            if let runtime = runtime(title.runtimeMinutes) {
                parts.append(runtime)
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// « 2 h 22 », « 47 min ». Jamais « 142 min » : personne ne lit un film en
    /// minutes au-delà de l'heure.
    static func runtime(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder) min" }
        if remainder == 0 { return "\(hours) h" }
        return "\(hours) h \(String(format: "%02d", remainder))"
    }

    /// Le modèle note sur 10 (`docs/02` §3.3), la carte affiche des étoiles sur
    /// 5. La conversion est ici, une fois, plutôt que dans chaque vue.
    static func fiveStarRating(_ rating: Double?) -> Double? {
        guard let rating else { return nil }
        return min(max(rating, 0), 10) / 2
    }

    /// La note telle qu'on l'écrit : « 8,4 / 10 ».
    static func ratingText(_ rating: Double?) -> String? {
        guard let rating else { return nil }
        return "\(formatter.string(from: rating as NSNumber) ?? "\(rating)") / 10"
    }

    /// La jaquette d'un titre : la pièce jointe `.primary` de plus petit
    /// `orderIndex`, à défaut la première image attachée.
    static func primaryAsset(of title: Title) -> MediaAsset? {
        let attachments = title.attachments ?? []
        let primary =
            attachments
            .filter { $0.slot == .primary }
            .min { $0.orderIndex < $1.orderIndex }
        return (primary ?? attachments.min { $0.orderIndex < $1.orderIndex })?.asset
    }

    /// L'image d'en-tête 16/9, si le titre en a une.
    static func backdropAsset(of title: Title) -> MediaAsset? {
        (title.attachments ?? [])
            .filter { $0.slot == .backdrop }
            .min { $0.orderIndex < $1.orderIndex }?
            .asset
    }

    /// Le casting, dans l'ordre voulu par le modèle.
    static func cast(of title: Title) -> [Credit] {
        (title.credits ?? [])
            .filter { $0.person?.deletedAt == nil }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    static func genreNames(of title: Title) -> [String] {
        // `Genre` n'a pas de suppression douce (pas de `deletedAt`) : le seul
        // retrait possible est l'archivage.
        (title.genres ?? [])
            .filter { !$0.isArchived }
            .map(\.name)
            .sorted()
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
