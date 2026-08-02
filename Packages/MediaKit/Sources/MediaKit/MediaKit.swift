import CineShelfCore
import Foundation

/// Pipeline médias : import, dérivés, cache disque, export.
///
/// S'appuie sur `CineShelfCore` pour les modèles et n'expose aucune vue.
public enum MediaKit {
    /// Version du format de cache sur disque, incrémentée quand les dérivés changent.
    public static let cacheFormatVersion = 1

    /// Version du schéma de données que ce pipeline sait traiter.
    public static var supportedSchemaVersion: Int { CineShelfCore.schemaVersion }
}
