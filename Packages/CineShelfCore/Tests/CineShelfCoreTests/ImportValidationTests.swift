import Foundation
import Testing

@testable import CineShelfCore

// La validation ligne à ligne, les causes groupées, et les deux rapports.
//
// **Aucun `save()` dans ce fichier, et c'est le sujet.** La frontière `L11a` / `L11b` est
// « rien n'est écrit dans la bibliothèque » : tout ce qui est ici se vérifie sur des valeurs.
// Les tests qui touchent le magasin sont ceux d'`ImportMappingRepository`, plus bas.
//
// Sources des seuils assenés ici : `CatalogBounds`, qui cite les siennes — année 1888-2030
// de l'addendum d'import, note **0-10** de `docs/02` §3.3. Aucun seuil ne vient d'une planche
// de design : la planche 6 décrit cinq étoiles à l'affichage, ce qui est un rendu.

@MainActor
private func analyze(header: [String], rows: [[String]]) -> (ImportValidator, ImportAnalysis) {
    let document = CSVReader().read(csv(header: header, rows: rows))
    let columns = ColumnMatcher(schema: .title).analyze(header: document.header, rows: document.rows)
    let validator = ImportValidator(schema: .title)
    return (validator, validator.analyze(document: document, columns: columns))
}

struct CSVValueParserTests {

    @Test(
        "Les formes de oui et de non qu'un tableur écrit",
        arguments: [
            ("oui", true), ("OUI", true), ("Yes", true), ("VRAI", true), ("1", true),
            ("non", false), ("NO", false), ("faux", false), ("0", false), ("", false)
        ])
    func booleanForms(text: String, expected: Bool) {
        #expect(CSVValueParser.boolean(text) == expected)
    }

    @Test("Une valeur booléenne inconnue n'est pas avalée")
    func unknownBooleanIsNil() {
        // Un `?? false` ici écrirait « non » sur une cellule fautive, et personne ne le
        // verrait jamais.
        #expect(CSVValueParser.boolean("peut-être") == nil)
    }

    @Test("Une date se lit au format AAAA-MM-JJ")
    func isoDateIsRead() throws {
        let date = try #require(CSVValueParser.date("2021-10-20"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        #expect(calendar.component(.day, from: date) == 20)
        #expect(calendar.component(.month, from: date) == 10)
        #expect(calendar.component(.year, from: date) == 2021)
    }

    @Test("Le format jour/mois/année est refusé, pas deviné")
    func slashDateIsRefused() {
        // `02/04/2019` est le 2 avril pour un tableur français et le 4 février pour un
        // américain : choisir, c'est se tromper une fois sur deux sans jamais le signaler.
        #expect(CSVValueParser.date("02/04/2019") == nil)
    }

    @Test("Une date impossible est refusée au lieu d'être reportée")
    func impossibleDateIsRefused() {
        // `Calendar.date(from:)` accepte un 31 février en le reportant sur mars : une faute
        // de frappe deviendrait une date valide mais fausse.
        #expect(CSVValueParser.date("2021-02-31") == nil)
        #expect(CSVValueParser.date("2021-13-01") == nil)
    }

    @Test("L'export et la lecture se répondent sur les dates")
    func exportRoundTripsThroughParser() async throws {
        // Le fuseau courant des deux côtés : en UTC d'un côté seulement, exporter puis
        // réimporter décalerait les dates d'un jour. Le bug a déjà été attrapé une fois sur
        // la colonne « Année » de l'export.
        let original = try #require(CSVValueParser.date("2021-10-20"))
        let written = await MainActor.run { CSVExporter.dateStyle.format(original) }
        #expect(written == "2021-10-20")
        #expect(CSVValueParser.date(written) == original)
    }

    @Test("Une année se lit en chiffres ou dans une date complète")
    func yearAcceptsBothForms() {
        #expect(CSVValueParser.year("2021") == 2021)
        // La fiche du champ le dit : « Une date complète est acceptée. »
        #expect(CSVValueParser.year("2021-10-20") == 2021)
        // `20211` est un nombre : il est lu, puis refusé pour ses bornes. Exiger quatre
        // chiffres ici le faisait refuser comme « attendu en chiffres », un message faux
        // devant une cellule qui n'en contient que.
        #expect(CSVValueParser.year("20211") == 20211)
        #expect(CSVValueParser.year("2h30") == nil)
    }

