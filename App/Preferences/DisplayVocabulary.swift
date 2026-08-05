import CineShelfCore
import DesignSystem
import Foundation

// MARK: - L1 bis · Le pont entre le vocabulaire persisté et le vocabulaire visuel
//
// **Le store lui-même a déménagé dans `CineShelfCore`** (`DisplayPreferenceStore`) : les
// prompts 14 à 17 le réutiliseront, et il ne pouvait pas rester dans la fonctionnalité
// « Titres » — un store rangé là aurait été recopié au premier écran suivant.
//
// Ce qui reste ici est la seule chose qui appartienne à l'app : la correspondance entre les
// deux vocabulaires, que ni l'un ni l'autre des deux paquets ne peut écrire, puisque la
// règle de dépendances de `docs/04` §1 leur interdit de se connaître.
//
// **C'est le seul endroit du dépôt où les deux jeux se rencontrent**, et c'est ce qui rend
// `DisplayVocabularyTests` possible : la cible de test de l'app importe les deux paquets.

extension DisplayContext {

    /// Le contexte visuel correspondant.
    ///
    /// `switch` exhaustif sans `default`, et c'est le filet : ajouter un cas à
    /// `DisplayContext` fait **cesser la compilation** ici, au lieu de perdre silencieusement
    /// une préférence au runtime. Le test de vocabulaire couvre l'autre sens et les
    /// `rawValue`, que le compilateur ne peut pas voir.
    var posterContext: PosterContext {
        switch self {
        case .movies: .titles
        case .actors: .people
        case .collections: .collections
        case .social: .socialFeed
        case .homeMovies: .homeTitles
        case .homeActors: .homePeople
        case .homeCollections: .homeCollections
        case .homeSocial: .homeSocial
        }
    }
}

extension PosterContext {

    /// Le contexte persisté correspondant. L'inverse exact de `posterContext`.
    var displayContext: DisplayContext {
        switch self {
        case .titles: .movies
        case .people: .actors
        case .collections: .collections
        case .socialFeed: .social
        case .homeTitles: .homeMovies
        case .homePeople: .homeActors
        case .homeCollections: .homeCollections
        case .homeSocial: .homeSocial
        }
    }
}

extension DisplayPreference {

    /// Le réglage visuel correspondant.
    var posterSetting: PosterSetting {
        PosterSetting(layout: CardLayout(layout), size: CardSize(size))
    }

    init(_ setting: PosterSetting) {
        self.init(layout: DisplayLayout(setting.layout), size: DisplaySize(setting.size))
    }
}

// Les quatre conversions d'énumération passent par `rawValue`, avec un repli explicite.
//
// **Le repli n'est pas de la prudence décorative** : `init?(rawValue:)` est faillible, et un
// `!` serait un force unwrap, que le projet interdit hors des tests. Il est **inatteignable
// tant que `DisplayVocabularyTests` passe**, et c'est exactement pourquoi ce test existe :
// sans lui, le repli deviendrait un défaut muet — une carte en portrait là où l'utilisateur
// avait choisi le paysage, sans rien dans les logs.

extension CardLayout {
    fileprivate init(_ layout: DisplayLayout) {
        self = CardLayout(rawValue: layout.rawValue) ?? .portrait
    }
}

extension CardSize {
    fileprivate init(_ size: DisplaySize) {
        self = CardSize(rawValue: size.rawValue) ?? .medium
    }
}

extension DisplayLayout {
    fileprivate init(_ layout: CardLayout) {
        self = DisplayLayout(rawValue: layout.rawValue) ?? .portrait
    }
}

extension DisplaySize {
    fileprivate init(_ size: CardSize) {
        self = DisplaySize(rawValue: size.rawValue) ?? .medium
    }
}

// MARK: - La façade que les vues appellent

/// Lit et écrit un `PosterSetting` pour un contexte **visuel**.
///
/// Les vues parlent le vocabulaire visuel — c'est le leur — et ne voient jamais les noms de
/// la v1. La traduction se fait ici, en un seul endroit.
enum PosterSettingStore {

    static func setting(profileID: UUID?, context: PosterContext) -> PosterSetting {
        DisplayPreferenceStore(profileID: profileID)
            .preference(for: context.displayContext)
            .posterSetting
    }

    static func save(_ setting: PosterSetting, profileID: UUID?, context: PosterContext) {
        DisplayPreferenceStore(profileID: profileID)
            .save(DisplayPreference(setting), for: context.displayContext)
    }
}
