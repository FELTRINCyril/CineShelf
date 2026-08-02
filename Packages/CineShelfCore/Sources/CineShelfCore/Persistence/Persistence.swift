import Foundation
import SwiftData

/// Ouverture du magasin SwiftData (`docs/02` §4).
///
/// Tant que l'abonnement Apple Developer n'est pas souscrit, l'app démarre avec
/// `cloudKit: false`. Le modèle est déjà écrit sous les contraintes du miroir :
/// l'activation se fera en changeant ce booléen et en ajoutant l'entitlement.
public enum Persistence {
    public static let cloudKitContainerIdentifier = "iCloud.fr.feltrin.CineShelf"

    public static var schema: Schema { Schema(versionedSchema: CineShelfSchemaV1.self) }

    /// - Parameters:
    ///   - cloudKit: branche le miroir sur la base privée de l'utilisateur.
    ///   - inMemory: magasin volatil, pour les tests.
    /// - Returns: le conteneur ouvert sur le schéma courant.
    /// - Throws: l'erreur de SwiftData si le magasin ne peut pas être ouvert —
    ///   notamment si le schéma viole une contrainte du miroir CloudKit.
    @MainActor
    public static func makeContainer(cloudKit: Bool, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Self.schema
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .private(cloudKitContainerIdentifier) : .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: [config]
        )
    }
}
