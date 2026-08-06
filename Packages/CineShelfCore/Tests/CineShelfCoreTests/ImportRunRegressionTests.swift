import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les cinq défauts de `L11b` trouvés par la revue du 2026-08-04, tous reproduits sur sonde avant
// correction. Aucun n'aurait été vu par un test écrit depuis les mêmes hypothèses que le code :
// deux portaient sur une **colonne du schéma que je n'avais pas essayée**, un sur une entrée
// répétée, un sur l'identité de l'acteur, un sur une cellule que la validation acceptait.

@MainActor
struct ImportDuplicateKeyRegressionTests {

    @Test("Un fichier daté sans colonne « Année » ne duplique pas, ni dans le lot ni entre imports")
    func releaseDateAloneFeedsTheDuplicateKey() async throws {
        // **Le défaut le plus grave de la passe.** L'année de la clé de doublon ne venait que de
        // la colonne `year` ; `TitleQuery.living` traite une année nulle comme « cherche un titre
        // **sans** date », donc un fichier portant « Date de sortie » seule écrivait une date puis
        // cherchait l'absence de date. Mesuré : deux lignes identiques importées deux fois
        // donnaient **quatre** fiches « Dune », sans un signal, avec un bilan cohérent.
        let fixture = try makeImportFixture()
        let rows = importRows(
            header: ["Titre", "Date de sortie"],
            rows: [["Dune", "2021-10-15"], ["Dune", "2021-10-15"]])
        try #require(rows.allSatisfy(\.isReady) == true)

        let first = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)
        let second = try await fixture.actor.importRows(
            rows, fileName: "f.csv", libraryID: fixture.library.id)

