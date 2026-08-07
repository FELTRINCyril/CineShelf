import CoreGraphics
import SwiftData
import SwiftUI
import Testing

@testable import CineShelf
@testable import CineShelfCore
@testable import DesignSystem

// MARK: - Les sondes des écrans de transfert
//
// **Scindé de `ScreenRenderTests` le 2026-08-07** pour tenir sous la limite de longueur. La
// coupe suit la feature : import et export d'un côté, écrans de catalogue de l'autre. Le décor
// et la mesure de pixels restent dans `ScreenRenderTests`.

@Suite("Rendu des écrans de transfert")
@MainActor
struct TransferRenderTests {

    /// Les deux vues du second jalon de `V8`, et **la paire qui doit se distinguer**.
    ///
    /// Une cause corrigeable dessine un champ de saisie ; une cause de découpage dessine un
    /// message et **pas** de champ. Si les deux rendaient la même chose, la sonde serait aveugle
    /// sur les deux — c'est la leçon de `MediaFill`, où absence et échec donnaient le même aplat.
    @Test("La correction en masse et l'abandon dessinent, et les deux causes se distinguent")
    func correctionAndAbandonDraw() throws {
        let columns = ColumnAnalysis(
            entity: .title,
            matches: [
                ColumnMatch(
                    columnIndex: 0, columnName: "titre", fieldKey: "title", quality: .certain)
            ],
            missingRequiredFieldKeys: [])
        let layout = ColumnLayout(columns)
        // Trois lignes fautives, ni zéro ni une : un compte quelconque.
        let rows = (0..<3).map { index in
            ImportRow(
                number: index + 2, rawFields: [""], layout: layout,
                issues: [
                    ImportIssue(fieldKey: "title", reason: .requiredValueMissing(field: "Titre"))
                ])
        }
        let analysis = ImportAnalysis(columns: columns, header: ["titre"], rows: rows)
        let correctable = try #require(analysis.causeGroups.first)
        // La même cause, privée de sa clé de champ : c'est ce que produit une ligne mal découpée.
        let opaque = ImportCauseGroup(
            causeKey: "malformed:fieldCountMismatch",
            sample: .rowMalformed(.fieldCountMismatch(expected: 14, found: 13)),
            rowNumbers: [4, 9], fieldKey: nil)

        let withField = try #require(
            render(
                ImportCorrectionSheet(
                    cause: correctable, analysis: analysis, schema: .title,
                    onApply: { _ in }, onCancel: {})))
        let withoutField = try #require(
            render(
                ImportCorrectionSheet(
                    cause: opaque, analysis: analysis, schema: .title,
                    onApply: { _ in }, onCancel: {})))
        let abandon = try #require(
            render(
                ImportAbandonSheet(
                    readyCount: 771, refusedCount: 203, correctedCauseCount: 3, totalCauseCount: 6,
                    onChoose: { _ in }, onCancel: {})))

        print(
            "11f corrigeable : \(withField.distinctColours) couleurs · "
                + "non corrigeable : \(withoutField.distinctColours) · "
                + "11g abandon : \(abandon.distinctColours)")

        #expect(!withField.isUniform)
        #expect(!withoutField.isUniform)
        #expect(!abandon.isUniform)
        // La paire : le champ de saisie doit se voir. Un compte de couleurs identique
        // signifierait que la feuille rend la même chose dans les deux cas, donc que rien ne
        // distingue une cause qu'on peut corriger d'une cause qu'on ne peut pas.
        #expect(
            withField.distinctColours != withoutField.distinctColours,
            Comment(
                rawValue: "corrigeable \(withField.distinctColours) "
                    + "== opaque \(withoutField.distinctColours)"))
    }

    /// **`V10` — la corbeille, et la paire qui doit se distinguer.**
    ///
    /// Vide contre peuplée : si les deux rendaient la même chose, la sonde serait aveugle sur
    /// les deux. C'est la leçon de `MediaFill`, et elle vaut ici parce que `TrashService` a
    /// vécu écrit-mais-jamais-lu — une vue qui ne montrerait rien passerait inaperçue.
    @Test("La corbeille dessine, et une corbeille peuplée ne ressemble pas à une vide")
    func trashDraws() throws {
        let stage = try Stage()
        try stage.populate()

        let empty = try #require(render(stage.host(TrashView(onChange: {}))))

        // Trois titres et une personne à la corbeille : ni zéro, ni un.
        let titles = TitleRepository(context: stage.context)
        let fetched = try stage.context.fetch(FetchDescriptor<Title>()).prefix(3)
        for title in fetched { titles.softDelete(title) }
        if let person = try stage.context.fetch(FetchDescriptor<Person>()).first {
            PersonRepository(context: stage.context).softDelete(person)
        }
        try stage.context.save()

        let filled = try #require(render(stage.host(TrashView(onChange: {}))))
        print("Corbeille — vide : \(empty.distinctColours) couleurs · peuplée : \(filled.distinctColours)")

        #expect(!empty.isUniform)
        #expect(!filled.isUniform)
        #expect(
            filled.distinctColours != empty.distinctColours,
            Comment(
                rawValue: "vide \(empty.distinctColours) == peuplée \(filled.distinctColours)"))
    }
}
