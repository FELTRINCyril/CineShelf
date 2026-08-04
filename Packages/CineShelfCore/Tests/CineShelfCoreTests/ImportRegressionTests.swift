import Foundation
import Testing

@testable import CineShelfCore

// Le montage est celui d'`ImportValidationTests` : un document découpé, une correspondance,
// un validateur. Répété ici plutôt que partagé, parce que ces tests portent sur des entrées
// que l'autre fichier n'atteignait pas — et c'est justement ce qui leur donne leur valeur.
@MainActor
private func analyze(header: [String], rows: [[String]]) -> (ImportValidator, ImportAnalysis) {
    let document = CSVReader().read(csv(header: header, rows: rows))
    let columns = ColumnMatcher(schema: .title).analyze(header: document.header, rows: document.rows)
    let validator = ImportValidator(schema: .title)
    return (validator, validator.analyze(document: document, columns: columns))
}

// Les défauts de validation et de rapport trouvés par la revue du 2026-08-04.
@MainActor
struct ImportRegressionTests {

    @Test("Une correction de masse repart dans le fichier de reprise")
    func correctionFlowsIntoTheRejectedRowsReport() throws {
        // **Le défaut le plus coûteux de la passe.** `settingCell` ne mettait à jour que
        // `cells`, alors que le rapport est construit depuis `rawFields` : une ligne corrigée
        // sur l'année mais encore refusée pour sa durée repartait avec l'**ancienne** année.
        // Scénario complet : corriger 214 années, exporter les écartées pour finir les durées
        // au tableur, redéposer — les 214 corrections avaient disparu, sans un mot.
        let (validator, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes"], rows: [["Dune", "20211", "2h30"]])
        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "2021"), to: analysis)
        let reread = CSVReader().read(validator.rejectedRowsCSV(from: corrected))
        let row = try #require(reread.rows.first)

        #expect(corrected.refusedRows.count == 1, "la durée reste fautive, donc la ligne repart")
        #expect(row.fields[1] == "2021", "l'année corrigée doit repartir corrigée")
    }

    @Test("Une valeur saisie pour un champ sans colonne ne s'invente pas dans le fichier")
    func correctionWithoutColumnStaysOutOfTheReport() throws {
        // C'est « Saisir une année pour toutes » de la planche 11f sur un fichier qui n'a pas
        // de colonne d'année : la valeur vit dans l'analyse, mais le fichier ne l'a jamais
        // portée et n'a donc pas à la porter au retour. Décision explicite, pas un effet de
        // bord — l'ajouter décalerait les colonnes du fichier redéposé.
        let (validator, analysis) = analyze(header: ["Titre"], rows: [[""]])
        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "2020", rowNumbers: [2]), to: analysis)
        let row = try #require(corrected.rows.first)

        #expect(row.cells["year"] == "2020")
        #expect(row.rawFields == [""], "le fichier d'origine reste tel quel")
    }

    @Test("Une cellule multivaleur réduite à son séparateur est refusée")
    func separatorOnlyMultiValueIsRefused() throws {
        // `splitMultiValue` retire les valeurs vides, donc `Rôles = "/"` rendait une liste
        // vide et la ligne passait **prête**, avec zéro rôle. `BulkEditor` refuse justement
        // une liste de rôles vide, au motif que le modèle suppose au moins un rôle : deux
        // écrivains, deux règles, et c'est l'import qui écrivait la personne sans rôle.
        let document = CSVReader().read(csv(header: ["Nom", "Rôles"], rows: [["Villeneuve", "/"]]))
        let columns = ColumnMatcher(schema: .person).analyze(header: document.header)
        let analysis = ImportValidator(schema: .person)
            .analyze(document: document, columns: columns)

        #expect(analysis.readyRows.isEmpty)
        let issue = try #require(analysis.refusedRows.first?.issues.first)
        #expect(issue.reason.causeKey == "notAllowed:Rôles")
    }

    @Test("Un en-tête illisible bloque l'import et dit la vraie cause")
    func malformedHeaderBlocksTheImport() throws {
        let data = CSVWriter.byteOrderMark + Data("\"Titre;Année\r\nDune;2021\r\n".utf8)
        let document = CSVReader().read(data)
        let columns = ColumnMatcher(schema: .title).analyze(header: document.header)
        let analysis = ImportValidator(schema: .title)
            .analyze(document: document, columns: columns)
        let report = ImportReport(analysis: analysis)

        #expect(report.hasImportableRows == false)
        #expect(try #require(report.headerMalformation).isUnterminatedQuote)
    }

    @Test("Un nombre à espaces intérieures est refusé, pas recollé")
    func interiorSpacesAreNotSwallowed() {
        // La première version retirait **toutes** les espaces : « 1 2 3 » rendait 123, une
        // valeur inventée là où il fallait un refus nommé.
        #expect(CSVValueParser.decimal("1 2 3") == nil)
        #expect(CSVValueParser.decimal(" 8,4 ") == 8.4, "les espaces de bord restent tolérées")
    }
}

