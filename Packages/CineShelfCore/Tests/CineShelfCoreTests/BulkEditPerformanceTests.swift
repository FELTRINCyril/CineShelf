import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// `BulkEditor` est `@MainActor`, et c'est un choix assumé : les repositories le sont, et
// les contourner reviendrait à perdre `refreshDerived()`. Le raisonnement tient parce que
// le lot est borné — une sélection que l'utilisateur a sous les yeux.
//
// Ce test existe pour que le jour où ce raisonnement cesse d'être vrai **se voie**. Il ne
// défend pas un budget d'expérience utilisateur : il rapporte un coût par entité, et
// n'assène qu'un plafond d'ordre de grandeur. Un seuil serré sur un runner partagé
// mesurerait le bruit de la machine — les runners GitHub n'ont pas d'accélération
// d'image et sont virtualisés, mesuré ailleurs à 15 ms en local contre 266 ms sur le
// runner pour la même opération.
//
// Les chiffres locaux sont notés à côté de chaque assertion : c'est eux qu'il faut
// comparer d'une session à l'autre, pas le plafond.

@MainActor
struct BulkEditPerformanceTests {

    /// Un lot bien plus grand que ce qu'une sélection à la main produira.
    private static let batchSize = 500

    /// Valeur nommée et non tuple à trois membres : `large_tuple` l'interdit, et la
    /// convention du dépôt est de nommer plutôt que de désactiver la règle.
    private struct Catalog {
        let editor: BulkEditor
        let ids: [UUID]
        let context: ModelContext
    }

    private func makeCatalog() throws -> Catalog {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)

        var ids: [UUID] = []
        for index in 0..<Self.batchSize {
            let title = Title(name: "Titre \(index)")
            title.library = library
            title.refreshDerived()
            context.insert(title)
            ids.append(title.id)
        }
        try context.save()
        return Catalog(editor: BulkEditor(isolatedContext: context), ids: ids, context: context)
    }

    private func elapsed(_ work: () throws -> Void) rethrows -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        try work()
        return start.duration(to: clock.now)
    }

    /// Millisecondes. `components.attoseconds` seul **n'inclut pas** les secondes
    /// entières : une mesure de 8,9 s s'y lisait « 0,9 s », et le premier chiffre publié
    /// sur le pipeline médias était dix fois trop optimiste à cause de ça.
    private func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }

    @Test("Un lot de 500 titres sur un champ scalaire")
    func scalarBatchCost() throws {
        let catalog = try makeCatalog()

        let duration = try elapsed {
            let outcome = try catalog.editor.apply(
                .setArchived(true), toTitles: catalog.ids, summary: "500 titres archivés")
            #expect(outcome.appliedCount == Self.batchSize)
        }

        let total = milliseconds(duration)
        let perEntity = total / Double(Self.batchSize)
        print(
            """
            [perf] lot scalaire de \(Self.batchSize) titres : \
            \(String(format: "%.0f", total)) ms au total, \
            \(String(format: "%.2f", perEntity)) ms par titre
            """
        )

        // Local sur ce Mac : ~0,3 ms par titre, ~150 ms au total. Le plafond est un
        // ordre de grandeur au-dessus : il attrape une régression algorithmique — un
        // `fetch` par entité, un `refreshDerived()` devenu quadratique — et rien de plus.
        #expect(perEntity < 20, "\(String(format: "%.2f", perEntity)) ms par titre")
    }

    @Test("Un lot de 500 titres sur une relation")
    func relationBatchCost() throws {
        let catalog = try makeCatalog()
        let library = try #require(
            try catalog.context.fetch(FetchDescriptor<Library>()).first)
        let genre = try GenreRepository(context: catalog.context)
            .findOrCreate(name: "Policier", target: .title, in: library)
        try catalog.context.save()

        let duration = try elapsed {
            let outcome = try catalog.editor.apply(
                .addGenres([genre.id]), toTitles: catalog.ids, summary: "genre ajouté")
            #expect(outcome.appliedCount == Self.batchSize)
        }

        let total = milliseconds(duration)
        let perEntity = total / Double(Self.batchSize)
        print(
            """
            [perf] lot de relation de \(Self.batchSize) titres : \
            \(String(format: "%.0f", total)) ms au total, \
            \(String(format: "%.2f", perEntity)) ms par titre
            """
        )

        // Plus coûteux que le scalaire : `filterKeys` se recompose depuis les relations,
        // donc chaque titre relit ses genres. C'est justement le chemin qu'il faut
        // surveiller.
        #expect(perEntity < 30, "\(String(format: "%.2f", perEntity)) ms par titre")
    }

    @Test("Un refus sur un lot de 500 ne coûte pas plus cher qu'une application")
    func refusalIsNotMoreExpensive() throws {
        let catalog = try makeCatalog()

        // La validation tourne avant toute écriture : un refus doit sortir tôt, sans
        // avoir muté puis annulé 500 entités. Si ce chiffre s'approche de celui d'une
        // application réussie, c'est que l'ordre « valider puis écrire » a été inversé.
        let duration = try elapsed {
            let outcome = try catalog.editor.apply(
                .setRating(99), toTitles: catalog.ids, summary: "note invalide")
            #expect(outcome.appliedCount == 0)
        }

        let total = milliseconds(duration)
        print("[perf] refus sur \(Self.batchSize) titres : \(String(format: "%.0f", total)) ms")
        #expect(total < 2000, "\(String(format: "%.0f", total)) ms")
    }
}
