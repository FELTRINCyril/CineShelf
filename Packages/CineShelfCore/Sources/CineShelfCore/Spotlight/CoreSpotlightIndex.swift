import CoreSpotlight
import Foundation

/// L'adaptateur vers `CoreSpotlight`. Tout ce qui mérite d'être vérifié est ailleurs.
///
/// Ce fichier ne prend **aucune décision** : il convertit des `SpotlightEntry` en
/// `CSSearchableItem` et passe les appels. Les règles — quoi indexer, sous quel
/// identifiant, avec quels mots-clés — sont dans `SpotlightIndexer`, où elles sont
/// testables sans index système. C'est ce partage qui rend `L3` couvrable : sous
/// `swift test`, le binaire n'a pas d'identifiant de paquet et `CSSearchableIndex`
/// n'écrit nulle part.
///
/// Les erreurs remontées par l'index sont **avalées volontairement**. Une indexation
/// est un service rendu, pas une écriture du catalogue : si Spotlight refuse un item —
/// index en reconstruction, appareil à court d'espace, protection des données activée
/// avant premier déverrouillage — l'utilisateur ne doit pas voir d'erreur, et surtout
/// l'écriture qui a déclenché l'indexation ne doit pas échouer pour autant. La
/// réindexation complète de `SpotlightIndexer.reindexEverything(in:)` est le filet.
@MainActor
public final class CoreSpotlightIndex: SpotlightIndexing {

    private let index: CSSearchableIndex

    public init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    public func index(_ entries: [SpotlightEntry]) {
        guard entries.isEmpty == false else { return }
        index.indexSearchableItems(entries.map(Self.item(from:))) { _ in }
    }

    public func remove(identifiers: [String]) {
        guard identifiers.isEmpty == false else { return }
        index.deleteSearchableItems(withIdentifiers: identifiers) { _ in }
    }

    public func removeAll() {
        index.deleteSearchableItems(withDomainIdentifiers: [SpotlightItemID.domain]) { _ in }
    }

    private static func item(from entry: SpotlightEntry) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = entry.title
        attributes.contentDescription = entry.contentDescription ?? entry.subtitle
        attributes.keywords = entry.keywords
        attributes.thumbnailData = entry.thumbnailData

        // `relatedUniqueIdentifier` porte le même identifiant que l'item : c'est ce
        // qui permet à `NSUserActivity` de désigner l'entité à ouvrir sans réencoder
        // la route. Le décodage se fait par `SpotlightItemID(rawValue:)`.
        attributes.relatedUniqueIdentifier = entry.id.rawValue

        return CSSearchableItem(
            uniqueIdentifier: entry.id.rawValue,
            domainIdentifier: SpotlightItemID.domain,
            attributeSet: attributes
        )
    }
}
