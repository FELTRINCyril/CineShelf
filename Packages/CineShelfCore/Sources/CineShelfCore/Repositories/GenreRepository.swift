import Foundation
import SwiftData

/// Écritures sur les genres.
///
/// CloudKit interdit `@Attribute(.unique)` : `findOrCreate(name:target:in:)`
/// cherche sur `nameKey` avant d'insérer. C'est notre remplacement de la
/// contrainte d'unicité, côté application.
@MainActor
public struct GenreRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Le genre existant de même clé, cible et bibliothèque, sinon un genre neuf.
    public func findOrCreate(name: String, target: GenreTarget = .title, in library: Library) throws -> Genre {
        if let existing = try find(key: Genre.key(for: name), target: target, in: library) {
            return existing
        }
        let genre = Genre(name: name, target: target)
        genre.library = library
        context.insert(genre)
        ActivityRecorder(context: context).record(.create, genre)
        return genre
    }

    public func rename(_ genre: Genre, to name: String) {
        genre.name = name
        genre.refreshDerived()
        ActivityRecorder(context: context).record(.update, genre)
    }

    private func find(key: String, target: GenreTarget, in library: Library) throws -> Genre? {
        let targetRaw = target.rawValue
        let libraryID = library.id
        var descriptor = FetchDescriptor<Genre>(
            predicate: #Predicate {
                $0.nameKey == key && $0.targetRaw == targetRaw && $0.library?.id == libraryID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
