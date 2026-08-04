import Foundation

// MARK: - Corriger en masse, sans reparser

/// Une correction appliquée à un lot de lignes.
///
/// La planche 11f : « une cause, une décision, un aperçu de l'effet avant de l'appliquer ».
/// `Codable` parce que le **brouillon d'import la persiste** : reprendre un import rejoue ses
/// corrections dans l'ordre, ce qui redonne exactement l'état où l'utilisateur s'est arrêté. La
/// forme est donc un format de fichier, et c'est `ImportDraft.currentVersion` qui la protège.
public struct ImportCorrection: Codable, Sendable, Hashable {
    /// Le champ corrigé.
    public let fieldKey: String
    /// La valeur à écrire dans la cellule.
    public let value: String
    /// Les lignes visées. `nil` = toutes les lignes en erreur sur ce champ.
    public let rowNumbers: Set<Int>?

    public init(fieldKey: String, value: String, rowNumbers: Set<Int>? = nil) {
        self.fieldKey = fieldKey
        self.value = value
        self.rowNumbers = rowNumbers
    }
}

extension ImportValidator {

    /// La même analyse, une correction appliquée et les lignes touchées revalidées.
    ///
    /// **Sans reparser le fichier**, comme la fiche l'exige : les octets ont été découpés une
    /// fois, et une correction de masse sur 214 lignes ne doit pas relire 1 284 lignes. Seule
    /// une `ImportRow` déjà en mémoire est retravaillée, et seules les lignes visées.
    ///
    /// Rien n'est muté : une nouvelle analyse est rendue. C'est ce qui permet à l'écran de
    /// montrer l'effet **avant** de l'appliquer — il compare deux valeurs, il n'annule pas
    /// une écriture.
    public func applying(_ correction: ImportCorrection, to analysis: ImportAnalysis) -> ImportAnalysis {
        let targets =
            correction.rowNumbers
            ?? Set(
                analysis.refusedRows
                    .filter { $0.issues.contains { $0.fieldKey == correction.fieldKey } }
                    .map(\.number)
            )
        let rows = analysis.rows.map { row -> ImportRow in
            guard targets.contains(row.number) else { return row }
            // Aucun index n'est passé ici : la ligne consulte sa propre disposition. C'est ce
            // qui rend impossible d'écrire la correction dans la mauvaise colonne — la version
            // précédente calculait l'index à cet endroit, et rien ne vérifiait qu'il fût bon.
            let corrected = row.settingCell(correction.value, forKey: correction.fieldKey)
            // La malformation n'est pas rejouée : elle appartient au découpage, et corriger
            // une cellule ne recolle pas une ligne dont les colonnes sont décalées.
            let malformation = row.issues.compactMap { issue -> CSVMalformation? in
                guard case .rowMalformed(let malformation) = issue.reason else { return nil }
                return malformation
            }.first
            return corrected.settingIssues(issues(for: corrected, malformation: malformation))
        }
        return ImportAnalysis(
            columns: analysis.columns,
            header: analysis.header,
            rows: rows,
            headerMalformation: analysis.headerMalformation)
    }

    /// L'effet d'une correction avant de l'appliquer : les lignes touchées, avant et après.
    ///
    /// Trois lignes par défaut, comme « Aperçu de l'effet · trois premières lignes
    /// concernées » de la planche 11f.
    public func preview(
        _ correction: ImportCorrection,
        on analysis: ImportAnalysis,
        limit: Int = 3
    ) -> [ImportCorrectionPreview] {
        let after = applying(correction, to: analysis)
        let changed = zip(analysis.rows, after.rows)
            .filter { $0.cell(correction.fieldKey) != $1.cell(correction.fieldKey) }
        return changed.prefix(limit).map {
            ImportCorrectionPreview(
                number: $0.number,
                before: $0.cell(correction.fieldKey) ?? "",
                after: $1.cell(correction.fieldKey) ?? "")
        }
    }
}

/// Une ligne que la correction changerait, avant et après.
public struct ImportCorrectionPreview: Sendable, Hashable, Identifiable {
    public let number: Int
    public let before: String
    public let after: String

    public var id: Int { number }

    public init(number: Int, before: String, after: String) {
        self.number = number
        self.before = before
        self.after = after
    }
}