    @Test("Un nombre décimal se lit à la virgule comme au point")
    func decimalAcceptsCommaAndDot() {
        // L'export écrit un point, mais un utilisateur qui saisit une note dans Excel en
        // français tape une virgule.
        #expect(CSVValueParser.decimal("8.4") == 8.4)
        #expect(CSVValueParser.decimal("8,4") == 8.4)
        #expect(CSVValueParser.decimal("2h30") == nil)
    }

    @Test("Un vocabulaire fermé accepte le rawValue et son libellé français")
    func enumeratedAcceptsSynonyms() {
        let kinds = TitleKind.allCases.map(\.rawValue)
        #expect(CSVValueParser.enumerated("movie", allowedValues: kinds) == "movie")
        #expect(CSVValueParser.enumerated("Film", allowedValues: kinds) == "movie")
        #expect(CSVValueParser.enumerated("Série", allowedValues: kinds) == "series")
        #expect(CSVValueParser.enumerated("bluray25", allowedValues: kinds) == nil)
    }
}

@MainActor
struct ImportValidatorTests {

    @Test("Une ligne complète et propre est prête")
    func cleanRowIsReady() {
        let (_, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes", "Note · sur 10"],
            rows: [["Dune", "2021", "155", "8,4"]])

        #expect(analysis.readyRows.count == 1)
        #expect(analysis.refusedRows.isEmpty)
    }

    @Test("Un titre vide est refusé : c'est le seul champ requis")
    func emptyRequiredFieldIsRefused() throws {
        let (_, analysis) = analyze(header: ["Titre", "Année"], rows: [["", "2021"]])
        let issue = try #require(analysis.refusedRows.first?.issues.first)

        #expect(issue.fieldKey == "title")
        #expect(issue.reason == .requiredValueMissing(field: "Titre"))
        // Le message dit quoi faire, pas ce qui est faux — règle 11a de l'addendum.
        #expect(issue.reason.message.contains("requis"))
    }

    @Test("Une année absente n'est PAS une erreur, contrairement à la planche 11e")
    func missingYearIsNotAnError() {
        // La planche compte 214 lignes en erreur pour « Année absente », avec le message
        // « L'année est requise pour créer un titre ». Or `docs/02` §3.3 rend `releaseDate`
        // optionnel : un titre sans année est un titre valide, et refuser la ligne
        // écarterait des données que le modèle accepte.
        //
        // C'est le motif que `CLAUDE.md` nomme : un document de design qui paraît contraindre
        // le modèle est une erreur de catégorie, à signaler et non à appliquer. Écart inscrit
        // dans `docs/PROMPTS.md`.
        let (_, analysis) = analyze(header: ["Titre", "Année"], rows: [["Tenet", ""]])

        #expect(analysis.readyRows.count == 1)
    }

