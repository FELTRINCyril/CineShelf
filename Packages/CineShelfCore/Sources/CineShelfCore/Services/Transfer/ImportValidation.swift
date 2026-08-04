import Foundation

// MARK: - Valider les lignes, et grouper les causes
//
// L'étape 2 de l'import (planche 11e). La phrase qui commande tout ce fichier :
// « On ne corrige pas 417 lignes, on corrige six causes. »
//
// Conséquence de forme : une cause est un **cas d'énumération**, jamais un message libre.
// Deux durées fautives — `2h30` et `2h17` — sont la **même** cause, donc la valeur trouvée
// ne fait pas partie de la clé de regroupement, seulement du message. C'est exactement le
// patron de `BulkRefusalReason`, et pour la même raison : un `String` ne se groupe pas.
//
// **Aucune écriture, ici non plus.** Une `ImportRow` est une valeur ; corriger en masse
// produit une nouvelle analyse, pas une mutation du magasin. « Rien n'est écrit dans la
// bibliothèque avant l'appui final » est la garantie du parcours, et c'est aussi ce qui rend
// tout ce fichier testable sans `save()`.

/// Pourquoi une ligne est refusée.
///
/// Un cas par cause. Les valeurs associées servent au message, pas au regroupement — voir
/// `causeKey`.
public enum ImportRefusalReason: Sendable, Hashable {
    /// Un champ requis est vide sur cette ligne.
    case requiredValueMissing(field: String)
    /// La cellule n'est pas un nombre là où un nombre est attendu.
    case valueNotANumber(field: String, found: String)
    /// La cellule n'est pas une date au format attendu.
    case valueNotADate(field: String, found: String)
    /// La valeur est hors des bornes du catalogue.
    case valueOutOfRange(field: String, expected: String, found: String)
    /// La valeur n'appartient pas au vocabulaire du champ.
    case valueNotAllowed(field: String, found: String, expected: String)
    /// Le découpage de la ligne a échoué — voir `CSVMalformation`.
    ///
    /// Une malformation est une cause d'erreur **de plein droit** et non un cas à part : elle
    /// se groupe et se compte avec les autres, sinon l'aperçu annoncerait « 417 en erreur »
    /// sans que les lignes illisibles y figurent.
    case rowMalformed(CSVMalformation)

    /// Le message montré à l'utilisateur. Dit quoi faire, pas ce qui est faux — règle 11a de
    /// l'addendum, « Année attendue entre 1888 et 2030 », pas « Année invalide ».
    public var message: String {
        switch self {
        case .requiredValueMissing(let field):
            "\(field) est requis. Renseigner cette colonne ou écarter la ligne."
        case .valueNotANumber(let field, let found):
            "\(field) attendu en chiffres. Trouvé « \(found) »."
        case .valueNotADate(let field, let found):
            "\(field) attendu au format AAAA-MM-JJ. Trouvé « \(found) »."
        case .valueOutOfRange(let field, let expected, let found):
            "\(field) attendu \(expected). Trouvé « \(found) »."
        case .valueNotAllowed(let field, let found, let expected):
            "\(field) : « \(found) » n'est pas une valeur connue. Attendu \(expected)."
        case .rowMalformed(let malformation):
            malformation.message
        }
    }

    /// Le libellé de la cause, sans la valeur trouvée. C'est ce qu'un groupe affiche.
    public var causeLabel: String {
        switch self {
        case .requiredValueMissing(let field): "\(field) absent"
        case .valueNotANumber(let field, _): "\(field) non numérique"
        case .valueNotADate(let field, _): "\(field) au mauvais format"
        case .valueOutOfRange(let field, _, _): "\(field) hors bornes"
        case .valueNotAllowed(let field, _, _): "\(field) : valeur inconnue"
        case .rowMalformed: "Ligne illisible"
        }
    }

