import Foundation
import SwiftData

/// L'indexation Spotlight : quoi indexer, sous quelle forme, et quand le retirer.
///
/// ## La règle qui commande tout le reste
///
/// **Une entité privée ou à la corbeille n'est jamais dans l'index, et la sortie de
/// l'index doit suivre l'entrée dans ces états.** Ce n'est pas la même exigence que
/// « ne pas indexer le privé » : un titre indexé alors qu'il était public, puis rendu
/// privé, resterait trouvable depuis l'écran d'accueil du système. Personne ne le
/// verrait — l'app le masque correctement partout — et c'est précisément ce qui en
/// fait une fuite. Même chose pour la corbeille : une suppression douce qui laisse
/// l'item en place rend un contenu supprimé encore trouvable.
///
/// D'où la forme de l'API : `sync(_:)` **décide à partir de l'état courant** au lieu
/// de recevoir un ordre « indexe » ou « retire ». Un appelant ne peut donc pas se
/// tromper d'ordre, et n'a pas à savoir ce qui a changé — il lui suffit d'appeler
/// après chaque écriture. Les repositories le font pour lui.
///
/// ## Ce que « privé » veut dire ici, et ce qu'il ne veut pas dire
///
/// `isPrivate` est porté **par l'entité**, pas par le profil. Un `Title` appartient à
/// une `Library`, jamais à un `Profile` ; ce que le profil porte, c'est
/// `hidesPrivateContent`, qui décide de l'**affichage** dans l'app.
///
/// Pour Spotlight, seule la première compte, et la seconde n'aurait aucun sens :
/// l'index du système est **unique pour l'appareil**, il n'a pas de notion de profil
/// actif. Indexer selon `hidesPrivateContent` reviendrait à faire dépendre le contenu
/// d'un index partagé du profil ouvert au moment de l'écriture — donc à fuiter dès
/// qu'un profil permissif touche une entité privée. La règle est donc absolue :
/// `isPrivate` n'entre pas dans l'index, quel que soit le profil.
///
/// ## Ce qui est indexé bien qu'on puisse en douter
///
/// **Les entités archivées le sont.** `isArchived` masque ce qu'on garde ; ce n'est pas
/// un état de confidentialité mais de rangement, et le contrat (`docs/03` §9) ne cite
/// que le privé et la corbeille. C'est une décision, pas un oubli : si elle change, elle
/// change ici, dans `shouldIndex(...)`, et nulle part ailleurs.
@MainActor
public struct SpotlightIndexer {

    /// La vignette d'une entité, si on en a une.
    ///
    /// Une fermeture plutôt qu'une dépendance : le pipeline de vignettes vit dans
    /// `MediaKit`, que `CineShelfCore` ne peut pas importer — la règle de dépendances
    /// de `docs/04` §1 va dans l'autre sens. C'est donc l'appelant qui fournit les
    /// octets. Par défaut il n'y en a pas, et les items sont indexés sans image :
    /// moins joli, jamais faux.
    public typealias ThumbnailProvider = @MainActor (UUID) -> Data?

    let index: any SpotlightIndexing
    let thumbnail: ThumbnailProvider

    public init(
        index: any SpotlightIndexing,
        thumbnail: @escaping ThumbnailProvider = { _ in nil }
    ) {
        self.index = index
        self.thumbnail = thumbnail
    }

    // MARK: La règle

    /// Cette entité a-t-elle sa place dans l'index du système ?
    ///
    /// Le seul endroit du projet qui répond à cette question. Les trois entités
    /// indexables partagent `isPrivate` et `deletedAt` sans partager de protocole
    /// commun — les rassembler sous un protocole juste pour ça ajouterait une
    /// indirection pour deux propriétés.
    public static func shouldIndex(isPrivate: Bool, deletedAt: Date?) -> Bool {
        isPrivate == false && deletedAt == nil
    }

    // MARK: Synchroniser une entité

    /// Met l'index d'accord avec l'état courant du titre.
    public func sync(_ title: Title) {
        guard Self.shouldIndex(isPrivate: title.isPrivate, deletedAt: title.deletedAt) else {
            return remove(.init(kind: .title, entityID: title.id))
        }
        index.index([entry(for: title)])
    }

    /// Met l'index d'accord avec l'état courant de la personne.
    public func sync(_ person: Person) {
        guard Self.shouldIndex(isPrivate: person.isPrivate, deletedAt: person.deletedAt) else {
            return remove(.init(kind: .person, entityID: person.id))
        }
        index.index([entry(for: person)])
    }

    /// Met l'index d'accord avec l'état courant de la collection.
    public func sync(_ collection: TitleCollection) {
        guard
            Self.shouldIndex(isPrivate: collection.isPrivate, deletedAt: collection.deletedAt)
        else {
            return remove(.init(kind: .collection, entityID: collection.id))
        }
        index.index([entry(for: collection)])
    }

    private func remove(_ id: SpotlightItemID) {
        index.remove(identifiers: [id.rawValue])
    }

