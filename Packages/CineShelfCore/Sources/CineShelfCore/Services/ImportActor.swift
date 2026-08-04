import Foundation
import SwiftData

/// Écritures lourdes hors du thread principal (`docs/04` §3) : import,
/// migration, régénération de vignettes.
///
/// L'import de lot arrive aux prompts 19 et 20. Ce qui est déjà là est le patron
/// de sauvegarde par lots, sans lequel la mémoire explose et l'interface se fige.
@ModelActor
public actor ImportActor {
    /// Sauvegarde tous les 200 objets.
    public static let batchSize = 200

    /// Rend la main tous les 50 objets.
    ///
    /// Distinct de `batchSize`, et c'est le fond : la **durabilité** a pour unité le lot
    /// sauvegardé, la **réactivité** a la sienne. Les aligner faisait tenir le fil d'exécution
    /// 160 ms d'affilée sur un lot de 200 (mesuré), ce qui se voit à l'écran.
    public static let yieldInterval = 50

    /// Insère chaque élément puis sauvegarde tous `batchSize` éléments.
    ///
    /// - Parameters:
    ///   - items: les éléments à insérer, dans l'ordre.
    ///   - progress: avancement entre 0 et 1, appelé à chaque lot sauvegardé.
    ///   - insert: l'insertion d'un élément dans le contexte de l'acteur.
    /// - Throws: l'erreur de `insert` ou celle de la sauvegarde.
    public func insertInBatches<Element: Sendable>(
        _ items: [Element],
        progress: (@Sendable (Double) -> Void)? = nil,
        insert: @Sendable (Element, ModelContext) throws -> Void
    ) throws {
        guard !items.isEmpty else { return }

        for (offset, item) in items.enumerated() {
            try insert(item, modelContext)
            guard (offset + 1).isMultiple(of: Self.batchSize) else { continue }
            try modelContext.save()
            progress?(Double(offset + 1) / Double(items.count))
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        progress?(1)
    }
}
