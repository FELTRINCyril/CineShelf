import Foundation

// MARK: - L1 bis · Les préférences d'affichage, hors des vues
//
// **Le store était dans une vue, et il ne pouvait pas y rester.** `App/Features/Titles`
// portait un `PosterSettingStore` qui connaissait à la fois `UserDefaults` et les types de
// `DesignSystem` : les prompts 14 à 17 le réutiliseront, et un store rangé dans la
// fonctionnalité « Titres » aurait été recopié à chaque nouvel écran.
//
// **Le vocabulaire persisté est celui de la v1, et c'est une reprise, pas un choix.** La
// matrice `disposition × taille` est une fonctionnalité existante (`docs/06` §5), donc les
// noms d'origine font foi :
//
//     movies · actors · collections · social
//     home_movies · home_actors · home_collections · home_social
//
// Le jeu que portait l'intégration — `home, titles, people, collections, gallery,
// bookmarks, genre, filmography` — comptait bien huit entrées, mais **ce n'étaient pas les
// mêmes** : il inventait `gallery`, `bookmarks`, `genre` et `filmography` et perdait les
// quatre rails d'accueil. Ce n'était donc pas une reprise mais une invention, et elle
// aurait fait perdre son réglage à chaque contexte au premier lancement d'une version qui
// aurait relu de vraies données.
//
// **Pourquoi ce vocabulaire vit ici et le vocabulaire visuel dans `DesignSystem`.** La
// règle de dépendances de `docs/04` §1 interdit à l'un de connaître l'autre. Les deux jeux
// sont donc en double, ce qui est acceptable — et devient un bug le jour où quelqu'un
// ajoute un cas d'un seul côté, puisque **rien ne cesse de compiler** : le contexte
// nouveau perd simplement sa préférence au runtime. C'est `DisplayVocabularyTests`, dans
// la cible de test de l'app — le seul endroit qui voit les deux paquets —, qui affirme que
// les `rawValue` s'accordent.

/// Les huit contextes où la matrice `disposition × taille` est mémorisée.
///
/// Les `rawValue` sont ceux de la v1 : ce sont eux qui partent sur le disque, et une
/// préférence n'a de valeur que si elle se retrouve.
public enum DisplayContext: String, Codable, Sendable, CaseIterable {
    case movies
    case actors
    case collections
    case social
    case homeMovies = "home_movies"
    case homeActors = "home_actors"
    case homeCollections = "home_collections"
    case homeSocial = "home_social"

    /// La disposition et la taille par défaut de ce contexte.
    ///
    /// Les valeurs viennent du jeu visuel, où elles sont relevées des planches. Elles sont
    /// répétées ici plutôt que lues, parce que `CineShelfCore` n'importe pas
    /// `DesignSystem` — et `DisplayVocabularyTests` vérifie que les deux tables coïncident,
    /// sans quoi le défaut du disque et celui de l'écran divergeraient en silence.
    public var defaultPreference: DisplayPreference {
        switch self {
        case .movies, .homeMovies: DisplayPreference(layout: .portrait, size: .medium)
        case .actors, .homeActors: DisplayPreference(layout: .portrait, size: .compact)
        case .collections, .homeCollections, .social:
            DisplayPreference(layout: .landscape, size: .medium)
        case .homeSocial: DisplayPreference(layout: .landscape, size: .compact)
        }
    }
}

/// La disposition d'une carte. `rawValue` accordé à `CardLayout` de `DesignSystem`.
public enum DisplayLayout: String, Codable, Sendable, CaseIterable {
    case portrait, landscape
}

/// Le cran de taille d'une carte. `rawValue` accordé à `CardSize` de `DesignSystem`.
///
/// Trois crans et non une dimension : la taille rendue dépend du contexte — 92 pt dans un
/// rail de personnes, 148 pt dans la grille des titres — et c'est le contexte qui la
/// résout. Persister des points aurait figé une géométrie qui appartient au design.
public enum DisplaySize: String, Codable, Sendable, CaseIterable {
    case compact, medium, large
}

