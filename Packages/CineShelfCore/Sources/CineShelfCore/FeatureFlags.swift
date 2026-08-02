import Foundation

/// Bascules d'activation des fonctionnalités qui dépendent d'une configuration externe.
public enum FeatureFlags {
    /// Passe à `true` le jour où le conteneur CloudKit et les entitlements sont en place.
    ///
    /// Voir le README, section « Activer CloudKit ».
    public static let cloudKitEnabled = false
}
