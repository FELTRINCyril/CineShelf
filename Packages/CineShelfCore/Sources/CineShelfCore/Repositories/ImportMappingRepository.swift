import Foundation
import SwiftData

/// Écritures et lectures des correspondances de colonnes mémorisées.
///
/// **L'entité existait sans personne pour la lire.** `ImportMapping` a été ajoutée par la
/// passe de fermeture du schéma, qui l'avait relevée comme le plus gros manque de
/// l'inventaire — et sa docstring disait « Aucune logique ne le consomme encore : `L11`
/// l'écrira. » C'est ce fichier.
///
/// `@MainActor` comme tous les repositories : ils touchent des `@Model`, qui appartiennent au
/// contexte qui les a lus. L'analyse d'un fichier, elle, n'est pas isolée du tout — c'est la
/// frontière que `L11a` a tenue, et la raison pour laquelle tout ce qui précède est testable
/// sans magasin.
@MainActor
public struct ImportMappingRepository {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// La correspondance mémorisée pour un en-tête, s'il en existe une.
    ///
    /// C'est le seul point d'entrée de la reconnaissance automatique : « Réutiliser cette
    /// correspondance pour les prochains fichiers de même en-tête ». La signature est
    /// calculée sous locale invariante — voir `ColumnMapping.headerSignature`, et
    /// `TextFolding` pour ce qui arriverait sinon entre deux appareils.
    public func mapping(forHeader header: [String], in library: Library) throws -> ImportMapping? {
        try mapping(signature: ColumnMapping.headerSignature(for: header), in: library)
    }

    /// La correspondance à appliquer pour cette signature.
    ///
    /// **Le personnel passe devant l'intégré par règle, et non par chance.** La première
    /// version triait sur `updatedAt` seul, en affirmant qu'une correspondance personnelle
    /// « masque l'intégrée à la lecture ». Elle ne la masquait que si elle était plus
    /// récente — or un `isBuiltIn` arrive par une mise à jour de l'app ou par une fusion
    /// CloudKit, donc **plus tard**. Mesuré : l'utilisateur mémorisait « Le mien », un
    /// intégré de même signature arrivait, et la lecture rendait l'intégré. Le tri porte
    /// donc d'abord sur `isBuiltIn`.
    /// Le tri final se fait **en Swift et non en SQL** : `SortDescriptor` exige un `Bool`
    /// comparable, ce qu'il n'est pas. Sans coût réel — le prédicat rend une signature dans
    /// une bibliothèque, donc au plus une correspondance personnelle et une intégrée.
    public func mapping(signature: String, in library: Library) throws -> ImportMapping? {
        let candidates = try context.fetch(
            FetchDescriptor<ImportMapping>(
                predicate: ImportMappingQuery.matching(signature: signature, inLibrary: library.id),
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            ))
        return candidates.first { !$0.isBuiltIn } ?? candidates.first
    }