    /// La clé de regroupement : la nature du refus et le champ, **sans** la valeur trouvée.
    ///
    /// C'est ce qui fait que 54 durées écrites `2h30`, `2h17`, `1h58` forment **une** cause
    /// et non 54. Inclure la valeur donnerait autant de groupes que de lignes, et l'écran
    /// qui promet « six causes » en afficherait des centaines.
    public var causeKey: String {
        switch self {
        case .requiredValueMissing(let field): "missing:\(field)"
        case .valueNotANumber(let field, _): "notNumber:\(field)"
        case .valueNotADate(let field, _): "notDate:\(field)"
        case .valueOutOfRange(let field, _, _): "outOfRange:\(field)"
        case .valueNotAllowed(let field, _, _): "notAllowed:\(field)"
        case .rowMalformed(let malformation): "malformed:\(malformation.causeKey)"
        }
    }
}

extension CSVMalformation {
    /// La nature de la malformation, sans ses nombres.
    ///
    /// Deux lignes à 13 et 15 colonnes au lieu de 14 relèvent du même problème de fichier :
    /// les compter séparément ferait deux causes d'une seule.
    var causeKey: String {
        switch self {
        case .unterminatedQuote: "unterminatedQuote"
        case .fieldCountMismatch: "fieldCountMismatch"
        case .invalidEncoding: "invalidEncoding"
        }
    }
}

/// Un refus, et où il se produit.
public struct ImportIssue: Sendable, Hashable {
    /// La clé du champ concerné, `nil` si le refus porte sur la ligne entière.
    public let fieldKey: String?
    public let reason: ImportRefusalReason

    public init(fieldKey: String?, reason: ImportRefusalReason) {
        self.fieldKey = fieldKey
        self.reason = reason
    }
}

/// Une cause, et les lignes qu'elle touche.
public struct ImportCauseGroup: Sendable, Hashable, Identifiable {
    public let causeKey: String
    /// Un refus représentatif : il porte le libellé et un exemple de valeur.
    public let sample: ImportRefusalReason
    /// Les numéros de ligne concernés, en ordre croissant.
    public let rowNumbers: [Int]

    public var id: String { causeKey }
    public var count: Int { rowNumbers.count }
    public var label: String { sample.causeLabel }

    public init(causeKey: String, sample: ImportRefusalReason, rowNumbers: [Int]) {
        self.causeKey = causeKey
        self.sample = sample
        self.rowNumbers = rowNumbers
    }
}

// MARK: - L'analyse d'un fichier

/// Le résultat de l'analyse : des lignes, des causes, et rien d'écrit.
public struct ImportAnalysis: Sendable, Hashable {

    /// La correspondance des colonnes qui a produit cette analyse.
    public let columns: ColumnAnalysis
    /// L'en-tête du fichier, tel quel. Nécessaire au rapport redéposable.
    public let header: [String]
    public let rows: [ImportRow]
    /// L'incident qui a frappé la ligne d'en-tête, s'il y en a un.
    ///
    /// Porté jusqu'ici parce qu'un en-tête fautif ne se rattrape pas ligne à ligne : c'est le
    /// **fichier** qui n'est pas lisible, et le rapport doit le dire au lieu de réclamer une
    /// colonne que le fichier contient.
    public let headerMalformation: CSVMalformation?

    public init(
        columns: ColumnAnalysis,
        header: [String],
        rows: [ImportRow],
        headerMalformation: CSVMalformation? = nil
    ) {
        self.columns = columns
        self.header = header
        self.rows = rows
        self.headerMalformation = headerMalformation
    }

    public var readyRows: [ImportRow] { rows.filter(\.isReady) }
    public var refusedRows: [ImportRow] { rows.filter { !$0.isReady } }
    /// Les colonnes qu'aucun champ ne réclame, nommées.
    public var ignoredColumnNames: [String] { columns.ignoredColumnNames }

