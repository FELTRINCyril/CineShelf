import Foundation

/// Ce qu'on donne à indexer, sous une forme que `CoreSpotlight` ne connaît pas.
///
/// **Pourquoi une valeur intermédiaire plutôt qu'un `CSSearchableItem` directement.**
/// Parce que les décisions — quoi indexer, sous quel titre, avec quels mots-clés, sous
/// quel identifiant — sont du domaine, et doivent être testables sans index système,
/// sans droit d'accès et sans identifiant de paquet. `CoreSpotlightIndex` fait la
/// conversion en une poignée de lignes ; tout ce qui mérite d'être vérifié est ici.
public struct SpotlightEntry: Equatable, Sendable {

    public let id: SpotlightItemID
    /// Le titre affiché dans Spotlight.
    public let title: String
    /// La ligne secondaire : année et durée pour un titre, rôles pour une personne.
    public let subtitle: String?
    /// Le texte long, cherché par Spotlight sans être affiché en entier.
    public let contentDescription: String?
    /// Les mots-clés, déjà repliés — mêmes règles que `searchText`.
    public let keywords: [String]
    /// La vignette, si on en a une.
    public let thumbnailData: Data?

    public init(
        id: SpotlightItemID,
        title: String,
        subtitle: String? = nil,
        contentDescription: String? = nil,
        keywords: [String] = [],
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.contentDescription = contentDescription
        self.keywords = keywords
        self.thumbnailData = thumbnailData
    }
}

/// La frontière avec `CoreSpotlight`.
///
/// Un protocole, et non un appel direct, pour la même raison que partout ailleurs dans
/// ce projet : l'index du système n'est pas disponible sous `swift test` — le binaire
/// n'a pas d'identifiant de paquet — et une suite de tests n'a rien à écrire dans
/// l'index de la machine qui la fait tourner. Le test fournit un double qui enregistre
/// les appels ; la production fournit `CoreSpotlightIndex`.
@MainActor
public protocol SpotlightIndexing: AnyObject {
    func index(_ entries: [SpotlightEntry])
    func remove(identifiers: [String])
    func removeAll()
}

/// L'implémentation par défaut : elle ne fait rien.
///
/// C'est ce qui permet aux repositories de synchroniser l'index sans condition ni
/// `if`, y compris dans les tests et dans tout contexte où Spotlight n'a pas été
/// branché. Le chemin d'indexation est alors exercé à vide, ce qui est exactement ce
/// qu'on veut : une seule forme de code, pas deux.
@MainActor
public final class NullSpotlightIndex: SpotlightIndexing {
    public init() {}
    public func index(_ entries: [SpotlightEntry]) {}
    public func remove(identifiers: [String]) {}
    public func removeAll() {}
}