// `cells` dérive de `rawFields` : la divergence n'est plus corrigée, elle est irreprésentable.
//
// Le correctif du 2026-08-04 écrivait les deux stockages. Il traitait le symptôme : la
// structure restait deux choses qu'aucune règle n'obligeait à s'accorder — l'initialiseur
// public acceptait n'importe quelle paire, et l'appelant calculait lui-même l'index de
// colonne. Ces tests couvrent la projection elle-même, sur le patron des deux branches de
// `#Predicate` : quand un invariant tient par construction, on vérifie quand même qu'il tient.
@MainActor
struct ImportRowProjectionTests {

    private let layout = ColumnLayout(indexByField: ["title": 0, "year": 1])

    @Test("Une cellule se lit dans la ligne, pas dans une copie")
    func cellIsProjectedFromRawFields() {
        let row = ImportRow(number: 2, rawFields: ["Dune", "2021"], layout: layout)

        #expect(row.cell("title") == "Dune")
        #expect(row.cell("year") == "2021")
        #expect(row.cells == ["title": "Dune", "year": "2021"])
    }

    @Test("Corriger un champ à colonne écrit dans la ligne, et nulle part ailleurs")
    func correctingAMappedFieldWritesTheFile() {
        let row = ImportRow(number: 2, rawFields: ["Dune", "20211"], layout: layout)
        let corrected = row.settingCell("2021", forKey: "year")

        #expect(corrected.rawFields == ["Dune", "2021"])
        #expect(corrected.cell("year") == "2021")
        // Pas de double écriture : un champ est dans la disposition **ou** dans les valeurs
        // décidées, jamais dans les deux. C'est cette exclusion qui remplace l'accord à
        // maintenir entre deux stockages.
        #expect(corrected.overrides.isEmpty)
    }

    @Test("Corriger un champ sans colonne ne touche pas la ligne du fichier")
    func correctingAnUnmappedFieldLeavesTheFileAlone() {
        let row = ImportRow(number: 2, rawFields: ["Dune"], layout: ColumnLayout(indexByField: ["title": 0]))
        let corrected = row.settingCell("2020", forKey: "year")

        #expect(corrected.rawFields == ["Dune"], "le fichier n'a jamais porté cette valeur")
        #expect(corrected.overrides == ["year": "2020"])
        #expect(corrected.cell("year") == "2020")
    }

    @Test("Le fichier de reprise et les cellules s'accordent après n'importe quelle correction")
    func reportAndCellsAgreeAfterEveryCorrection() throws {
        // L'assertion d'accord, celle que réclamait la structure d'avant. Elle est désormais
        // une conséquence de la projection, et elle reste écrite : c'est elle qui échouerait si
        // quelqu'un remettait un stockage parallèle.
        let (validator, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes"],
            rows: [["Dune", "20211", "2h30"], ["Tenet", "20200", "1h50"]])

        var corrected = analysis
        for (key, value) in [("year", "2021"), ("runtime", "155")] {
            corrected = validator.applying(ImportCorrection(fieldKey: key, value: value), to: corrected)
        }
        let reread = CSVReader().read(validator.rejectedRowsCSV(from: corrected))

        // Toutes les lignes sont passées : la vérification porte donc sur l'analyse corrigée.
        #expect(corrected.refusedRows.isEmpty)
        #expect(reread.rows.isEmpty)

        for row in corrected.rows {
            for key in row.layout.mappedFieldKeys {
                let index = try #require(row.layout.index(of: key))
                #expect(row.cell(key) == row.rawFields[index], "\(key) désaccordé ligne \(row.number)")
            }
        }
    }

    @Test("Une ligne trop courte rend nil au lieu de déborder")
    func shortRowDoesNotOverflow() {
        // Le cas est un refus légitime — `fieldCountMismatch` — donc la ligne existe et se lit.
        let row = ImportRow(number: 2, rawFields: ["Dune"], layout: layout)

        #expect(row.cell("year") == nil)
        #expect(row.cells == ["title": "Dune"])
    }

    @Test("Corriger un champ dont la colonne manque à cette ligne ne l'invente pas")
    func correctingABeyondEndColumnIsANoOp() {
        // La disposition dit « colonne 1 » mais la ligne n'en a qu'une : écrire y ferait
        // déborder l'index, et compléter la ligne en douce inventerait une colonne que le
        // fichier n'a pas. La ligne reste telle quelle, et son refus de découpage subsiste.
        let row = ImportRow(number: 2, rawFields: ["Dune"], layout: layout)
        #expect(row.settingCell("2021", forKey: "year") == row)
    }
}