    /// La correspondance personnelle de cette signature, s'il en existe une.
    private func personalMapping(signature: String, in library: Library) throws -> ImportMapping? {
        var descriptor = FetchDescriptor<ImportMapping>(
            predicate: ImportMappingQuery.personal(signature: signature, inLibrary: library.id),
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Toutes les correspondances d'une bibliothèque, la plus récemment modifiée d'abord.
    public func all(in library: Library) throws -> [ImportMapping] {
        try context.fetch(
            FetchDescriptor<ImportMapping>(
                predicate: ImportMappingQuery.inLibrary(library.id),
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            ))
    }

    /// Mémorise une correspondance pour un en-tête donné.
    ///
    /// **Écrase la correspondance de même signature au lieu d'en ajouter une seconde.** Deux
    /// correspondances pour le même en-tête seraient un choix impossible à présenter — et
    /// comme la lecture prend la plus récente, la seconde rendrait la première invisible sans
    /// la supprimer. `ImportMapping` n'a pas d'`@Attribute(.unique)`, CloudKit l'interdit :
    /// c'est ici que l'unicité se tient, comme pour `Genre.nameKey`.
    ///
    /// Une correspondance intégrée n'est jamais écrasée : elle est livrée avec l'app, donc
    /// une correspondance personnelle de même en-tête est un enregistrement distinct, que la
    /// lecture fait passer devant (voir `mapping(signature:in:)`).
    ///
    /// - Throws: `ColumnMappingError.duplicateColumnNames` si l'en-tête porte deux colonnes
    ///   de même nom. La correspondance est mémorisée **par nom** — c'est ce qui la rend
    ///   indépendante de l'ordre des colonnes — donc deux homonymes en perdraient une, et
    ///   c'était le champ requis qui disparaissait dans le cas mesuré. Un refus nommé plutôt
    ///   qu'un arbitrage muet.
    @discardableResult
    public func save(
        _ mapping: ColumnMapping,
        named name: String,
        forHeader header: [String],
        in library: Library
    ) throws -> ImportMapping {
        let duplicates = ColumnMapping.duplicateColumnNames(in: header)
        guard duplicates.isEmpty else {
            throw ColumnMappingError.duplicateColumnNames(duplicates)
        }

        let signature = ColumnMapping.headerSignature(for: header)
        // La correspondance **personnelle**, et non « la plus récente » : sinon un intégré
        // plus récent faisait insérer un second enregistrement personnel à chaque appel.
        if let existing = try personalMapping(signature: signature, in: library) {
            existing.name = name
            existing.columnMapData = try mapping.encoded()
            existing.updatedAt = .now
            return existing
        }

        let record = ImportMapping(name: name, headerSignature: signature)
        record.columnMapData = try mapping.encoded()
        record.library = library
        context.insert(record)
        return record
    }

    /// La correspondance portée par un enregistrement.
    ///
    /// - Throws: `ColumnMappingError.unsupportedVersion` si elle vient d'une version
    ///   postérieure de l'app, ce qui arrive en synchronisation. Refuser plutôt que deviner :
    ///   un mappage mal relu écrit les bonnes valeurs dans les mauvais champs.
    public func columnMapping(of record: ImportMapping) throws -> ColumnMapping? {
        guard let data = record.columnMapData else { return nil }
        return try ColumnMapping.decoded(from: data)
    }

    /// Renomme une correspondance personnelle.
    ///
    /// **Refuse une intégrée, comme `delete`.** Le nom d'une correspondance livrée revient à
    /// la prochaine mise à jour, donc le renommage ne tient pas ; et il bougeait `updatedAt`,
    /// ce qui la faisait passer devant une correspondance personnelle avant que la lecture ne
    /// trie sur `isBuiltIn`.
    public func rename(_ record: ImportMapping, to name: String) throws {
        guard !record.isBuiltIn else { throw ImportMappingError.builtInCannotBeRenamed }
        record.name = name
        record.updatedAt = .now
    }

    /// Supprime une correspondance personnelle.
    ///
    /// **Refuse une correspondance intégrée.** `ImportMapping.isBuiltIn` dit « ne se supprime
    /// pas et se retrouve après une réinstallation » : la supprimer localement la ferait
    /// revenir au prochain lancement, ce qui se lit comme un bug. Un refus explicite plutôt
    /// qu'une suppression qui ne tient pas.
    ///
    /// Suppression franche et non corbeille, contrairement à `Genre` : une correspondance ne
    /// porte aucune association, la reperdre ne coûte que de refaire un écran.
    public func delete(_ record: ImportMapping) throws {
        guard !record.isBuiltIn else { throw ImportMappingError.builtInCannotBeDeleted }
        context.delete(record)
    }
}

public enum ImportMappingError: Error, Sendable, Hashable {
    /// Une correspondance livrée avec l'app ne se supprime pas.
    case builtInCannotBeDeleted
    /// Ni ne se renomme : le nom reviendrait à la prochaine mise à jour.
    case builtInCannotBeRenamed
}
