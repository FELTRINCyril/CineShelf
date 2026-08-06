import Foundation

// MARK: - L18 · Les statistiques
//
// **Des séries, pas des graphiques.** La fiche est explicite : « les agrégations rendent des
// séries ; `Swift Charts` viendra avec `V11` ». Ce fichier n'importe donc ni SwiftUI ni Charts,
// et c'est ce qui permet de le tester — et à un widget de s'en servir.
//
// **Aucun `fetch` ici.** Les quatre agrégations prennent `[Title]` et rendent des tableaux :
// l'appelant décide de ce qu'il compte — la bibliothèque courante, une sélection, un profil.
// Une fonction qui interrogerait le magasin elle-même déciderait à sa place, et il faudrait
// une variante par question.

/// Une part d'une répartition : un libellé, un compte.
public struct StatisticSlice: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let count: Int

    public init(id: String, label: String, count: Int) {
        self.id = id
        self.label = label
        self.count = count
    }
}

public enum LibraryStatistics {

    /// La répartition par genre, du plus fourni au moins fourni.
    ///
    /// **Un titre à trois genres compte trois fois**, et la somme des parts dépasse donc le
    /// nombre de titres. C'est correct pour la question posée — « combien de drames ai-je ? » —
    /// et faux pour une autre — « quelle part de ma bibliothèque est du drame ? ». La seconde
    /// n'a pas de réponse honnête tant qu'un titre a plusieurs genres, et c'est pour ça qu'on
    /// ne la rend pas.
    public static func byGenre(_ titles: [Title]) -> [StatisticSlice] {
        var counts: [UUID: (name: String, count: Int)] = [:]
        for title in titles {
            for genre in title.genres ?? [] {
                counts[genre.id, default: (genre.name, 0)].count += 1
            }
        }
        return
            counts
            .map { StatisticSlice(id: $0.key.uuidString, label: $0.value.name, count: $0.value.count) }
            .sorted { ($0.count, $1.label) > ($1.count, $0.label) }
    }

    /// La répartition par décennie, de la plus ancienne à la plus récente.
    ///
    /// **Chronologique et non par compte**, à la différence des genres : une décennie a un
    /// ordre naturel, et le trier par volume rendrait la série illisible — on lit une frise,
    /// pas un classement. Les titres sans date sont **omis**, pas rangés dans une décennie
    /// zéro : « 0 » se lirait comme une décennie réelle sur un axe.
    public static func byDecade(_ titles: [Title]) -> [StatisticSlice] {
        var counts: [Int: Int] = [:]
        for title in titles {
            guard let year = title.releaseYear else { continue }
            counts[(year / 10) * 10, default: 0] += 1
        }
        return
            counts
            .sorted { $0.key < $1.key }
            .map { StatisticSlice(id: "\($0.key)", label: "\($0.key)s", count: $0.value) }
    }

    /// La répartition par note, en cinq crans — la note du modèle est sur 10, l'affichage sur 5.
    ///
    /// `TitleFormat.fiveStarRating` divise déjà par deux côté présentation ; ici on reste dans
    /// le modèle et on regroupe par étoile pleine. **Les titres sans note sont omis** : « pas
    /// noté » n'est pas une note basse, et le compter en 0 ferait mentir la moyenne visuelle.
    public static func byRating(_ titles: [Title]) -> [StatisticSlice] {
        var counts: [Int: Int] = [:]
        for title in titles {
            guard let rating = title.rating else { continue }
            let star = max(1, min(5, Int((rating / 2).rounded(.up))))
            counts[star, default: 0] += 1
        }
        return (1...5).compactMap { star in
            guard let count = counts[star] else { return nil }
            return StatisticSlice(id: "\(star)", label: "\(star) ★", count: count)
        }
    }

    /// La durée totale, en minutes. Les titres sans durée valent zéro, ce qui est exact.
    ///
    /// **Les séries ne sont pas comptées**, et c'est une décision : `runtimeMinutes` est la
    /// durée d'un film ; une série porte `seasonCount` et `episodeCount` mais **aucune durée
    /// d'épisode**, donc son temps total est inconnu. L'estimer à 45 minutes par épisode
    /// produirait un chiffre plausible et faux — exactement ce que le projet refuse ailleurs.
    public static func totalRuntime(_ titles: [Title]) -> Int {
        titles.reduce(0) { total, title in
            guard title.kind == .movie else { return total }
            return total + (title.runtimeMinutes ?? 0)
        }
    }

    /// Ce que le total ne couvre pas, pour que l'écran puisse le dire.
    ///
    /// Sans ce compte, « 412 heures » se lirait comme le temps de toute la bibliothèque, et
    /// personne ne saurait que les séries n'y sont pas. Un chiffre incomplet qui s'annonce
    /// complet est pire qu'un chiffre absent.
    public static func runtimeExclusions(_ titles: [Title]) -> (series: Int, withoutRuntime: Int) {
        let series = titles.count { $0.kind != .movie }
        let missing = titles.count { $0.kind == .movie && $0.runtimeMinutes == nil }
        return (series, missing)
    }
}