/// Ce qui est persisté pour un contexte, et **rien d'autre**.
///
/// `docs/02` §3.10 décrit `{layout, size, pageSize, sort, dir}`. `pageSize` est abandonné
/// (`docs/03` §2 : la grille charge à la demande) ; `sort` et `dir` appartiennent à
/// `TitleFilter`, que `NavigationModel` sérialise déjà. Les mettre ici créerait deux
/// sources de vérité. **Le jour où le tri doit persister par contexte, c'est `TitleFilter`
/// qui lira ce store — jamais ce store qui dupliquera `TitleFilter`.**
public struct DisplayPreference: Codable, Sendable, Hashable {
    public var layout: DisplayLayout
    public var size: DisplaySize

    public init(layout: DisplayLayout = .portrait, size: DisplaySize = .medium) {
        self.layout = layout
        self.size = size
    }
}

/// La préférence d'affichage d'un profil, par contexte.
///
/// Même statut que `RecentSearchStore` : hors du schéma CloudKit, parce que `docs/02` §3.10
/// range les préférences d'appareil hors du modèle. Un réglage de densité n'a d'ailleurs
/// aucune raison de traverser : un iPhone et un Mac n'affichent pas la même chose au même
/// cran.
///
/// Non `Sendable`, comme `RecentSearchStore` : `UserDefaults` ne l'est pas, et le store se
/// construit là où on s'en sert.
public struct DisplayPreferenceStore {

    private let defaults: UserDefaults
    private let profileID: UUID?

    /// - Parameters:
    ///   - profileID: le profil concerné. `nil` couvre le cas où le sélecteur n'a pas
    ///     encore tranché, et lui donne son propre casier plutôt que de polluer celui d'un
    ///     profil réel.
    ///   - defaults: injecté pour que les tests n'écrivent pas dans le domaine de
    ///     l'application.
    public init(profileID: UUID?, defaults: UserDefaults = .standard) {
        self.profileID = profileID
        self.defaults = defaults
    }

    /// La préférence enregistrée, ou le défaut du contexte.
    ///
    /// Une valeur illisible rend le défaut au lieu de propager l'erreur : une préférence
    /// d'affichage corrompue n'est pas un incident, c'est un réglage à reposer.
    public func preference(for context: DisplayContext) -> DisplayPreference {
        guard let data = defaults.data(forKey: key(context)),
            let decoded = try? JSONDecoder().decode(DisplayPreference.self, from: data)
        else { return context.defaultPreference }
        return decoded
    }

    public func save(_ preference: DisplayPreference, for context: DisplayContext) {
        guard let data = try? JSONEncoder().encode(preference) else { return }
        defaults.set(data, forKey: key(context))
    }

    /// Efface les huit contextes de ce profil. Sert au « réinitialiser l'affichage » des
    /// réglages, et aux tests.
    public func reset() {
        for context in DisplayContext.allCases {
            defaults.removeObject(forKey: key(context))
        }
    }

    /// Le préfixe porte le **vocabulaire**, pas seulement le sujet — et c'est une
    /// correction, pas une précaution.
    ///
    /// Trois jeux de clés ont existé pour la même préférence : `display.` au prompt 11
    /// (contextes `home, titles, people, collections, gallery, bookmarks, genre,
    /// filmography`), `poster.` à `I1` (contextes `titles, people, socialFeed, homeTitles…`),
    /// et celui-ci. **Deux d'entre eux se recouvrent.** `CardDisplaySetting` et
    /// `DisplayPreference` ont les mêmes noms de champs (`layout`, `size`) et les mêmes
    /// `rawValue`, et `collections` appartient aux trois jeux de contextes : un
    /// `display.<profil>.collections` laissé par un ancien build se **décoderait sans
    /// erreur** dans le type d'aujourd'hui.
    ///
    /// Ici les valeurs seraient par chance équivalentes, mais compter sur cette chance est
    /// précisément la faute : le jour où la charge utile change, la lecture silencieuse
    /// d'un ancien format rendrait un réglage plausible et faux. Le `v1` du préfixe dit
    /// quel vocabulaire la valeur parle, donc aucun recouvrement n'est possible.
    ///
    /// **Rien n'est migré, et c'est délibéré.** L'app n'a jamais été livrée : il n'existe
    /// aucun réglage d'utilisateur à préserver, et écrire une table de correspondance pour
    /// des données qui n'existent pas serait du code « au cas où ». Le défaut du contexte
    /// est la bonne réponse.
    private func key(_ context: DisplayContext) -> String {
        "display.v1.\(profileID?.uuidString ?? "none").\(context.rawValue)"
    }
}