    @Test("Une année hors bornes est refusée avec ses bornes dans le message")
    func yearOutOfRangeIsRefused() throws {
        let (_, analysis) = analyze(header: ["Titre", "Année"], rows: [["Nope", "20211"]])
        let issue = try #require(analysis.refusedRows.first?.issues.first)

        // Source des bornes : `CatalogBounds.years`, qui cite l'addendum d'import.
        #expect(
            issue.reason
                == .valueOutOfRange(field: "Année", expected: "entre 1888 et 2030", found: "20211"))
    }

    @Test("Une note de 8,4 est acceptée : l'échelle est sur 10")
    func ratingScaleIsOutOfTen() {
        // `docs/02` §3.3. La planche 6 du design montre cinq étoiles pleines, ce qui décrit
        // un **rendu** (`TitleFormat.fiveStarRating` divise par deux). Borner à 0…5 ici
        // refuserait la moitié de l'échelle à l'import — c'était le bug de `L10`.
        let (_, analysis) = analyze(
            header: ["Titre", "Note · sur 10"],
            rows: [["Dune", "8,4"], ["Tenet", "10"], ["Nope", "0"]])

        #expect(analysis.refusedRows.isEmpty)
    }

    @Test("Une note au-delà de 10 est refusée")
    func ratingAboveTenIsRefused() {
        let (_, analysis) = analyze(header: ["Titre", "Note · sur 10"], rows: [["Dune", "11"]])
        #expect(analysis.refusedRows.count == 1)
    }

    @Test("Une durée non numérique est refusée avec la valeur trouvée")
    func nonNumericRuntimeIsRefused() throws {
        // La cause « Durée non numérique · format 2h30 » de la planche 11e.
        let (_, analysis) = analyze(
            header: ["Titre", "Durée · minutes"], rows: [["Oppenheimer", "2h30"]])
        let issue = try #require(analysis.refusedRows.first?.issues.first)

        #expect(issue.reason == .valueNotANumber(field: "Durée · minutes", found: "2h30"))
    }

    @Test("Une valeur hors vocabulaire est refusée, et le vocabulaire est dit")
    func unknownEnumeratedValueIsRefused() throws {
        let (_, analysis) = analyze(header: ["Titre", "Type"], rows: [["Dune", "bluray25"]])
        let issue = try #require(analysis.refusedRows.first?.issues.first)

        #expect(issue.reason.causeKey == "notAllowed:Type")
        #expect(issue.reason.message.contains("movie"))
    }

    @Test("Une cellule multivaleur dit laquelle de ses valeurs est inconnue")
    func multiValueNamesTheOffendingValue() throws {
        let document = CSVReader().read(
            csv(header: ["Nom", "Rôles"], rows: [["Villeneuve", "realisation/plombier"]]))
        let columns = ColumnMatcher(schema: .person).analyze(header: document.header)
        let analysis = ImportValidator(schema: .person)
            .analyze(document: document, columns: columns)
        let issue = try #require(analysis.refusedRows.first?.issues.first)

        // Refuser la cellule en bloc obligerait à deviner laquelle des deux corriger.
        #expect(issue.reason.message.contains("plombier"))
        #expect(issue.reason.message.contains("realisation") == false)
    }

    @Test("Une ligne mal découpée ne produit qu'un refus, pas dix")
    func malformedRowProducesOneIssue() throws {
        // Ses champs sont décalés : valider cellule par cellule ferait plusieurs refus dans
        // plusieurs causes différentes pour une faute de frappe, et l'aperçu deviendrait
        // illisible.
        //
        // **La fixture est choisie pour que les cellules décalées soient elles-mêmes
        // fautives** : un point-virgule de trop après le titre décale tout, donc « Année »
        // reçoit un titre et « Titre » se retrouve vide. Une première version de ce test
        // utilisait une ligne dont les cellules restaient valides après décalage — la preuve
        // d'échec a montré qu'il passait même sans le court-circuit, donc qu'il ne couvrait
        // pas la règle qu'il prétendait vérifier.
        let (_, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes"], rows: [["", "Dune", "2h30", "155"]])
        let row = try #require(analysis.refusedRows.first)

        #expect(row.issues.count == 1)
        #expect(row.issues[0].reason.causeKey == "malformed:fieldCountMismatch")
        #expect(row.issues[0].fieldKey == nil)
    }
}

@MainActor
struct ImportCauseGroupingTests {

    @Test("Deux durées fautives différentes forment une seule cause")
    func sameCauseGroupsAcrossValues() throws {
        // La phrase qui commande tout : « On ne corrige pas 417 lignes, on corrige six
        // causes. » Inclure la valeur trouvée dans la clé donnerait autant de groupes que de
        // lignes.
        let (_, analysis) = analyze(
            header: ["Titre", "Durée · minutes"],
            rows: [["Oppenheimer", "2h30"], ["The Northman", "2h17"], ["Dune", "155"]])
        let group = try #require(analysis.causeGroups.first)

        #expect(analysis.causeGroups.count == 1)
        #expect(group.count == 2)
        #expect(group.label == "Durée · minutes non numérique")
        #expect(group.rowNumbers == [2, 3])
    }

