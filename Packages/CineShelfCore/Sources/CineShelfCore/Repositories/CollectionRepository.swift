import Foundation
import SwiftData

/// Écritures sur les collections de titres.
@MainActor
public struct CollectionRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(name: String, in library: Library) -> TitleCollection {
        let collection = TitleCollection(name: name)
        collection.library = library
        collection.refreshDerived()
        context.insert(collection)
        ActivityRecorder(context: context).record(.create, collection)
        return collection
    }

    public func update(_ collection: TitleCollection, _ mutate: (TitleCollection) -> Void) {
        mutate(collection)
        collection.refreshDerived()
        ActivityRecorder(context: context).record(.update, collection)
    }

    public func softDelete(_ collection: TitleCollection) {
        collection.deletedAt = .now
        collection.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, collection)
    }

    public func restore(_ collection: TitleCollection) {
        collection.deletedAt = nil
        collection.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, collection)
    }
}
