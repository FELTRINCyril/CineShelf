import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Le seul endroit de `L11a` qui écrit dans le magasin — et il n'écrit que des
// correspondances de colonnes, jamais une entité du catalogue. C'est ce que la coupe
// `L11a` / `L11b` garantit.
//
// **Tout ce qui interroge par prédicat passe par le magasin**, comme `CLAUDE.md` l'exige :
// `save()` puis relecture depuis un contexte neuf. Sur du pending, SwiftData évalue le
// prédicat en Swift et sa traduction SQL n'est pas exercée — c'est ce qui avait laissé 42
// tests verts sur une grille vide.

@MainActor
struct ImportMappingRepositoryTests {

    /// Magasin volatil, contexte, bibliothèque. Un type plutôt qu'un triplet : les
    /// assertions relisent depuis un **contexte neuf** sur le même conteneur, donc les trois
    /// voyagent ensemble.
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let library: Library

        /// Un contexte neuf sur le même magasin : ce qu'un autre écran verrait.
        func freshContext() -> ModelContext { ModelContext(container) }
    }

    private func fixture() throws -> Fixture {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let library = Library(name: "Principal", isDefault: true)
        context.insert(library)
        try context.save()
        return Fixture(container: container, context: context, library: library)
    }

    @Test("Une correspondance mémorisée se retrouve depuis un contexte neuf")
    func savedMappingIsFoundThroughTheStore() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "runtime_min", "my_score"]
        let mapping = ColumnMatcher(schema: .title).analyze(header: header).mapping

        try ImportMappingRepository(context: context)
            .save(mapping, named: "Mon export", forHeader: header, in: library)
        try context.save()

        // Contexte neuf : c'est le chemin SQL du prédicat qui est exercé, pas son
        // équivalent Swift sur des objets en attente.
        let fresh = fixture.freshContext()
        let freshLibrary = try #require(try fresh.fetch(FetchDescriptor<Library>()).first)
        let found = try ImportMappingRepository(context: fresh)
            .mapping(forHeader: header, in: freshLibrary)

        #expect(found?.name == "Mon export")
    }

    @Test("Le même en-tête dans un autre ordre retrouve la correspondance")
    func reorderedHeaderStillMatches() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "year", "genre_raw"]
        let mapping = ColumnMatcher(schema: .title).analyze(header: header).mapping

        try ImportMappingRepository(context: context)
            .save(mapping, named: "Mon export", forHeader: header, in: library)
        try context.save()

        let fresh = fixture.freshContext()
        let freshLibrary = try #require(try fresh.fetch(FetchDescriptor<Library>()).first)
        let found = try ImportMappingRepository(context: fresh)
            .mapping(forHeader: ["genre_raw", "title", "year"], in: freshLibrary)

        // Un tableur qui déplace une colonne produit le même fichier pour l'utilisateur, et
        // la correspondance est mémorisée par nom : l'ordre ne change rien à ce qu'elle décide.
        #expect(found != nil)
    }

    @Test("Un en-tête différent ne retrouve rien")
    func differentHeaderFindsNothing() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "year"]

        try ImportMappingRepository(context: context).save(
            ColumnMatcher(schema: .title).analyze(header: header).mapping,
            named: "Mon export", forHeader: header, in: library)
        try context.save()

        let fresh = fixture.freshContext()
        let freshLibrary = try #require(try fresh.fetch(FetchDescriptor<Library>()).first)
        #expect(
            try ImportMappingRepository(context: fresh)
                .mapping(forHeader: ["title", "year", "runtime"], in: freshLibrary) == nil)
    }

    @Test("Mémoriser deux fois le même en-tête met à jour au lieu de dupliquer")
    func savingTwiceUpdatesInPlace() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "col_1"]
        let repository = ImportMappingRepository(context: context)

        try repository.save(
            ColumnMapping(entity: .title, columnToField: ["title": "title"]),
            named: "Premier jet", forHeader: header, in: library)
        try context.save()
        try repository.save(
            ColumnMapping(entity: .title, columnToField: ["title": "title", "col_1": "year"]),
            named: "Corrigé", forHeader: header, in: library)
        try context.save()

        // `ImportMapping` n'a pas d'`@Attribute(.unique)` — CloudKit l'interdit. L'unicité se
        // tient donc ici, comme pour `Genre.nameKey`. Deux correspondances du même en-tête
        // rendraient la première invisible sans la supprimer.
        let fresh = fixture.freshContext()
        let all = try fresh.fetch(FetchDescriptor<ImportMapping>())
        #expect(all.count == 1)
        #expect(all.first?.name == "Corrigé")

        let record = try #require(all.first)
        let reread = try #require(
            try ImportMappingRepository(context: fresh).columnMapping(of: record))
        #expect(reread.columnToField["col_1"] == "year")
    }

    @Test("Une correspondance d'une autre bibliothèque n'est pas visible")
    func mappingsAreScopedToTheirLibrary() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let other = Library(name: "Bac à sable")
        context.insert(other)
        let header = ["title", "year"]

        try ImportMappingRepository(context: context).save(
            ColumnMapping(entity: .title, columnToField: ["title": "title"]),
            named: "Principal", forHeader: header, in: library)
        try context.save()

        let fresh = fixture.freshContext()
        let freshOther = try #require(
            try fresh.fetch(FetchDescriptor<Library>()).first { $0.name == "Bac à sable" })
        #expect(
            try ImportMappingRepository(context: fresh)
                .mapping(forHeader: header, in: freshOther) == nil)
    }

    @Test("Une correspondance se supprime, et disparaît du magasin")
    func deleteRemovesTheRecord() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let repository = ImportMappingRepository(context: context)
        let record = try repository.save(
            ColumnMapping(entity: .title, columnToField: [:]),
            named: "Jetable", forHeader: ["title"], in: library)
        try context.save()

        try repository.delete(record)
        try context.save()

        let fresh = fixture.freshContext()
        #expect(try fresh.fetch(FetchDescriptor<ImportMapping>()).isEmpty)
    }

    @Test("Une correspondance intégrée refuse d'être supprimée")
    func builtInMappingCannotBeDeleted() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let record = ImportMapping(name: "Movix", headerSignature: "x")
        record.isBuiltIn = true
        record.library = library
        context.insert(record)

        // `ImportMapping.isBuiltIn` dit « ne se supprime pas et se retrouve après une
        // réinstallation » : la supprimer localement la ferait revenir au prochain lancement,
        // ce qui se lit comme un bug. Un refus explicite plutôt qu'une suppression qui ne
        // tient pas.
        #expect(throws: ImportMappingError.builtInCannotBeDeleted) {
            try ImportMappingRepository(context: context).delete(record)
        }
    }

    @Test("Une correspondance personnelle ne réécrit pas une correspondance intégrée")
    func personalMappingDoesNotOverwriteBuiltIn() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "year"]
        let builtIn = ImportMapping(
            name: "Movix", headerSignature: ColumnMapping.headerSignature(for: header))
        builtIn.isBuiltIn = true
        builtIn.library = library
        context.insert(builtIn)
        try context.save()

        try ImportMappingRepository(context: context).save(
            ColumnMapping(entity: .title, columnToField: ["title": "title"]),
            named: "Le mien", forHeader: header, in: library)
        try context.save()

        // Deux enregistrements : l'intégré reste intact, et la lecture prend le plus récent,
        // donc l'utilisateur passe devant.
        let fresh = fixture.freshContext()
        #expect(try fresh.fetch(FetchDescriptor<ImportMapping>()).count == 2)

        let freshLibrary = try #require(try fresh.fetch(FetchDescriptor<Library>()).first)
        let found = try ImportMappingRepository(context: fresh)
            .mapping(forHeader: header, in: freshLibrary)
        #expect(found?.name == "Le mien")
    }

    @Test("Une correspondance vide se relit comme absente, pas comme une erreur")
    func emptyPayloadReadsAsNil() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let record = ImportMapping(name: "Sans données", headerSignature: "x")
        record.library = library
        context.insert(record)

        #expect(try ImportMappingRepository(context: context).columnMapping(of: record) == nil)
    }

    @Test("Le renommage n'est pas journalisé, et c'est assumé")
    func renamingDoesNotJournal() throws {
        let fixture = try fixture()
        let (context, library) = (fixture.context, fixture.library)
        let repository = ImportMappingRepository(context: context)
        let record = try repository.save(
            ColumnMapping(entity: .title, columnToField: [:]),
            named: "Avant", forHeader: ["title"], in: library)
        try context.save()

        repository.rename(record, to: "Après")
        try context.save()

        #expect(record.name == "Après")
        // `ActivityEntityType` n'a pas de cas pour une correspondance de colonnes, et lui en
        // ajouter un mettrait un réglage d'import dans le fil d'activité du catalogue.
        // `JournalPolicy` reste le sujet de `L11b`, où c'est l'import lui-même qui écrit une
        // entrée **pour le lot** — pas une par titre, et pas une par mappage.
        #expect(try activityCount(in: context) == 0)
    }
}
