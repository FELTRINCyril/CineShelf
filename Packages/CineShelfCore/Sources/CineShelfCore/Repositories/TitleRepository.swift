import Foundation
import SwiftData

/// Écritures sur les titres (`docs/04` §3).
///
/// Invariant central : aucune écriture ne contourne `refreshDerived()`. C'est ce
/// qui garantit que `sortName` et `searchText` restent cohérents — ils
/// remplacent les colonnes générées et l'index FTS que CloudKit ne permet pas.
@MainActor
public struct TitleRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(name: String, kind: TitleKind = .movie, in library: Library) -> Title {
        let title = Title(name: name, kind: kind)
        title.library = library
        title.refreshDerived()
        context.insert(title)
        ActivityRecorder(context: context).record(.create, title)
        return title
    }

    public func update(_ title: Title, _ mutate: (Title) -> Void) {
        mutate(title)
        title.refreshDerived()
        ActivityRecorder(context: context).record(.update, title)
    }

    /// Corbeille plutôt que suppression : une suppression synchronisée est
    /// irréversible. La purge à 30 jours est une tâche de maintenance.
    public func softDelete(_ title: Title) {
        title.deletedAt = .now
        title.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, title)
    }

    public func restore(_ title: Title) {
        title.deletedAt = nil
        title.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, title)
    }
}
