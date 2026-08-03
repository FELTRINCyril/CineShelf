import CineShelfCore
import Foundation
import SwiftData

/// La base commune des trois suites qui couvrent le filtre des titres :
/// `TitleFilterTests` (les critères), `TitlePredicateTests` (la forme du
/// prédicat) et `FilterKeyTests` (le maintien des clés dérivées).
///
/// Ces aides sont partagées et non recopiées parce que `save()` avant `fetch`
/// n'est pas un détail de confort : c'est ce qui rend les tests valables. Sur des
/// objets encore en attente, SwiftData évalue le prédicat en Swift et sa
/// traduction SQL n'est jamais exercée — un `contains("")`, vrai en Swift et sans
/// correspondance en SQL, a ainsi vidé la grille derrière 42 tests verts. Une
/// copie de cette aide qui oublierait le `save()` réintroduirait le trou.
@MainActor
enum TitleFilterFixture {

    /// Magasin en mémoire : aucune trace sur disque, aucun CloudKit.
    static func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    static func makeContext() throws -> ModelContext {
        try makeStore().context
    }

    /// Un titre inséré, dérivés à jour.
    ///
    /// Les relations, elles, sont posées par l'appelant — qui doit rappeler
    /// `refreshDerived()` ensuite, exactement comme la production. Les poser ici
    /// et rafraîchir automatiquement masquerait le seul bug que
    /// `FilterKeyTests` cherche à voir.
    @discardableResult
    static func makeTitle(
        in context: ModelContext,
        name: String = "Un titre",
        runtime: Int? = 100,
        rating: Double? = 7,
        isArchived: Bool = false,
        isPrivate: Bool = false
    ) -> Title {
        let title = Title(name: name)
        title.runtimeMinutes = runtime
        title.rating = rating
        title.isArchived = isArchived
        title.isPrivate = isPrivate
        title.refreshDerived()
        context.insert(title)
        return title
    }

    /// Applique le filtre comme le fait `TitlesGrid` : un seul prédicat, aucune
    /// passe en mémoire.
    ///
    /// - Returns: les titres retenus, triés selon le filtre.
    static func results(
        _ filter: TitleFilter,
        in context: ModelContext,
        hidingPrivate: Bool = false,
        libraryID: UUID? = nil
    ) throws -> [Title] {
        try context.save()

        let descriptor = FetchDescriptor<Title>(
            predicate: filter.predicate(hidingPrivate: hidingPrivate, libraryID: libraryID),
            sortBy: filter.descriptors
        )
        return try context.fetch(descriptor)
    }
}
