import Foundation
import SwiftData

// MARK: - Indexer ce qu'un import vient d'écrire
//
// **Le trou que ce fichier ferme.** `ImportWriter` n'appelle pas `SpotlightIndexer`, et c'est
// délibéré : l'indexeur est `@MainActor`, l'import tourne sur un acteur. Mais « ne pas
// l'appeler » et « ne pas indexer » sont deux choses différentes, et confondre les deux
// donnerait exactement le défaut que ce dépôt traque : 1 284 titres importés, absents de la
// recherche système, sans que rien ne le signale. L'utilisateur chercherait « Dune » depuis
// l'écran d'accueil et ne trouverait rien, alors que l'app l'affiche.
//
// L'indexation est donc **différée et groupée** : une passe sur le fil principal après le
// commit, sur les identifiants que l'import a rendus. C'est aussi la bonne forme pour 1 284
// items — les repositories indexent à l'unité parce qu'ils écrivent à l'unité.

/// Remet l'index système d'accord avec ce qu'un lot vient d'écrire.
@MainActor
public struct SpotlightBatchIndexer {

    let context: ModelContext
    let indexer: SpotlightIndexer

    public init(
        context: ModelContext,
        indexer: SpotlightIndexer = SpotlightConfiguration.indexer
    ) {
        self.context = context
        self.indexer = indexer
    }

    /// Indexe les titres désignés, par paquets.
    ///
    /// **Les entités sont relues dans *ce* contexte, à partir de leurs identifiants.** Un
    /// `@Model` appartient au contexte qui l'a lu, donc ceux que l'import a créés ne peuvent pas
    /// traverser jusqu'ici — seuls des `UUID` le peuvent. C'est la même contrainte qui fait que
    /// `ImportActor` reçoit un `libraryID` et non une `Library`.
    ///
    /// `sync(_:)` **décide** à partir de l'état courant : un titre importé avec `isPrivate` à
    /// vrai n'entre pas dans l'index, sans que cette fonction ait à le savoir. C'est la garantie
    /// que `SpotlightIndexer` porte, et la raison pour laquelle elle ne prend pas d'ordre
    /// « indexe » ou « retire ».
    ///
    /// - Parameters:
    ///   - titleIDs: les identifiants rendus par `ImportRunResult`.
    ///   - chunkSize: combien d'identifiants par requête. `IN (...)` sur 1 284 valeurs est un
    ///     prédicat que SQLite refuse de préparer au-delà d'un certain nombre de paramètres ;
    ///     découper est la seule façon sûre, et 200 est déjà l'unité de lot de l'import.
    /// - Returns: le nombre de titres réellement retrouvés et synchronisés. Inférieur au nombre
    ///   d'identifiants demandés si l'un a été supprimé entre l'import et l'indexation.
    /// - Throws: l'erreur de lecture du magasin. Un identifiant introuvable n'en est pas une :
    ///   l'entité a pu être supprimée entre l'import et l'indexation, et refuser d'indexer les
    ///   autres pour autant serait disproportionné.
    @discardableResult
    public func indexTitles(ids titleIDs: [UUID], chunkSize: Int = ImportActor.batchSize) throws -> Int {
        var indexed = 0
        for chunk in stride(from: 0, to: titleIDs.count, by: chunkSize) {
            let slice = Set(titleIDs[chunk..<min(chunk + chunkSize, titleIDs.count)])
            guard !slice.isEmpty else { continue }
            let titles = try context.fetch(
                FetchDescriptor<Title>(predicate: TitleQuery.withIDs(slice)))
            for title in titles {
                indexer.sync(title)
                indexed += 1
            }
        }
        return indexed
    }

    /// Indexe ce qu'un import a produit : les titres créés **et** ceux qu'il a complétés.
    ///
    /// Les complétés aussi, et ce n'est pas superflu : un titre dont le résumé vient d'être
    /// rempli doit être retrouvable par ce résumé. `sync(_:)` réécrit l'item entier, donc un
    /// second passage n'est pas un doublon.
    ///
    /// Les entités de référence — personnes, collections — ne sont pas indexées ici : `Person`
    /// et `TitleCollection` le sont par leurs propres repositories, et une personne créée en
    /// passant par un import n'a ni biographie ni média, donc son item serait vide. À rouvrir
    /// si l'import se met un jour à écrire des fiches de personnes.
    @discardableResult
    public func index(_ result: ImportRunResult) throws -> Int {
        try indexTitles(ids: result.createdTitleIDs + result.completedTitleIDs)
    }
}
