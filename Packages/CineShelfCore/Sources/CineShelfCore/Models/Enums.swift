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

extension PersonRole {
    /// Le libellé français d'un rôle.
    ///
    /// Dans le modèle et non dans une vue : `SpotlightIndexer` en a besoin pour la
    /// ligne secondaire d'un item, et `CineShelfCore` n'importe pas SwiftUI. Même
    /// motif que `AgeBand.label` et les messages de `ActivityDescribing`.
    public var label: String {
        switch self {
        case .actor: "Acteur"
        case .social: "Compte social"
        case .director: "Réalisateur"
        case .writer: "Scénariste"
        case .crew: "Équipe"
        }
    }
}

public enum CreditRole: String, Codable, CaseIterable, Sendable {
    case cast, director, writer, producer, composer, crew
}

/// La teinte d'un profil, par jeton sémantique du design system.
///
/// Typée plutôt que laissée en `String` libre : `accentToken` était une chaîne
/// que rien ne validait, et la vue qui la résolvait retombait silencieusement
/// sur l'accent par défaut dès que le jeton n'existait pas. Un jeton invalide
/// doit être impossible à écrire, pas avalé à la lecture.
///
/// Le `rawValue` **est** le nom du jeu de couleurs : c'est ce qui permet à
/// `CineShelfCore` de rester ignorant du design system (il n'importe ni SwiftUI
/// ni `DesignSystem`) tout en désignant une couleur réelle.
///
/// Deux cas seulement, et `accent/soft` n'en fait volontairement pas partie :
/// c'est un lavis de fond, à alpha 0,10 en clair et jusqu'à 0,22 en contraste
/// élevé. Employé en teinte d'app, il rendrait l'accent quasi invisible. Comme
/// l'énumération est `CaseIterable` et qu'un `Picker` sur `allCases` est
/// exactement ce que le prompt 18 va construire, l'y laisser aurait livré un
/// réglage qui casse l'interface.
public enum ProfileAccent: String, Codable, CaseIterable, Sendable {
    case solid = "accent/solid"
    case text = "accent/text"
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

/// Le type d'entité visé par une entrée du fil d'activité.
///
/// **Pourquoi cette énumération existe, alors que le champ était déjà rempli.**
/// `entityTypeRaw` recevait `String(describing: Self.self)`, c'est-à-dire le nom Swift
/// du type, sous un commentaire qui prétendait que ça « suit les renommages sans table
/// à part ». C'était l'inverse : renommer un `@Model` change la chaîne, les anciennes
/// entrées gardent l'ancienne et le fil se scinde silencieusement en deux seaux.
/// Personne ne l'aurait vu avant que `L18` filtre par entité, ou que `L20` route une
/// annulation selon le type.
///
/// Les `rawValue` sont donc choisis **stables et lisibles**, sans chercher à coller aux
/// noms Swift d'aujourd'hui : ce sont eux qui vivent dans le magasin, et ils doivent
/// survivre à n'importe quel renommage de classe.
public enum ActivityEntityType: String, Codable, CaseIterable, Sendable {
    case library
    case profile
    case title
    case person
    case collection
    case genre
    case credit
    case media
    case link
    case savedLink = "saved_link"
    /// Un lot : édition en masse, import, fusion. L'entrée ne vise pas une entité
    /// unique, et son `entityID` désigne le lot lui-même.
    case batch
}

/// Les actions du fil d'activité. Absente de §3.1, qui décrit `actionRaw` en
/// texte libre : `ActivityRecorder` a besoin d'un vocabulaire fermé.
public enum ActivityAction: String, Codable, CaseIterable, Sendable {
    case create, update, delete, restore, merge
    case `import`
    /// Une edition en masse : une seule entree pour tout un lot.
    ///
    /// Distinct d'`update` parce que le fil doit pouvoir la presenter autrement — « 47
    /// titres modifies » et non quarante-sept lignes — et parce que `L20` retrouve les
    /// lots annulables par cette action. Ajouter un cas ne touche pas au schema :
    /// `ActivityEntry.actionRaw` est une `String`, et `action` rend `nil` sur un
    /// `rawValue` inconnu.
    case bulkEdit
    /// L'annulation d'un lot — `L20`.
    ///
    /// Distincte d'`update` et de `restore` : `restore` sort une entite de la corbeille, et
    /// « Modifie » ne dirait pas que l'operation en defait une autre. Meme raisonnement que
    /// `bulkEdit` ci-dessus, et meme innocuite vis-a-vis du schema : `actionRaw` est une
    /// `String`, et une version anterieure lira `nil` — donc « Operation », ce qu'une piste
    /// d'audit a le droit de dire.
    case undo
}