    @Test("Les causes sortent par effectif décroissant, et à égalité par clé")
    func causesAreSortedDeterministically() {
        let (_, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes"],
            rows: [
                ["Dune", "20211", "155"],
                ["Tenet", "20200", "150"],
                ["Nope", "2022", "2h10"]
            ])

        // Un tri instable rendrait deux exécutions du même fichier incomparables.
        #expect(analysis.causeGroups.map(\.count) == [2, 1])
        #expect(analysis.causeGroups.map(\.causeKey) == ["outOfRange:Année", "notNumber:Durée · minutes"])
    }

    @Test("Une ligne à deux refus compte dans deux causes, une fois dans chacune")
    func rowWithTwoIssuesCountsOncePerCause() {
        let (_, analysis) = analyze(
            header: ["Titre", "Année", "Durée · minutes"], rows: [["", "20211", "155"]])

        #expect(analysis.refusedRows.count == 1)
        #expect(analysis.causeGroups.count == 2)
        #expect(analysis.causeGroups.allSatisfy { $0.count == 1 })
    }
}

@MainActor
struct ImportCorrectionTests {

    @Test("Une correction de masse revalide sans reparser le fichier")
    func massCorrectionRevalidates() {
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"],
            rows: [["Tenet", "20211"], ["Dune", "20211"], ["Nope", "2022"]])
        #expect(analysis.refusedRows.count == 2)

        // Aucun `CSVReader` ici : les `ImportRow` déjà en mémoire sont retravaillées. Sur
        // 1 284 lignes, corriger 214 causes ne doit pas relire le fichier.
        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "2020"), to: analysis)

        #expect(corrected.refusedRows.isEmpty)
        #expect(corrected.readyRows.count == 3)
    }

    @Test("Une correction ne touche que les lignes visées")
    func correctionTargetsOnlyItsRows() throws {
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"], rows: [["Tenet", "20211"], ["Dune", "20211"]])
        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "2020", rowNumbers: [2]), to: analysis)

        #expect(corrected.readyRows.count == 1)
        #expect(corrected.refusedRows.count == 1)
        #expect(try #require(corrected.refusedRows.first).number == 3)
    }

    @Test("L'aperçu de l'effet montre l'avant et l'après, sans rien appliquer")
    func previewShowsBeforeAndAfter() throws {
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"], rows: [["Tenet", "20211"], ["Dune", "20211"]])
        let preview = validator.preview(
            ImportCorrection(fieldKey: "year", value: "2020"), on: analysis, limit: 1)

        #expect(preview.count == 1)
        #expect(preview[0].before == "20211")
        #expect(preview[0].after == "2020")
        // L'analyse d'origine est intacte : c'est une valeur, personne ne l'a mutée.
        #expect(analysis.refusedRows.count == 2)
    }

    @Test("Corriger une cellule ne recolle pas une ligne mal découpée")
    func correctionDoesNotHealMalformation() {
        // La malformation appartient au découpage : les colonnes sont décalées, et remplir
        // une cellule n'y change rien. La prétendre réparée écrirait les mauvaises valeurs
        // dans les bons champs.
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"], rows: [["Dune", "2021", "de trop"]])
        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "2021"), to: analysis, )

        #expect(corrected.refusedRows.count == 1)
    }

    @Test("Une correction peut en découvrir une autre")
    func correctionCanRevealAnotherIssue() throws {
        let (validator, analysis) = analyze(header: ["Titre", "Année"], rows: [["Dune", ""]])
        #expect(analysis.readyRows.count == 1)

        let corrected = validator.applying(
            ImportCorrection(fieldKey: "year", value: "20211", rowNumbers: [2]), to: analysis)

        // La revalidation est complète et non incrémentale : une correction qui introduit une
        // faute doit la faire apparaître, sinon l'aperçu mentirait après trois corrections.
        #expect(corrected.refusedRows.count == 1)
    }
}

@MainActor
struct ImportReportTests {

    @Test("Le rapport nomme les colonnes ignorées")
    func reportNamesIgnoredColumns() {
        // Exigence explicite de la fiche, contrepartie de l'abandon des champs libres : « une
        // colonne non reconnue ne doit pas disparaître en silence ».
        let (_, analysis) = analyze(
            header: ["Titre", "bought_at", "notes_perso"], rows: [["Dune", "Fnac", "steelbook"]])
        let report = ImportReport(analysis: analysis)

        #expect(report.ignoredColumnNames == ["bought_at", "notes_perso"])
        #expect(report.analyzedCount == 1)
        #expect(report.readyCount == 1)
        #expect(report.hasImportableRows)
    }