    /// Les causes, la plus nombreuse d'abord.
    ///
    /// À effectif égal, l'ordre est celui de la clé : un tri instable ferait sauter les
    /// groupes d'un affichage à l'autre, et le rapport de deux exécutions du même fichier ne
    /// serait pas comparable.
    public var causeGroups: [ImportCauseGroup] {
        var samples: [String: ImportRefusalReason] = [:]
        var lines: [String: [Int]] = [:]
        for row in rows {
            for issue in row.issues {
                let key = issue.reason.causeKey
                if samples[key] == nil { samples[key] = issue.reason }
                // Une ligne qui cumule deux refus de la **même** cause ne la compte qu'une
                // fois : « 214 lignes » doit être un compte de lignes, pas de refus.
                if lines[key]?.last != row.number { lines[key, default: []].append(row.number) }
            }
        }
        return samples.map { key, sample in
            ImportCauseGroup(causeKey: key, sample: sample, rowNumbers: lines[key] ?? [])
        }
        .sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.causeKey < rhs.causeKey : lhs.count > rhs.count
        }
    }
}

// MARK: - Le validateur

/// Valide les lignes d'un fichier contre un schéma, ligne à ligne.
public struct ImportValidator: Sendable {

    public let schema: CSVSchema

    public init(schema: CSVSchema) {
        self.schema = schema
    }

    /// Analyse un document déjà découpé, selon une correspondance de colonnes.
    ///
    /// La disposition est extraite **une fois** et partagée par toutes les lignes : aucune
    /// n'a de cellules à elle, chacune projette la sienne depuis ses octets.
    public func analyze(document: CSVReader.Document, columns: ColumnAnalysis) -> ImportAnalysis {
        let layout = ColumnLayout(columns)
        let rows = document.rows.map { row in
            let base = ImportRow(number: row.number, rawFields: row.fields, layout: layout)
            return base.settingIssues(issues(for: base, malformation: row.malformation))
        }
        return ImportAnalysis(
            columns: columns,
            header: document.header,
            rows: rows,
            headerMalformation: document.headerMalformation)
    }

    /// Les refus d'une ligne.
    ///
    /// **Une ligne mal découpée n'est pas validée cellule par cellule.** Ses champs sont
    /// décalés, donc chaque cellule serait fautive et une seule ligne produirait dix refus
    /// dans dix causes différentes — l'aperçu deviendrait illisible pour une faute de
    /// frappe. La malformation est le refus, et elle suffit.
    func issues(for row: ImportRow, malformation: CSVMalformation?) -> [ImportIssue] {
        if let malformation {
            return [ImportIssue(fieldKey: nil, reason: .rowMalformed(malformation))]
        }
        return schema.fields.compactMap { field in
            issue(for: field, value: row.cell(field.key) ?? "")
        }
    }

