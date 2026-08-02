import Foundation
import SwiftData

@testable import CineShelfCore

/// Magasin volatil pour les tests, sans miroir CloudKit.
///
/// Le miroir n'est pas testable ici : sous `swift test`, le binaire n'a pas
/// d'identifiant de paquet et CloudKit termine le processus. La conformité du
/// schéma est vérifiée par `CloudKitConformanceTests`, dans la cible
/// `CineShelfTests`.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    try Persistence.makeContainer(cloudKit: false, inMemory: true)
}
