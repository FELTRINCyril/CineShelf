import Foundation
import SwiftData

/// Écritures sur les collections de titres.
@MainActor
public struct CollectionRepository {
    let context: ModelContext
    /// Synchronisée après chaque écriture — voir `TitleRepository.spotlight`.
    let spotlight: SpotlightIndexer

    public init(
        context: ModelContext,
        spotlight: SpotlightIndexer = SpotlightConfiguration.indexer
    ) {
        self.context = context
        self.spotlight = spotlight
    }

    @discardableResult
    public func create(name: String, in library: Library) -> TitleCollection {
        let collection = TitleCollection(name: name)
        collection.library = library
        collection.refreshDerived()
        context.insert(collection)
        ActivityRecorder(context: context).record(.create, collection)
        spotlight.sync(collection)
        return collection
    }

    public func update(_ collection: TitleCollection, _ mutate: (TitleCollection) -> Void) {
        mutate(collection)
        collection.refreshDerived()
        ActivityRecorder(context: context).record(.update, collection)
        spotlight.sync(collection)
    }

    public func softDelete(_ collection: TitleCollection) {
        collection.deletedAt = .now
        collection.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, collection)
        spotlight.sync(collection)
    }

    public func restore(_ collection: TitleCollection) {
        collection.deletedAt = nil
        collection.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, collection)
        spotlight.sync(collection)
    }
}
