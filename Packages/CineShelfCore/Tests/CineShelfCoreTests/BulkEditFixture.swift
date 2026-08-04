import Foundation
import SwiftData

@testable import CineShelfCore

// Le montage partagé par les suites d'édition en masse.
//
// Il tient à un détail qui n'est pas cosmétique : les vérifications de « rien n'a été
// écrit » relisent depuis un **contexte neuf**, jamais depuis celui de l'éditeur. Sur des
// objets encore en attente, un `rollback()` mal fait passe inaperçu — et c'est
// exactement la classe de test vert sur base cassée qui a coûté 42 tests au prompt 11.

@MainActor
struct BulkEditFixture {
    let container: ModelContainer
    let context: ModelContext
    let library: Library

    /// L'éditeur partage le contexte de la fixture : c'est ce qui permet d'observer
    /// l'état intermédiaire. Les assertions d'absence d'écriture passent par
    /// `freshContext()`.
    var editor: BulkEditor { BulkEditor(isolatedContext: context) }

    /// Un contexte neuf sur le même magasin : ce qu'un autre écran verrait.
    func freshContext() -> ModelContext { ModelContext(container) }
}

@MainActor
func makeBulkEditFixture() throws -> BulkEditFixture {
    let container = try makeTestContainer()
    let context = ModelContext(container)
    let library = Library(name: "Principal", isDefault: true)
    context.insert(library)
    try context.save()
    return BulkEditFixture(container: container, context: context, library: library)
}

@MainActor
func makeBulkEditTitles(_ names: [String], in fixture: BulkEditFixture) throws -> [Title] {
    let repository = TitleRepository(context: fixture.context)
    let titles = names.map { repository.create(name: $0, in: fixture.library) }
    try fixture.context.save()
    return titles
}
