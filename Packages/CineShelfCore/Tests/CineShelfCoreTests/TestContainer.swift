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

/// Contexte volatil et bibliothèque insérée : le point de départ de presque
/// tous les tests de repository.
@MainActor
func makeTestLibrary() throws -> (context: ModelContext, library: Library) {
    let context = ModelContext(try makeTestContainer())
    let library = Library(name: "Principal", isDefault: true)
    context.insert(library)
    try context.save()
    return (context, library)
}

@MainActor
func activityCount(in context: ModelContext, action: ActivityAction? = nil) throws -> Int {
    let entries = try context.fetch(FetchDescriptor<ActivityEntry>())
    guard let action else { return entries.count }
    return entries.count { $0.action == action }
}
