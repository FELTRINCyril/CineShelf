import Foundation
import Testing

@testable import CineShelfCore

// MARK: - V8 · Les transitions du parcours d'import
//
// **Testées hors de toute vue**, parce que ce sont des décisions et non un dessin : peut-on
// avancer, quelles sorties propose-t-on. `ImportFlow` est nonisolé exprès.

@Suite("Parcours d'import")
struct ImportFlowTests {

    private func analysis(ready: Int, refused: Int, missingRequired: [String] = []) -> ImportAnalysis {
        let matches = [
            ColumnMatch(columnIndex: 0, columnName: "titre", fieldKey: "title", quality: .certain),
            ColumnMatch(columnIndex: 1, columnName: "notes_perso", fieldKey: nil, quality: .unrecognized)
        ]
        let columns = ColumnAnalysis(
            entity: .title, matches: matches, missingRequiredFieldKeys: missingRequired)
        // **Des nombres quelconques** : sept prêtes et trois fautives, ni zéro ni égalité — une
        // égalité masquerait une inversion des deux compteurs.
        let layout = ColumnLayout(columns)
        var rows: [ImportRow] = []
        for number in 0..<ready {
            rows.append(
                ImportRow(
                    number: number + 2, rawFields: ["Titre \(number)", "x"], layout: layout))
        }
        for number in 0..<refused {
            rows.append(
                ImportRow(
                    number: ready + number + 2, rawFields: ["", "x"], layout: layout,
                    issues: [
                        ImportIssue(
                            fieldKey: "title",
                            reason: .requiredValueMissing(field: "title"))
                    ]))
        }
        return ImportAnalysis(columns: columns, header: ["titre", "notes_perso"], rows: rows)
    }

    /// **Une colonne non reconnue ne bloque pas**, et le bloc `11d` l'écrit : « elles ne sont
    /// pas une erreur, l'import peut avancer sans y toucher ».
    @Test("Une colonne non reconnue n'empêche pas d'analyser")
    func unrecognizedColumnDoesNotBlock() {
        var flow = ImportFlow()
        flow.columns = analysis(ready: 7, refused: 3).columns
        #expect(flow.canAnalyze)
    }

    /// **Le seul blocage de l'étape 1.** Sans titre, l'aperçu n'annoncerait que « tout en
    /// erreur », ce qui ne renseigne sur rien.
    @Test("Un champ requis sans colonne bloque")
    func missingRequiredFieldBlocks() {
        var flow = ImportFlow()
        flow.columns = analysis(ready: 7, refused: 3, missingRequired: ["title"]).columns
        #expect(flow.canAnalyze == false)
    }

    @Test("Les deux sorties de l'aperçu suivent les comptes")
    func exitsFollowTheCounts() {
        var flow = ImportFlow()
        flow.analysis = analysis(ready: 7, refused: 3)
        #expect(flow.offersReadyOnly)
        #expect(flow.offersDraftAll)
        #expect(flow.readyLabel() == "Importer les 7 lignes prêtes")

        // **Un fichier sans erreur ne propose pas « erreurs en brouillon »** : un bouton qui
        // n'a rien à mettre en brouillon est un bouton qui ne fait rien.
        flow.analysis = analysis(ready: 4, refused: 0)
        #expect(flow.offersReadyOnly)
        #expect(flow.offersDraftAll == false)

        // Et l'inverse : un fichier entièrement fautif ne propose pas d'importer « les prêtes ».
        flow.analysis = analysis(ready: 0, refused: 5)
        #expect(flow.offersReadyOnly == false)
        #expect(flow.offersDraftAll)
    }

    @Test("Le rapport nomme les colonnes ignorées")
    func reportNamesIgnoredColumns() {
        var flow = ImportFlow()
        flow.analysis = analysis(ready: 7, refused: 3)
        // **La contrepartie de l'abandon des champs libres**, exigée par la fiche : une colonne
        // ignorée en silence ferait croire à un import complet.
        #expect(flow.report?.ignoredColumnNames == ["notes_perso"])
    }

    @Test("Le singulier est respecté sur une seule ligne prête")
    func singularLabel() {
        var flow = ImportFlow()
        flow.analysis = analysis(ready: 1, refused: 2)
        #expect(flow.readyLabel() == "Importer la ligne prête")
    }
}
