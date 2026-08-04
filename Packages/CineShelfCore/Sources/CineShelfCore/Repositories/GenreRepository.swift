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
    ///
    /// **La règle vit dans `EntityResolver` depuis `L11b`, et ce fichier la lui délègue.**
    /// L'import ne peut pas passer ici — ce type est `@MainActor` — donc il aurait fallu
    /// recopier la recherche dans l'acteur. Deux copies d'une règle de dédoublonnage finissent
    /// par diverger, et une divergence ici crée des doublons **en silence** : c'est
    /// exactement ce que `nameKey` existe pour empêcher.
    ///
    /// Ce qui reste ici est ce que le résolveur ne fait pas, faute de savoir dans quel
    /// contexte il est appelé : l'entrée de journal.
    public func findOrCreate(name: String, target: GenreTarget = .title, in library: Library) throws -> Genre {
        var resolver = EntityResolver(context: context, library: library)
        guard let genre = resolver.genre(named: name, target: target) else {
            throw GenreError.emptyName
        }
        // Journaliser **seulement** une vraie création : `createdIDs` le dit, et retrouver un
        // genre existant n'est pas un événement du catalogue.
        if resolver.createdIDs.contains(genre.id) {
            ActivityRecorder(context: context).record(.create, genre)
        }
        return genre
    }

    public func rename(_ genre: Genre, to name: String) {
        genre.name = name
        genre.refreshDerived()
        ActivityRecorder(context: context).record(.update, genre)
    }

    /// Corbeille plutôt que suppression : un genre supprimé en dur emporte
    /// toutes ses associations avec les titres et les personnes, et les
    /// recréer ne les ramène pas. Voir `docs/02` §3.5.
    public func softDelete(_ genre: Genre) {
        genre.deletedAt = .now
        genre.updatedAt = .now
        ActivityRecorder(context: context).record(.delete, genre)
    }

    public func restore(_ genre: Genre) {
        genre.deletedAt = nil
        genre.updatedAt = .now
        ActivityRecorder(context: context).record(.restore, genre)
    }

    /// Le nom d'un genre ne peut pas être vide.
    ///
    /// Un genre sans nom aurait une `nameKey` vide, donc il ferait doublon avec tous les
    /// autres genres sans nom, et le dédoublonnage les fusionnerait silencieusement.
    public enum GenreError: Error, Sendable, Hashable {
        case emptyName
    }

    private func find(key: String, target: GenreTarget, in library: Library) throws -> Genre? {
        // Le filtre `deletedAt == nil` est porté par `GenreQuery` : sans lui,
        // `findOrCreate` ressusciterait silencieusement un genre mis à la corbeille,
        // et l'utilisateur retrouverait ses anciennes associations sans les avoir
        // demandées.
        var descriptor = FetchDescriptor<Genre>(
            predicate: GenreQuery.living(key: key, target: target, inLibrary: library.id)
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
