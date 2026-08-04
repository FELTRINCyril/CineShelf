import Foundation

// MARK: - Les deux rapports
//
// Ils ne servent pas le même moment ni le même public :
//
//   - `ImportReport` est le **bilan lu à l'écran** (planches 11e et 11j) : ce qui est prêt,
//     ce qui est refusé, par quelle cause, et **quelles colonnes ont été ignorées**.
//   - `rejectedRowsCSV` est le **fichier de reprise** : le fichier d'origine, ses lignes
//     écartées seulement, augmenté d'une colonne d'erreur. Il se rouvre dans un tableur, se
//     corrige et se redépose.
//
// La deuxième est la plus importante des deux et la moins visible : sans elle, « 417 lignes
// en erreur » est une impasse. Avec elle, c'est un aller-retour.

/// Le bilan d'une analyse, en valeurs.
///
/// Une **valeur** et non une chaîne préformatée : l'écran compose ses libellés, et le même
/// bilan alimente l'aperçu (11e) et l'écran de fin (11j). Rendre du texte tout fait aurait
/// obligé à le reformater dans la vue, où rien n'est testable.
public struct ImportReport: Sendable, Hashable {

    /// Le nombre de lignes de données analysées, en-tête exclue.
    public let analyzedCount: Int
    public let readyCount: Int
    public let refusedCount: Int
    /// Les causes, la plus nombreuse d'abord.
    public let causes: [ImportCauseGroup]
    /// Les colonnes du fichier qu'aucun champ ne réclame, **nommées**.
    ///
    /// La fiche l'exige explicitement, et c'est la contrepartie de l'abandon des champs
    /// libres : « une colonne non reconnue ne doit pas disparaître en silence ». Trois
    /// colonnes ignorées sur quatorze, c'est un fichier dont on n'importe que dix champs, et
    /// l'utilisateur doit le lire avant l'appui final, pas le découvrir après.
    public let ignoredColumnNames: [String]
    /// Les champs requis qu'aucune colonne n'alimente. Non vide = l'import ne peut pas partir.
    public let missingRequiredFieldKeys: [String]

    public init(analysis: ImportAnalysis) {
        self.analyzedCount = analysis.rows.count
        self.readyCount = analysis.readyRows.count
        self.refusedCount = analysis.refusedRows.count
        self.causes = analysis.causeGroups
        self.ignoredColumnNames = analysis.ignoredColumnNames
        self.missingRequiredFieldKeys = analysis.columns.missingRequiredFieldKeys
    }

    /// `true` si l'analyse permet d'importer quelque chose.
    public var hasImportableRows: Bool { readyCount > 0 && missingRequiredFieldKeys.isEmpty }
}

// MARK: - Le fichier de reprise

extension ImportReport {

    /// La colonne ajoutée en fin de ligne par le rapport des écartées.
    ///
    /// **Un nom préfixé, et en fin de ligne.** Préfixé pour qu'il ne heurte aucune colonne du
    /// fichier d'origine ; en fin de ligne pour que le fichier redéposé retrouve ses colonnes
    /// aux mêmes places. En tête, il décalerait tout d'un cran, et une correspondance
    /// mémorisée par nom continuerait de fonctionner sans que l'utilisateur comprenne
    /// pourquoi ses colonnes ont bougé.
    ///
    /// Elle sera elle-même « non reconnue » à la relecture, donc ignorée et **nommée** dans
    /// le rapport suivant — ce qui est exactement le comportement voulu : elle n'est pas une
    /// donnée du catalogue.
    public static let errorColumnHeader = "cineshelf_erreur"
}

extension ImportValidator {

    /// Le fichier des lignes écartées, redéposable tel quel.
    ///
    /// - L'en-tête d'origine **à l'identique**, plus `cineshelf_erreur` en fin de ligne.
    /// - Une ligne par ligne refusée, dans l'ordre du fichier, avec ses cellules d'origine —
    ///   colonnes ignorées comprises, car l'utilisateur les a peut-être remplies pour lui.
    /// - Tous les refus de la ligne dans la colonne d'erreur, séparés par « · » : une ligne
    ///   peut cumuler une année hors bornes et un titre vide, et n'en montrer qu'un
    ///   obligerait à deux allers-retours.
    ///
    /// Le BOM et le `CRLF` viennent de `CSVWriter`, donc ce fichier est relu par `CSVReader`
    /// sans que le BOM contamine le nom de la première colonne — c'est vérifié, et c'était la
    /// raison d'être du retrait de BOM à la lecture.
    public func rejectedRowsCSV(from analysis: ImportAnalysis, writer: CSVWriter = CSVWriter()) -> Data {
        let header = analysis.header + [ImportReport.errorColumnHeader]
        let rows = analysis.refusedRows.map { row in
            // La ligne est complétée à la largeur de l'en-tête avant d'ajouter la colonne
            // d'erreur : sur une ligne trop courte — c'est justement un des refus — le
            // message se retrouverait dans une colonne de données.
            let padded =
                row.rawFields.count < analysis.header.count
                ? row.rawFields
                    + Array(repeating: "", count: analysis.header.count - row.rawFields.count)
                : row.rawFields
            return padded + [row.issues.map(\.reason.message).joined(separator: " · ")]
        }
        return writer.data(header: header, rows: rows)
    }
}
