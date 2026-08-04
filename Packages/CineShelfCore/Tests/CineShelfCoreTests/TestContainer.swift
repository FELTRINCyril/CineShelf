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

/// Un index Spotlight observable, partagé par les suites qui l'exercent.
///
/// **Extrait de `SpotlightIndexerTests` le 2026-08-04, quand `L11b` en a eu besoin.** Il y était
/// `private`, et la deuxième suite qui a voulu observer l'indexation aurait donc dû en écrire un
/// second. Deux espions du même protocole finissent par ne pas enregistrer les mêmes choses, et
/// c'est la leçon que `CatalogBounds` et `EntityResolver` ont déjà coûtée aujourd'hui.
final class RecordingSpotlightIndex: SpotlightIndexing {
    private(set) var indexed: [SpotlightEntry] = []
    private(set) var removed: [String] = []
    private(set) var removeAllCount = 0

    func index(_ entries: [SpotlightEntry]) { indexed.append(contentsOf: entries) }
    func remove(identifiers: [String]) { removed.append(contentsOf: identifiers) }
    func removeAll() { removeAllCount += 1 }

    /// Repart d'un journal vide, pour n'observer que ce qui suit la préparation.
    ///
    /// `removeAllCount` n'est pas remis à zéro : c'est un compteur d'événements rares, et les
    /// tests qui l'observent veulent son total.
    func forgetCalls() {
        indexed.removeAll()
        removed.removeAll()
    }
}
