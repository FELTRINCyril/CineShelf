import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Le dédoublonnage, la règle de doublon, et l'invariant des dérivés.
//
// Tous les scénarios viennent de la sonde adverse. Ceux qui portent sur le comportement **avant
// sauvegarde** le disent dans leur nom, comme `CLAUDE.md` l'exige : le chemin SQL est couvert
// séparément par les tests qui sauvegardent entre deux imports.

@MainActor
struct EntityResolverTests {

    @Test("Deux lignes citant la même personne n'en créent qu'une, avant toute sauvegarde")
    func samePersonTwiceBeforeSaveCreatesOne() async throws {
        // **Le cas nommé par `CLAUDE.md`** : le comportement avant `save()` est ici le sujet.
        // Sans le cache de lot, le second `fetch` ne verrait pas la personne créée par la
        // première ligne, et l'import créerait le doublon qu'il cherche à éviter.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Réalisation"],
                rows: [["Dune", "Denis Villeneuve"], ["Sicario", "Denis Villeneuve"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(try fixture.people().count == 1)
        #expect(try fixture.people().first?.displayName == "Denis Villeneuve")
    }

    @Test("La même personne écrite autrement est la même personne")
    func personKeyIgnoresCaseAndDiacritics() async throws {
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Réalisation"],
                rows: [["A", "Denis Villeneuve"], ["B", "DENIS VILLENEUVE"], ["C", "denis villeneuve"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        // La clé est `sortName`, replié en locale invariante — donc reproductible d'un appareil à
        // l'autre. Voir `docs/02` §3.
        #expect(try fixture.people().count == 1)
    }

    @Test("Une personne déjà en base est retrouvée par le chemin SQL, d'un import à l'autre")
    func existingPersonIsFoundThroughTheStore() async throws {
        // Deux imports séparés par un `save()` : c'est la traduction SQL du prédicat qui est
        // exercée ici, et non son équivalent Swift sur des objets en attente.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Réalisation"], rows: [["A", "Denis Villeneuve"]]),
            fileName: "1.csv", libraryID: fixture.library.id)
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Réalisation"], rows: [["B", "denis villeneuve"]]),
            fileName: "2.csv", libraryID: fixture.library.id)

        #expect(try fixture.people().count == 1)
    }

    @Test("La clé de dédoublonnage est bien celle que refreshDerived compose")
    func personSortKeyMatchesRefreshDerived() throws {
        // **Sans ce test, changer l'un des deux casserait le dédoublonnage en silence** : la
        // recherche ne trouverait simplement jamais de doublon, et chaque import créerait des
        // personnes en double sans une erreur.
        let person = Person(firstName: "Denis", lastName: "Villeneuve")
        person.refreshDerived()
        #expect(person.sortName == Person.sortKey(firstName: "Denis", lastName: "Villeneuve"))

        let single = Person(firstName: "", lastName: "Madonna")
        single.refreshDerived()
        #expect(single.sortName == Person.sortKey(firstName: "", lastName: "Madonna"))
    }

    @Test(
        "Un nom complet se coupe au dernier espace",
        arguments: [
            ("Denis Villeneuve", "Denis", "Villeneuve"),
            ("Jean Pierre Melville", "Jean Pierre", "Melville"),
            ("Madonna", "", "Madonna"),
            ("  Denis   Villeneuve  ", "Denis", "Villeneuve")
        ])
    func nameSplitting(full: String, first: String, last: String) {
        // Au dernier espace et non au premier : « Jean Pierre Melville » a « Melville » pour nom
        // de famille, pas « Pierre Melville ».
        let split = EntityResolver.splitName(full.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(split.first == first)
        #expect(split.last == last)
    }

    @Test("Un genre à la corbeille ne ressuscite pas")
    func trashedGenreIsNotRevived() async throws {
        let fixture = try makeImportFixture()
        let repository = GenreRepository(context: fixture.context)
        let genre = try repository.findOrCreate(name: "Action", in: fixture.library)
        repository.softDelete(genre)
        try fixture.context.save()

        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Genres"], rows: [["Dune", "action"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        // Comportement documenté dans `docs/02` §3.5 : `findOrCreate` filtre `deletedAt == nil`,
        // donc retaper un genre supprimé en crée un neuf plutôt que de ressusciter l'ancien avec
        // toutes ses anciennes associations.
        let genres = try fixture.freshContext().fetch(FetchDescriptor<Genre>())
        #expect(genres.count == 2)
        #expect(genres.filter { $0.deletedAt == nil }.count == 1)
    }

    @Test("Les entités d'une autre bibliothèque ne sont pas vues")
    func otherLibraryIsInvisible() async throws {
        let fixture = try makeImportFixture()
        let other = Library(name: "Bac à sable")
        fixture.context.insert(other)
        _ = TitleRepository(context: fixture.context).create(name: "Dune", in: other)
        _ = try GenreRepository(context: fixture.context).findOrCreate(name: "Action", in: other)
        try fixture.context.save()

        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Genres"], rows: [["Dune", "Action"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        // Le « Dune » de l'autre bibliothèque n'est pas un doublon, et son genre « Action » n'est
        // pas réutilisable : une entité qui fuit d'une bibliothèque à l'autre est la cause la plus
        // sournoise de `BulkRefusalReason`.
        #expect(result.createdTitleIDs.count == 1)
        #expect(try fixture.titles().count == 2)
        #expect(try fixture.freshContext().fetch(FetchDescriptor<Genre>()).count == 2)
    }

    @Test("Le même genre répété dans une cellule n'est attaché qu'une fois")
    func repeatedGenreInOneCellAttachesOnce() async throws {
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Genres"], rows: [["Dune", "action/action/Action"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(try fixture.freshContext().fetch(FetchDescriptor<Genre>()).count == 1)
        let title = try #require(try fixture.titles().first)
        #expect((title.genres ?? []).count == 1)
    }
}

// MARK: - La règle de doublon

@MainActor
struct ImportDuplicateRuleTests {

    @Test("Le même titre et la même année complètent la fiche au lieu d'en créer une seconde")
    func duplicateCompletesInsteadOfCreating() async throws {
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Année", "Note · sur 10"],
                rows: [["Dune", "2021", ""], ["Dune", "2021", "9"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        // Règle arrêtée le 2026-08-04 : clé nom replié + année, et on complète.
        #expect(try fixture.titles().count == 1)
        #expect(try fixture.titles().first?.rating == 9)
    }

    @Test("Un import ne remplace jamais une valeur déjà là")
    func existingValuesAreNeverOverwritten() async throws {
        let fixture = try makeImportFixture()
        let repository = TitleRepository(context: fixture.context)
        let existing = repository.create(name: "Dune", in: fixture.library)
        repository.update(existing, journal: .perEntity) {
            $0.rating = 7
            $0.releaseDate = ImportWriter.firstDay(of: 2021)
        }
        try fixture.context.save()

        let result = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Année", "Note · sur 10", "Résumé"],
                rows: [["Dune", "2021", "9", "un résumé"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let title = try #require(try fixture.titles().first)
        // Un import ne doit pas pouvoir dégrader une fiche soignée à la main.
        #expect(title.rating == 7, "la note existante est conservée")
        #expect(title.summary == "un résumé", "le champ vide est rempli")
        #expect(result.completedTitleIDs.count == 1)
    }

    @Test("Les valeurs d'avant sont écrites dans le diff, pour que l'annulation les rétablisse")
    func previousValuesAreRecorded() async throws {
        let fixture = try makeImportFixture()
        let repository = TitleRepository(context: fixture.context)
        let existing = repository.create(name: "Dune", in: fixture.library)
        repository.update(existing, journal: .perEntity) { $0.releaseDate = ImportWriter.firstDay(of: 2021) }
        try fixture.context.save()

        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année", "Résumé"], rows: [["Dune", "2021", "un résumé"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let diff = try ImportBatchDiff.decoded(
            from: try #require(try fixture.batchEntries().first?.payload))
        let completion = try #require(diff.completions.first)
        // `nil` signifie **le champ était vide**, ce qui est l'information à rétablir — pas une
        // absence d'information.
        #expect(completion.previousValues.keys.contains("summary"))
        #expect(completion.previousValues["summary"] == .some(nil))
    }

    @Test("Un titre sans année et un titre daté sont deux éditions différentes")
    func undatedTitleIsNotADuplicateOfADatedOne() async throws {
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", ""], ["Dune", "2021"], ["Dune", ""]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        // Les confondre écrirait dans la mauvaise fiche.
        #expect(result.createdTitleIDs.count == 2)
        #expect(try fixture.titles().count == 2)
        // **Le troisième « Dune » sans année retrouve le premier, et disparaît du bilan.** Il
        // n'est pas compté « inchangé » : le repliage par entité donne la précédence à `created`,
        // parce que la fiche a bien été créée **par cet import**. L'annulation doit donc la
        // retirer, et non restaurer un état d'avant qui n'a jamais existé. La première version
        // comptait la ligne séparément, ce qui faisait dire au bilan « 2 ajoutés, 1 inchangé »
        // pour deux fiches.
        #expect(result.unchangedTitleIDs.isEmpty)
        #expect(result.processedCount == 3, "les trois lignes ont bien été traitées")
    }

    @Test("Réimporter le même fichier ne duplique rien, et ne journalise rien")
    func reimportingTheSameFileIsIdempotent() async throws {
        let fixture = try makeImportFixture()
        let rows = importRows(
            header: ["Titre", "Année", "Genres", "Réalisation"],
            rows: [["Dune", "2021", "sci-fi", "Denis Villeneuve"], ["Tenet", "2020", "action", "Nolan"]])

        let first = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)
        let second = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)

        #expect(first.createdTitleIDs.count == 2)
        #expect(second.createdTitleIDs.isEmpty)
        #expect(second.unchangedTitleIDs.count == 2)
        #expect(try fixture.titles().count == 2)
        #expect(try fixture.people().count == 2)
        // Les crédits **surtout** : les rattacher une seconde fois est le défaut le plus facile
        // à ne pas voir, puisque la fiche paraît correcte.
        #expect(try fixture.freshContext().fetch(FetchDescriptor<Credit>()).count == 2)
        // Rien n'a changé, donc rien à annuler, donc aucune entrée.
        #expect(try fixture.batchEntries().count == 1)
    }

    @Test("La distribution garde l'ordre du générique")
    func castKeepsFileOrder() async throws {
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Distribution"],
                rows: [["Dune", "Timothée Chalamet/Rebecca Ferguson/Josh Brolin"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let title = try #require(try fixture.titles().first)
        let cast = (title.credits ?? [])
            .filter { $0.role == .cast }
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap(\.person?.displayName)
        #expect(cast == ["Timothée Chalamet", "Rebecca Ferguson", "Josh Brolin"])
    }
}

// MARK: - L'invariant des dérivés, prouvé par idempotence

@MainActor
struct ImportDerivedValuesTests {

    @Test("Les dérivés d'un import sont ceux que refreshDerived produit")
    func derivedValuesAreIdempotentAfterImport() async throws {
        // **La preuve que `ImportWriter` appelle bien `refreshDerived()`**, et elle ne dépend pas
        // de ma parole ni de ma connaissance de ce que la méthode calcule : on la rappelle et on
        // vérifie que **rien ne change**. Un oubli laisserait un dérivé en arrière, donc un écart
        // au second appel. Même ruse que la comparaison de locale.
        //
        // C'est le filet du « piège central » de la fiche : les repositories sont `@MainActor`,
        // l'import écrit depuis un acteur, donc il porte l'invariant lui-même.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Genres", "Collection", "Réalisation"],
                rows: [["Dune", "sci-fi/thriller", "Saga Dune", "Denis Villeneuve"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let context = fixture.freshContext()

        for title in try context.fetch(FetchDescriptor<Title>()) {
            let before = [title.sortName, title.searchText, title.filterKeys]
            title.refreshDerived()
            #expect(before == [title.sortName, title.searchText, title.filterKeys], "titre")
        }
        for person in try context.fetch(FetchDescriptor<Person>()) {
            let before = [person.displayName, person.sortName, person.searchText, person.filterKeys]
            person.refreshDerived()
            #expect(
                before == [person.displayName, person.sortName, person.searchText, person.filterKeys],
                "personne")
        }
        for collection in try context.fetch(FetchDescriptor<TitleCollection>()) {
            let before = [collection.sortName, collection.searchText]
            collection.refreshDerived()
            #expect(before == [collection.sortName, collection.searchText], "collection")
        }
    }

    @Test("Un titre importé est retrouvable par le filtre de son genre")
    func importedTitleIsFoundByItsGenreFilter() async throws {
        // La conséquence concrète de l'invariant : `filterKeys` dénormalise les relations, donc un
        // titre écrit sans rafraîchissement serait introuvable par le filtre correspondant — sans
        // erreur, et sans qu'aucun test de relation ne bronche.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Genres"], rows: [["Dune", "sci-fi"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let context = fixture.freshContext()
        let genre = try #require(try context.fetch(FetchDescriptor<Genre>()).first)
        let title = try #require(try context.fetch(FetchDescriptor<Title>()).first)
        #expect(title.filterKeys.contains(FilterKey.genre(genre.id)))
    }

    @Test("Chaque champ du schéma est traité par l'écrivain")
    func everySchemaFieldIsHandledByTheWriter() {
        // **Le compilateur ne garde rien ici** : la clé est une `String`, donc une colonne ajoutée
        // au schéma tomberait dans le `default` de l'écrivain — jamais écrite sur un titre neuf,
        // jamais complétée sur un doublon, et sans aucun signal. Ce test échoue à l'ajout d'une
        // colonne, c'est-à-dire au moment où on peut encore décider.
        let schemaKeys = Set(CSVSchema.title.fields.map(\.key))
        #expect(
            schemaKeys.subtracting(ImportWriter.handledKeys).isEmpty,
            "champs du schéma non traités : \(schemaKeys.subtracting(ImportWriter.handledKeys))")
        #expect(
            ImportWriter.handledKeys.subtracting(schemaKeys).isEmpty,
            "clés traitées qui n'existent plus : \(ImportWriter.handledKeys.subtracting(schemaKeys))")
    }
}