    // MARK: Décrire une entité

    public func entry(for title: Title) -> SpotlightEntry {
        SpotlightEntry(
            id: .init(kind: .title, entityID: title.id),
            title: title.name,
            subtitle: Self.subtitle(for: title),
            contentDescription: title.summary,
            keywords: Self.keywords(from: title.searchText),
            thumbnailData: thumbnail(title.id)
        )
    }

    public func entry(for person: Person) -> SpotlightEntry {
        SpotlightEntry(
            id: .init(kind: .person, entityID: person.id),
            title: person.displayName,
            subtitle: person.roles.isEmpty ? nil : Self.subtitle(for: person),
            contentDescription: person.bio,
            keywords: Self.keywords(from: person.searchText),
            thumbnailData: thumbnail(person.id)
        )
    }

    public func entry(for collection: TitleCollection) -> SpotlightEntry {
        let count = collection.titles?.count ?? 0
        return SpotlightEntry(
            id: .init(kind: .collection, entityID: collection.id),
            title: collection.name,
            subtitle: count == 0 ? nil : "\(count) titre\(count > 1 ? "s" : "")",
            contentDescription: collection.summary,
            keywords: Self.keywords(from: collection.searchText),
            thumbnailData: thumbnail(collection.id)
        )
    }

    /// Année et durée, ce qui distingue deux titres homonymes dans une liste système.
    private static func subtitle(for title: Title) -> String? {
        var parts: [String] = []
        if let year = title.releaseYear { parts.append(String(year)) }
        if let runtime = title.runtimeMinutes {
            parts.append(runtime >= 60 ? "\(runtime / 60) h \(runtime % 60)" : "\(runtime) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func subtitle(for person: Person) -> String {
        person.roles.map(\.label).sorted().joined(separator: ", ")
    }

    /// Les mots-clés viennent de `searchText`, donc **déjà repliés** — sans accents ni
    /// casse, exactement comme la recherche interne de `L2`. C'est ce que la fiche
    /// entend par « partager la normalisation » : deux repliages différents feraient
    /// que « Âme » se trouve dans l'app et pas dans Spotlight, ou l'inverse.
    private static func keywords(from searchText: String) -> [String] {
        Array(
            Set(
                searchText
                    .split(whereSeparator: { $0.isLetter == false && $0.isNumber == false })
                    .map(String.init)
                    .filter { $0.count > 2 }
            )
        ).sorted()
    }

    // MARK: Réindexation complète

    /// Vide l'index et le reconstruit depuis le magasin.
    ///
    /// Rejouable sans condition : elle commence par tout retirer, donc la lancer deux
    /// fois donne le même résultat qu'une fois. Trois appelants prévus — la fin de la
    /// migration `L13`, un changement de format d'identifiant (voir `SpotlightItemID`),
    /// et la maintenance de `L16` si l'index est soupçonné d'avoir dérivé.
    ///
    /// Les entités privées et celles à la corbeille sont écartées ici comme ailleurs,
    /// par la même fonction : une réindexation qui appliquerait sa propre règle serait
    /// la meilleure façon de réintroduire la fuite qu'on vient de fermer.
    ///
    /// - Parameter context: le magasin à lire.
    /// - Returns: le nombre d'items indexés.
    /// - Throws: ce que remonte `ModelContext.fetch`.
    @discardableResult
    public func reindexEverything(in context: ModelContext) throws -> Int {
        index.removeAll()

        var entries: [SpotlightEntry] = []
        for title in try context.fetch(FetchDescriptor<Title>())
        where Self.shouldIndex(isPrivate: title.isPrivate, deletedAt: title.deletedAt) {
            entries.append(entry(for: title))
        }
        for person in try context.fetch(FetchDescriptor<Person>())
        where Self.shouldIndex(isPrivate: person.isPrivate, deletedAt: person.deletedAt) {
            entries.append(entry(for: person))
        }
        for collection in try context.fetch(FetchDescriptor<TitleCollection>())
        where Self.shouldIndex(isPrivate: collection.isPrivate, deletedAt: collection.deletedAt) {
            entries.append(entry(for: collection))
        }

        index.index(entries)
        return entries.count
    }
}

/// Le moteur d'indexation que les repositories utilisent par défaut.
///
/// **Un point de configuration plutôt qu'un singleton figé.** `docs/04` §3 écrivait
/// `SpotlightIndexer.shared`, ce qui aurait rendu les repositories intestables : une
/// suite de tests aurait écrit dans l'index de la machine. Ici la valeur est
/// remplaçable — l'app pose la vraie au démarrage, et un test qui veut observer
/// l'indexation passe son propre indexeur au repository plutôt que de toucher à
/// celle-ci. Par défaut elle ne fait rien, ce qui est le bon comportement tant que
/// personne n'a branché Spotlight.
@MainActor
public enum SpotlightConfiguration {
    public static var indexer = SpotlightIndexer(index: NullSpotlightIndex())
}
