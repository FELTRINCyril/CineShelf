import Foundation

/// Les types d'entités indexables dans Spotlight — `docs/03` §9.
///
/// Trois, et pas quatre : les signets n'y sont pas. Un signet est une adresse
/// enregistrée, pas une œuvre du catalogue ; le rendre trouvable depuis l'écran
/// d'accueil du système reviendrait à concurrencer les favoris du navigateur, ce que
/// personne n'a demandé. La recherche interne (`SearchScope`), elle, les couvre.
public enum SpotlightEntityKind: String, CaseIterable, Codable, Sendable {
    case title
    case person
    case collection

    /// La portée de recherche interne correspondante.
    ///
    /// Le lien est explicite plutôt que sous-entendu : `L2` et `L3` doivent parler du
    /// même découpage, sinon un item Spotlight ouvrirait un écran de résultats qui ne
    /// sait pas le montrer.
    public var searchScope: SearchScope {
        switch self {
        case .title: .titles
        case .person: .people
        case .collection: .collections
        }
    }
}

/// L'identifiant d'un item Spotlight, et sa traduction depuis et vers une chaîne.
///
/// **Pourquoi ce type vit dans `CineShelfCore` et non dans une vue.** Spotlight rend
/// une chaîne, et il faut en déduire quoi ouvrir. Cette traduction est une règle du
/// domaine, pas une affaire d'interface : elle doit être testable sans monter d'écran,
/// et elle doit survivre au changement de direction artistique. La vue se contente de
/// convertir un `SpotlightItemID` en route.
///
/// **Le format est un contrat de compatibilité.** Un identifiant indexé aujourd'hui
/// est encore dans l'index du système demain, après une mise à jour de l'app. En
/// changer la forme sans réindexer rendrait tous les anciens items inouvrables — ils
/// resteraient visibles dans Spotlight et ne mèneraient nulle part. Si le format doit
/// changer, `SpotlightIndexer.reindexEverything(in:)` doit tourner dans la foulée.
public struct SpotlightItemID: Equatable, Hashable, Sendable {

    /// Le domaine des items, qui permet de tout retirer d'un coup.
    public static let domain = "fr.feltrin.CineShelf.catalog"

    /// Le type d'activité pour l'ouverture directe depuis un item.
    public static let activityType = "fr.feltrin.CineShelf.open"

    private static let separator = ":"

    public let kind: SpotlightEntityKind
    public let entityID: UUID

    public init(kind: SpotlightEntityKind, entityID: UUID) {
        self.kind = kind
        self.entityID = entityID
    }

    /// La forme stockée dans l'index du système.
    public var rawValue: String {
        "\(kind.rawValue)\(Self.separator)\(entityID.uuidString)"
    }

    /// Relit un identifiant rendu par Spotlight.
    ///
    /// Rend `nil` sur tout ce qui n'est pas exactement au format attendu — type
    /// inconnu, UUID invalide, séparateur manquant. Un identifiant étranger n'est pas
    /// une erreur : l'index du système peut contenir des items d'une version
    /// antérieure, et le bon comportement est de ne rien ouvrir plutôt que de deviner.
    public init?(rawValue: String) {
        let parts = rawValue.split(separator: Self.separator, maxSplits: 1)
        guard parts.count == 2,
            let kind = SpotlightEntityKind(rawValue: String(parts[0])),
            let entityID = UUID(uuidString: String(parts[1]))
        else { return nil }

        self.kind = kind
        self.entityID = entityID
    }
}
