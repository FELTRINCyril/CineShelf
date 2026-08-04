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

        try repository.rename(record, to: "Après")
        try context.save()

        #expect(record.name == "Après")
        // `ActivityEntityType` n'a pas de cas pour une correspondance de colonnes, et lui en
        // ajouter un mettrait un réglage d'import dans le fil d'activité du catalogue.
        // `JournalPolicy` reste le sujet de `L11b`, où c'est l'import lui-même qui écrit une
        // entrée **pour le lot** — pas une par titre, et pas une par mappage.
        #expect(try activityCount(in: context) == 0)
    }
}

// Les défauts du repository trouvés par la revue du 2026-08-04.
@MainActor
struct ImportMappingRepositoryRegressionTests {

    /// Même montage que la suite principale : magasin volatil, contexte, bibliothèque.
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let library: Library

        func freshContext() -> ModelContext { ModelContext(container) }
    }

    private func makeFixture() throws -> Fixture {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let library = Library(name: "Principal", isDefault: true)
        context.insert(library)
        try context.save()
        return Fixture(container: container, context: context, library: library)
    }

    @Test("Un intégré plus récent ne prend pas le pas sur la correspondance personnelle")
    func personalMappingWinsOverNewerBuiltIn() throws {
        // **Le masquage annoncé ne reposait sur rien.** La lecture triait sur `updatedAt`
        // seul, donc une correspondance personnelle ne passait devant que si elle était plus
        // récente — or un `isBuiltIn` arrive par une mise à jour de l'app ou par une fusion
        // CloudKit, donc **plus tard**. Le personnel passe maintenant devant par règle.
        let fixture = try makeFixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "year"]
        let repository = ImportMappingRepository(context: context)

        try repository.save(
            ColumnMapping(entity: .title, columnToField: ["title": "title"]),
            named: "Le mien", forHeader: header, in: library)
        try context.save()

        let builtIn = ImportMapping(
            name: "Movix", headerSignature: ColumnMapping.headerSignature(for: header))
        builtIn.isBuiltIn = true
        builtIn.library = library
        builtIn.updatedAt = Date(timeIntervalSinceNow: 3600)
        context.insert(builtIn)
        try context.save()

        let fresh = fixture.freshContext()
        let freshLibrary = try #require(try fresh.fetch(FetchDescriptor<Library>()).first)
        let found = try ImportMappingRepository(context: fresh)
            .mapping(forHeader: header, in: freshLibrary)

        #expect(found?.name == "Le mien")
    }

    @Test("Mémoriser deux fois face à un intégré ne crée pas deux correspondances")
    func savingBesideABuiltInDoesNotDuplicate() throws {
        // Mesuré avant correction : trois enregistrements pour une seule signature, dont deux
        // personnels — le doublon silencieux de `Genre.nameKey`, transposé. `save` cherchait
        // « la plus récente » et, la trouvant intégrée, insérait un nouvel enregistrement à
        // chaque appel.
        let fixture = try makeFixture()
        let (context, library) = (fixture.context, fixture.library)
        let header = ["title", "year"]
        let repository = ImportMappingRepository(context: context)

        let builtIn = ImportMapping(
            name: "Movix", headerSignature: ColumnMapping.headerSignature(for: header))
        builtIn.isBuiltIn = true
        builtIn.library = library
        builtIn.updatedAt = Date(timeIntervalSinceNow: 3600)
        context.insert(builtIn)

        for name in ["Le mien", "Le mien v2", "Le mien v3"] {
            try repository.save(
                ColumnMapping(entity: .title, columnToField: ["title": "title"]),
                named: name, forHeader: header, in: library)
            try context.save()
        }

        let fresh = fixture.freshContext()
        let all = try fresh.fetch(FetchDescriptor<ImportMapping>())
        #expect(all.count == 2, "un intégré et un seul personnel")
        #expect(all.filter { !$0.isBuiltIn }.map(\.name) == ["Le mien v3"])
    }

    @Test("Un en-tête à colonnes homonymes refuse d'être mémorisé")
    func duplicateColumnNamesAreRefused() throws {
        // La correspondance est mémorisée par nom, donc deux homonymes en perdraient une — et
        // c'était le champ requis qui disparaissait dans le cas mesuré. Un refus nommé plutôt
        // qu'un arbitrage muet.
        let fixture = try makeFixture()
        let (context, library) = (fixture.context, fixture.library)

        #expect(throws: ColumnMappingError.duplicateColumnNames(["Titre"])) {
            try ImportMappingRepository(context: context).save(
                ColumnMapping(entity: .title, columnToField: ["Titre": "title"]),
                named: "Bancal", forHeader: ["Titre", "Titre"], in: library)
        }
        #expect(try context.fetch(FetchDescriptor<ImportMapping>()).isEmpty)
    }

    @Test("Une correspondance intégrée refuse aussi d'être renommée")
    func builtInCannotBeRenamed() throws {
        // `delete` le refusait, `rename` non — et il bougeait `updatedAt`, ce qui faisait
        // passer l'intégré devant le personnel avant que la lecture ne trie sur `isBuiltIn`.
        let fixture = try makeFixture()
        let (context, library) = (fixture.context, fixture.library)
        let builtIn = ImportMapping(name: "Movix", headerSignature: "x")
        builtIn.isBuiltIn = true
        builtIn.library = library
        context.insert(builtIn)

        #expect(throws: ImportMappingError.builtInCannotBeRenamed) {
            try ImportMappingRepository(context: context).rename(builtIn, to: "Le mien")
        }
        #expect(builtIn.name == "Movix")
    }
}