    @Test("Un champ requis sans colonne rend le rapport non importable")
    func missingRequiredFieldBlocksImport() {
        let (_, analysis) = analyze(header: ["Année"], rows: [["2021"]])
        let report = ImportReport(analysis: analysis)

        #expect(report.missingRequiredFieldKeys == ["title"])
        #expect(report.hasImportableRows == false)
    }

    @Test("Le rapport des écartées reprend le fichier d'origine et ajoute la cause")
    func rejectedRowsReportKeepsOriginalShape() throws {
        let (validator, analysis) = analyze(
            header: ["Titre", "Année", "notes_perso"],
            rows: [["Dune", "2021", "steelbook"], ["Tenet", "20211", "prêté"]])
        let data = validator.rejectedRowsCSV(from: analysis)
        let reread = CSVReader().read(data)

        // L'en-tête d'origine à l'identique, la colonne d'erreur **en fin** de ligne : en
        // tête, elle décalerait toutes les colonnes du fichier redéposé.
        #expect(reread.header == ["Titre", "Année", "notes_perso", ImportReport.errorColumnHeader])
        #expect(reread.rows.count == 1)

        let row = try #require(reread.rows.first)
        // Les colonnes ignorées sont conservées : l'utilisateur les a peut-être remplies pour
        // lui, et le fichier doit lui revenir entier.
        #expect(Array(row.fields.prefix(3)) == ["Tenet", "20211", "prêté"])
        #expect(row.fields[3].contains("entre 1888 et 2030"))
    }

    @Test("Le rapport des écartées se redépose et se relit sans le BOM en travers")
    func rejectedRowsReportIsReimportable() {
        // C'était la raison d'être du retrait de BOM à la lecture : notre propre écrivain en
        // écrit un, et ce fichier est fait pour être redéposé.
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"], rows: [["Tenet", "20211"]])
        let data = validator.rejectedRowsCSV(from: analysis)

        #expect(data.starts(with: CSVWriter.byteOrderMark))

        let document = CSVReader().read(data)
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)

        #expect(columns.matches[0].fieldKey == "title")
        // La colonne d'erreur n'est pas une donnée du catalogue : elle est ignorée, et nommée.
        #expect(columns.ignoredColumnNames == [ImportReport.errorColumnHeader])
    }

    @Test("Une ligne trop courte ne voit pas le message d'erreur atterrir dans ses données")
    func shortRowIsPaddedBeforeErrorColumn() throws {
        // Octets bruts : `CSVWriter` complète une ligne courte à la largeur de l'en-tête, donc il
        // est incapable de produire le cas que ce test exerce.
        let document = CSVReader().read(rawCSV(["Titre;Année", "Dune"]))
        let columns = ColumnMatcher(schema: .title)
            .analyze(header: document.header, rows: document.rows)
        let validator = ImportValidator(schema: .title)
        let analysis = validator.analyze(document: document, columns: columns)
        try #require(analysis.refusedRows.count == 1)

        let reread = CSVReader().read(validator.rejectedRowsCSV(from: analysis))
        let row = try #require(reread.rows.first)

        #expect(row.fields.count == 3)
        #expect(row.fields[1].isEmpty)
        #expect(row.fields[2].isEmpty == false)
    }

    @Test("Les cellules cumulées d'une ligne à deux refus tiennent dans une colonne")
    func multipleIssuesShareOneCell() throws {
        let (validator, analysis) = analyze(
            header: ["Titre", "Année"], rows: [["", "20211"]])
        let reread = CSVReader().read(validator.rejectedRowsCSV(from: analysis))
        let row = try #require(reread.rows.first)

        // Deux refus séparés par « · » : n'en montrer qu'un obligerait à deux allers-retours.
        #expect(row.fields[2].contains("requis"))
        #expect(row.fields[2].contains("entre 1888 et 2030"))
    }
}
