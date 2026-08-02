import Foundation

/// Point d'entrée du domaine métier.
///
/// Ce package ne dépend de rien et **n'importe jamais SwiftUI** : il accueillera
/// les `@Model` SwiftData, les repositories et les services.
public enum CineShelfCore {
    /// Version du schéma de données, incrémentée à chaque migration.
    public static let schemaVersion = 1
}