        #expect(first.createdTitleIDs.count == 1, "la seconde ligne est un doublon intra-lot")
        #expect(second.createdTitleIDs.isEmpty, "le réimport ne crée rien")
        #expect(try fixture.titles().count == 1)
    }

    @Test("Une date complète dans la colonne « Année » garde son jour")
    func fullDateInTheYearColumnKeepsItsDay() async throws {
        // L'aide du champ promet « une date complète est acceptée » et `CSVValueParser.year`
        // l'accepte, donc la validation laissait passer `2021-10-15`. L'écrivain n'en gardait que
        // l'année : le jour et le mois étaient jetés **en silence**, sur une cellule que rien ne
        // refusait.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", "2021-10-15"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let title = try #require(try fixture.titles().first)
        let date = try #require(title.releaseDate)
        #expect(calendar.component(.day, from: date) == 15)
        #expect(calendar.component(.month, from: date) == 10)
        #expect(title.releasePrecision == .day)
    }

    @Test("Une année seule garde sa précision d'année")
    func bareYearStillMeansYearPrecision() async throws {
        // La contrepartie du test précédent : la correction ne doit pas transformer toute année en
        // date au jour près.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(header: ["Titre", "Année"], rows: [["Dune", "2021"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(try fixture.titles().first?.releasePrecision == .year)
    }

    @Test("La même personne répétée dans une cellule ne produit qu'un crédit")
    func repeatedPersonInOneCellCreditsOnce() async throws {
        // Le côté genres était couvert ; l'entrée équivalente sur la colonne voisine ne l'était
        // pas. Le résolveur créait bien **une** personne, et `attachCredits` deux `Credit` vers
        // elle : la fiche montrait le même acteur deux fois.
        let fixture = try makeImportFixture()
        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Distribution"],
                rows: [["Dune", "Denis Villeneuve|denis villeneuve"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(try fixture.people().count == 1)
        let credits = try fixture.freshContext().fetch(FetchDescriptor<Credit>())
        #expect(credits.count == 1)
        #expect(credits.first?.orderIndex == 0)
    }
}

@MainActor
struct ImportBilanFoldingTests {

    @Test("Un titre décrit sur plusieurs lignes n'est compté qu'une fois")
    func repeatedTitleIsCountedOnce() async throws {
        // Mesuré avant correction : bilan « 1 ajouté, 2 complétés » pour **une** fiche, et le même
        // `UUID` présent dans `createdTitleIDs` **et** dans `completions`. Pour `L20`, ce diff
        // n'était pas défaisable — il aurait supprimé le titre puis tenté de restaurer des champs
        // sur une fiche disparue.
        let fixture = try makeImportFixture()
        let result = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Année", "Note · sur 10", "Résumé"],
                rows: [["Dune", "2021", "", ""], ["Dune", "2021", "9", ""], ["Dune", "2021", "", "un résumé"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        #expect(try fixture.titles().count == 1)
        #expect(result.createdTitleIDs.count == 1)
        #expect(result.completedTitleIDs.isEmpty, "créée par cet import, donc pas « complétée »")
        #expect(result.processedCount == 3, "les trois lignes ont bien été traitées")

        let payload = try #require(try fixture.batchEntries().first?.payload)
        let diff = try ImportBatchDiff.decoded(from: payload)
        #expect(diff.touchedTitleCount == 1)
        #expect(Set(diff.createdTitleIDs).isDisjoint(with: Set(diff.completions.map(\.entityID))))
        // Et les valeurs des lignes suivantes ont bien été écrites : replier le bilan ne doit pas
        // faire perdre les données.
        let title = try #require(try fixture.titles().first)
        #expect(title.rating == 9)
        #expect(title.summary == "un résumé")
    }

    @Test("Un titre existant décrit sur plusieurs lignes garde la valeur d'avant l'import")
    func previousValuesComeFromBeforeTheImport() async throws {
        let fixture = try makeImportFixture()
        let repository = TitleRepository(context: fixture.context)
        let existing = repository.create(name: "Dune", in: fixture.library)
        repository.update(existing, journal: .perEntity) { $0.releaseDate = ImportWriter.firstDay(of: 2021) }
        try fixture.context.save()

        _ = try await fixture.actor.importRows(
            importRows(
                header: ["Titre", "Année", "Résumé"],
                rows: [["Dune", "2021", "premier"], ["Dune", "2021", "second"]]),
            fileName: "f.csv", libraryID: fixture.library.id)

        let payload = try #require(try fixture.batchEntries().first?.payload)
        let diff = try ImportBatchDiff.decoded(from: payload)
        let completion = try #require(diff.completions.first)
        #expect(diff.completions.count == 1)
        // La **première** valeur gagne à la fusion : c'est celle d'avant l'import, la seule que
        // l'annulation puisse rétablir.
        #expect(completion.previousValues["summary"] == .some(nil))
        // Et la première ligne a gagné l'écriture, la seconde ne trouvant plus le champ vide.
        #expect(try fixture.titles().first?.summary == "premier")
    }
}

@MainActor
struct ImportActorLockRegressionTests {

    @Test("Deux acteurs sur le même magasin partagent le verrou")
    func twoActorsOnOneContainerAreSerialised() async throws {
        // **La première version indexait le verrou sur `ObjectIdentifier(actor)`, et ça ne
        // protégeait rien.** Mesuré : deux acteurs distincts sur le même conteneur, le même
        // fichier de 300 lignes en parallèle, **600 titres** en base et deux personnes au lieu
        // d'une, sans qu'aucun `alreadyRunning` ne soit levé. Le cas n'est pas théorique — une
        // propriété calculée qui fabrique un acteur par accès suffit, et mon propre montage de
        // test en avait une.
        let fixture = try makeImportFixture()
        let rows = importRows(
            header: ["Titre", "Année", "Réalisation"],
            rows: (1...300).map { ["T\($0)", "2000", "Denis Villeneuve"] })
        let first = ImportActor(modelContainer: fixture.container)
        let second = ImportActor(modelContainer: fixture.container)
        let libraryID = fixture.library.id

        let one = Task { try await first.importRows(rows, fileName: "a.csv", libraryID: libraryID) }
        let two = Task { try await second.importRows(rows, fileName: "b.csv", libraryID: libraryID) }

        var refused = 0
        var succeeded = 0
        for task in [one, two] {
            do {
                _ = try await task.value
                succeeded += 1
            } catch ImportRunError.alreadyRunning {
                refused += 1
            }
        }
        #expect(succeeded == 1)
        #expect(refused == 1)
        #expect(try fixture.titles().count == 300)
        #expect(try fixture.people().count == 1)
    }

    @Test("Deux magasins distincts s'importent en parallèle")
    func differentContainersDoNotBlockEachOther() async throws {
        // La contrepartie : le verrou protège un magasin, pas le processus. Deux bibliothèques
        // dans deux conteneurs — le cas d'un test parallèle — ne doivent pas se gêner.
        let one = try makeImportFixture()
        let two = try makeImportFixture()
        let rowsOne = importRows(header: ["Titre", "Année"], rows: [["A", "2000"]])
        let rowsTwo = importRows(header: ["Titre", "Année"], rows: [["B", "2001"]])
        let actorOne = one.actor
        let actorTwo = two.actor
        let idOne = one.library.id
        let idTwo = two.library.id

        let taskOne = Task { try await actorOne.importRows(rowsOne, fileName: "a.csv", libraryID: idOne) }
        let taskTwo = Task { try await actorTwo.importRows(rowsTwo, fileName: "b.csv", libraryID: idTwo) }

        let resultOne = try await taskOne.value
        let resultTwo = try await taskTwo.value
        #expect(resultOne.createdTitleIDs.count == 1)
        #expect(resultTwo.createdTitleIDs.count == 1)
    }
}

@MainActor
struct ImportEnrichmentTests {

    @Test("Un réimport enrichi ajoute les genres et les crédits manquants")
    func enrichedReimportAddsMissingMembers() async throws {
        // Mesuré avant correction : bilan « 0 ajoutés, 0 complétés, 1 inchangés », et les deux
        // ajouts **abandonnés sans être comptés nulle part**. C'est le geste le plus naturel qu'un
        // utilisateur fera après avoir complété son tableur.
        let fixture = try makeImportFixture()
        let actor = fixture.actor
        _ = try await actor.importRows(
            importRows(
                header: ["Titre", "Année", "Genres", "Distribution"],
                rows: [["Dune", "2021", "sci-fi", "A B"]]),
            fileName: "1.csv", libraryID: fixture.library.id)

        let result = try await actor.importRows(
            importRows(
                header: ["Titre", "Année", "Genres", "Distribution"],
                rows: [["Dune", "2021", "sci-fi|thriller", "A B|C D"]]),
            fileName: "2.csv", libraryID: fixture.library.id)

        #expect(result.completedTitleIDs.count == 1)
        let title = try #require(try fixture.titles().first)
        #expect((title.genres ?? []).map(\.name).sorted() == ["sci-fi", "thriller"])
        #expect((title.credits ?? []).count == 2)
    }

    @Test("Un réimport identique reste inchangé : ajouter est idempotent")
    func identicalReimportStaysUnchanged() async throws {
        // Sans cette propriété, « ajouter au lieu de sauter » redoublerait les relations à chaque
        // import — le défaut qu'on venait de corriger, retourné.
        let fixture = try makeImportFixture()
        let actor = fixture.actor
        let rows = importRows(
            header: ["Titre", "Année", "Genres", "Distribution"],
            rows: [["Dune", "2021", "sci-fi|thriller", "A B|C D"]])

        _ = try await actor.importRows(rows, fileName: "1.csv", libraryID: fixture.library.id)
        let second = try await actor.importRows(rows, fileName: "2.csv", libraryID: fixture.library.id)

        #expect(second.unchangedTitleIDs.count == 1)
        #expect(second.completedTitleIDs.isEmpty)
        let title = try #require(try fixture.titles().first)
        #expect((title.genres ?? []).count == 2)
        #expect((title.credits ?? []).count == 2)
        // **Une seule entrée de journal** : le second import n'a rien changé, donc il n'y a rien à
        // annuler.
        #expect(try fixture.batchEntries().count == 1)
    }

    @Test("Le diff dit quelles relations détacher")
    func diffRecordsAttachedRelations() async throws {
        // Un champ vide se rétablit en réécrivant son ancienne valeur ; une relation ajoutée, non.
        // Sans ces listes, l'enrichissement serait appliqué mais **pas annulable**, et `L20`
        // défairait la moitié d'un lot en croyant tout défaire.
        let fixture = try makeImportFixture()
        let actor = fixture.actor
        _ = try await actor.importRows(
            importRows(header: ["Titre", "Année", "Genres"], rows: [["Dune", "2021", "sci-fi"]]),
            fileName: "1.csv", libraryID: fixture.library.id)
        _ = try await actor.importRows(
            importRows(
                header: ["Titre", "Année", "Genres", "Distribution"],
                rows: [["Dune", "2021", "sci-fi|thriller", "A B"]]),
            fileName: "2.csv", libraryID: fixture.library.id)

        let entries = try fixture.batchEntries().sorted { $0.createdAt < $1.createdAt }
        let payload = try #require(entries.last?.payload)
        let diff = try ImportBatchDiff.decoded(from: payload)
        let completion = try #require(diff.completions.first)
        #expect(completion.attachedGenreIDs.count == 1, "seul « thriller » est neuf")
        #expect(completion.addedCreditIDs.count == 1)
    }

    @Test("Un fichier peut rendre un titre privé, jamais le rendre public")
    func privacyIsMonotonic() async throws {
        // Entre les deux erreurs possibles, celle qui expose un contenu marqué privé est la seule
        // qui ne se répare pas : c'est la fuite que `L3` a fermée, et l'index Spotlight est unique
        // pour l'appareil. Mesuré avant correction : le titre restait public **et** était réindexé.
        let fixture = try makeImportFixture()
        let actor = fixture.actor
        _ = try await actor.importRows(
            importRows(header: ["Titre", "Année", "Privé"], rows: [["Dune", "2021", "non"]]),
            fileName: "1.csv", libraryID: fixture.library.id)
        let beforeSecondImport = try fixture.titles().first?.isPrivate
        try #require(beforeSecondImport == false)

        _ = try await actor.importRows(
            importRows(header: ["Titre", "Année", "Privé"], rows: [["Dune", "2021", "oui"]]),
            fileName: "2.csv", libraryID: fixture.library.id)
        #expect(try fixture.titles().first?.isPrivate == true)

        // Et dans l'autre sens, « ne jamais écraser » s'applique pleinement.
        _ = try await actor.importRows(
            importRows(header: ["Titre", "Année", "Privé"], rows: [["Dune", "2021", "non"]]),
            fileName: "3.csv", libraryID: fixture.library.id)
        #expect(try fixture.titles().first?.isPrivate == true, "un fichier ne dé-privatise pas")
    }
}

@MainActor
struct ImportDraftRestoreTests {

    @Test("Une ligne mal découpée reste refusée après reprise")
    func malformationSurvivesTheDraft() throws {
        // `malformationCauseKey` était écrit dans le brouillon et **personne ne le lisait**. La
        // seule reprise démontrée l'était dans un test qui ré-sérialisait les lignes : une ligne
        // refusée pour colonnes décalées redevenait prête, donc importable avec ses valeurs dans
        // les mauvais champs.
        let document = CSVReader().read(rawCSV(["Titre;Année", "Dune;2021;de trop", "Tenet;2020"]))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)
        let analysis = ImportValidator(schema: .title).analyze(document: document, columns: columns)
        try #require(analysis.refusedRows.count == 1)

        let draft = ImportDraft(
            analysis: analysis, fileName: "f.csv", corrections: [],
            savedAt: Date(timeIntervalSince1970: 0))
        let restored = try #require(draft.restoredAnalysis())

        #expect(restored.refusedRows.count == 1)
        #expect(restored.refusedRows.first?.number == 2)
        #expect(restored.readyRows.count == 1)
    }

    @Test("Une valeur contenant le séparateur survit à la reprise")
    func delimiterInAValueSurvives() throws {
        // Les lignes du brouillon sont **déjà découpées** : la reprise ne repasse pas par le
        // texte, donc il n'y a rien à échapper ni à perdre.
        let document = CSVReader().read(
            csv(header: ["Titre", "Résumé"], rows: [["Dune; ou le désert", "Il dit \"non\" ; puis part"]]))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)
        let analysis = ImportValidator(schema: .title).analyze(document: document, columns: columns)

        let draft = ImportDraft(
            analysis: analysis, fileName: "f.csv", corrections: [],
            savedAt: Date(timeIntervalSince1970: 0))
        let restored = try #require(draft.restoredAnalysis())

        #expect(restored.rows.first?.cell("title") == "Dune; ou le désert")
        #expect(restored.rows.first?.cell("summary") == "Il dit \"non\" ; puis part")
    }

    @Test("La reprise rejoue la correspondance mémorisée et les corrections")
    func restoreReplaysMappingAndCorrections() throws {
        let document = CSVReader().read(csv(header: ["col_a", "col_b"], rows: [["Dune", "20211"]]))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)
            .assigning(fieldKey: "title", toColumnAt: 0)
            .assigning(fieldKey: "year", toColumnAt: 1)
        let analysis = ImportValidator(schema: .title).analyze(document: document, columns: columns)
        try #require(analysis.refusedRows.count == 1)

        let draft = ImportDraft(
            analysis: analysis, fileName: "f.csv",
            corrections: [ImportCorrection(fieldKey: "year", value: "2021")],
            savedAt: Date(timeIntervalSince1970: 0))
        let restored = try #require(draft.restoredAnalysis())

        // Les colonnes affectées à la main reviennent, et en `.certain`.
        #expect(restored.columns.matches.map(\.fieldKey) == ["title", "year"])
        #expect(restored.columns.matches.allSatisfy { $0.quality == .certain })
        #expect(restored.refusedRows.isEmpty, "la correction est rejouée")
    }

    @Test("Un import écrit ce que la reprise a produit")
    func restoredDraftIsImportable() async throws {
        // Le bout du parcours : « Reprendre » puis « Importer ». C'est ce que personne ne pouvait
        // faire depuis la production avant cette passe.
        let fixture = try makeImportFixture()
        let document = CSVReader().read(csv(header: ["Titre", "Année"], rows: [["Dune", "20211"]]))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)
        let analysis = ImportValidator(schema: .title).analyze(document: document, columns: columns)
        let draft = ImportDraft(
            analysis: analysis, fileName: "f.csv",
            corrections: [ImportCorrection(fieldKey: "year", value: "2021")],
            savedAt: Date(timeIntervalSince1970: 0))

        let restored = try #require(draft.restoredAnalysis())
        let result = try await fixture.actor.importRows(
            restored.rows, fileName: draft.fileName, libraryID: fixture.library.id)

        #expect(result.createdTitleIDs.count == 1)
        #expect(try fixture.titles().first?.releaseYear == 2021)
    }
}