    /// Le refus d'une cellule, s'il y en a un.
    ///
    /// **Une cellule vide n'est un refus que si le champ est requis.** C'est le modèle qui
    /// en décide, pas l'aperçu : `docs/02` §3.3 rend `releaseDate`, `runtimeMinutes` et
    /// `rating` optionnels, donc un titre sans année est un titre valide. Voir l'écart noté
    /// dans `docs/PROMPTS.md` : la planche 11e compte 214 lignes en erreur pour « année
    /// absente », ce qui décrit un modèle où l'année est requise — elle ne l'est pas.
    func issue(for field: CSVField, value: String) -> ImportIssue? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            guard field.isRequiredForImport else { return nil }
            return ImportIssue(
                fieldKey: field.key, reason: .requiredValueMissing(field: field.header))
        }
        return formatIssue(for: field, text: text)
    }

    private func formatIssue(for field: CSVField, text: String) -> ImportIssue? {
        switch field.shape {
        case .text:
            return nil
        case .multiValue, .enumerated, .boolean:
            return vocabularyIssue(for: field, text: text)
        case .date, .year, .integer, .decimal:
            return numberOrDateIssue(for: field, text: text)
        }
    }

    /// Les formes dont la faute est une valeur inconnue.
    private func vocabularyIssue(for field: CSVField, text: String) -> ImportIssue? {
        switch field.shape {
        case .multiValue:
            let values = CSVSchema.splitMultiValue(text)
            // **Une cellule qui ne contient que des séparateurs est vide, et elle passait.**
            // `splitMultiValue` retire les valeurs vides, donc `Rôles = "/"` rendait une
            // liste vide, et la recherche d'une valeur inconnue ne trouvait rien : la ligne
            // était déclarée prête avec zéro rôle. `BulkEditor` refuse justement une liste de
            // rôles vide, au motif que le modèle suppose au moins un rôle — deux écrivains,
            // deux règles. La cellule n'est pas vide pour l'utilisateur, elle est fautive.
            guard !values.isEmpty else {
                return refusal(
                    field,
                    .valueNotAllowed(
                        field: field.header,
                        found: text,
                        expected: "au moins une valeur, séparée par « \(CSVSchema.multiValueSeparator) »"))
            }
            // Le vocabulaire s'applique à chaque valeur de la cellule : « acteur/plombier »
            // doit dire laquelle des deux est inconnue, pas refuser la cellule en bloc.
            guard !field.allowedValues.isEmpty else { return nil }
            guard
                let unknown = values.first(where: {
                    CSVValueParser.enumerated($0, allowedValues: field.allowedValues) == nil
                })
            else { return nil }
            return refusal(
                field,
                .valueNotAllowed(
                    field: field.header, found: unknown, expected: expectation(of: field)))

        case .enumerated:
            guard CSVValueParser.enumerated(text, allowedValues: field.allowedValues) == nil else {
                return nil
            }
            return refusal(
                field,
                .valueNotAllowed(
                    field: field.header, found: text, expected: expectation(of: field)))

        case .boolean:
            guard CSVValueParser.boolean(text) == nil else { return nil }
            return refusal(
                field,
                .valueNotAllowed(
                    field: field.header, found: text, expected: "oui ou non"))

        case .text, .date, .year, .integer, .decimal:
            return nil
        }
    }

    /// Les formes dont la faute est un nombre ou une date : illisible, ou hors bornes.
    private func numberOrDateIssue(for field: CSVField, text: String) -> ImportIssue? {
        switch field.shape {
        case .date:
            guard CSVValueParser.date(text) == nil else { return nil }
            return refusal(field, .valueNotADate(field: field.header, found: text))

        case .year:
            guard let year = CSVValueParser.year(text) else {
                return refusal(field, .valueNotANumber(field: field.header, found: text))
            }
            return rangeIssue(field, value: Double(year), found: text)

        case .integer:
            guard let number = CSVValueParser.integer(text) else {
                return refusal(field, .valueNotANumber(field: field.header, found: text))
            }
            return rangeIssue(field, value: Double(number), found: text)

        case .decimal:
            guard let number = CSVValueParser.decimal(text) else {
                return refusal(field, .valueNotANumber(field: field.header, found: text))
            }
            return rangeIssue(field, value: number, found: text)

        case .text, .multiValue, .enumerated, .boolean:
            return nil
        }
    }

    private func rangeIssue(_ field: CSVField, value: Double, found: String) -> ImportIssue? {
        guard let range = field.range, !range.contains(value) else { return nil }
        return refusal(
            field,
            .valueOutOfRange(
                field: field.header,
                expected:
                    "entre \(CSVExportFormat.bound(range.lowerBound)) et \(CSVExportFormat.bound(range.upperBound))",
                found: found))
    }

    private func refusal(_ field: CSVField, _ reason: ImportRefusalReason) -> ImportIssue {
        ImportIssue(fieldKey: field.key, reason: reason)
    }

    /// Ce qu'un champ à vocabulaire fermé accepte, en clair.
    private func expectation(of field: CSVField) -> String {
        field.allowedValues.joined(separator: ", ")
    }
}

/// Les nombres écrits dans un message d'erreur.
///
/// Hors de `CSVExporter`, qui est `@MainActor` parce qu'il touche des `@Model` : la
/// validation ne l'est pas, et n'a pas à le devenir pour formater une borne.
enum CSVExportFormat {
    /// Une borne, sans décimale inutile : « entre 0 et 10 », pas « entre 0.0 et 10.0 ».
    static func bound(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
