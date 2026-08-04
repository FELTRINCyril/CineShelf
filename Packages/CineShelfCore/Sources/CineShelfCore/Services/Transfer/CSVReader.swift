import Foundation

// MARK: - Lire un CSV sans qu'une ligne fautive emporte les autres
//
// **Pourquoi ce lecteur est écrit à la main plutôt que délégué à `TabularData`.**
// Mesuré le 2026-08-04, sur un fichier de 5 000 lignes dont **une seule** mal formée à la
// 2 501e ligne :
//
//     DataFrame(contentsOfCSVFile:) -> « Misplaced quote at row 2501 »
//                                   -> zéro ligne exploitable
//
// Même verdict pour un nombre de colonnes incohérent, qui est le cas Excel le plus banal.
// Or l'addendum d'import décrit un aperçu de 1 284 lignes dont 771 prêtes et 417 en erreur
// groupées par six causes : ce parcours est **impossible** si le fichier entier est refusé.
// Un export réel contient des cellules mal quotées, et l'utilisateur doit pouvoir importer
// les lignes saines et corriger les autres.
//
// Le prix de ce choix est mesuré aussi : 2 ms pour 5 000 lignes, contre 5 ms pour
// `DataFrame`. Il ne fait ni inférence de type ni colonnes typées, et c'est voulu — voir
// `CSVSchema` pour la conversion, qui appartient à la validation et non à la lecture.

/// Une ligne lue, avec ses champs bruts et l'incident éventuel qui l'a affectée.
public struct CSVRow: Sendable, Hashable {
    /// Le numéro de ligne **dans le fichier**, en comptant l'en-tête, à partir de 1.
    ///
    /// C'est ce numéro que l'utilisateur voit dans son tableur : un aperçu qui dirait
    /// « ligne 412 » en comptant les lignes de données ne désignerait pas la même ligne
    /// que celle qu'il doit corriger.
    public let number: Int
    /// Les champs, dans l'ordre du fichier, guillemets retirés.
    public let fields: [String]
    /// L'incident de découpage, si la ligne en a subi un.
    public let malformation: CSVMalformation?

    public init(number: Int, fields: [String], malformation: CSVMalformation? = nil) {
        self.number = number
        self.fields = fields
        self.malformation = malformation
    }

    public var isMalformed: Bool { malformation != nil }
}

/// Ce qui peut mal tourner au **découpage** d'une ligne.
///
/// Distinct des erreurs de validation : ici, on ne sait pas encore ce que les champs
/// veulent dire. Une valeur non numérique ou un titre vide n'est pas une malformation,
/// c'est une erreur de contenu — voir `ImportIssue`.
public enum CSVMalformation: Sendable, Hashable {
    /// Un champ ouvert par un guillemet ne l'a jamais refermé, et la lecture a dû
    /// reprendre de force à la fin de ligne.
    case unterminatedQuote
    /// La ligne n'a pas le nombre de champs de l'en-tête.
    case fieldCountMismatch(expected: Int, found: Int)
    /// Un champ n'est pas de l'UTF-8 valide.
    ///
    /// Le cas vient d'un fichier enregistré en Windows-1252 ou en Latin-1 — ce qu'un vieux
    /// tableur fait encore. Décoder en remplaçant les octets fautifs par « ? » serait
    /// silencieux : l'utilisateur verrait « Ren? » sans savoir que son fichier est en
    /// cause. La ligne est donc rendue, lisible autant que possible, et **nommée**.
    case invalidEncoding

    public var message: String {
        switch self {
        case .unterminatedQuote:
            "Un guillemet n'est pas fermé. Vérifier les guillemets de cette ligne."
        case .fieldCountMismatch(let expected, let found):
            "\(found) colonnes au lieu de \(expected). Vérifier les points-virgules de cette ligne."
        case .invalidEncoding:
            "Cette ligne n'est pas en UTF-8. Réenregistrer le fichier en UTF-8 depuis le tableur."
        }
    }
}

/// Découpe un CSV, ligne par ligne, sans jamais rejeter le fichier entier.
public struct CSVReader: Sendable {

    /// Au-delà de combien de sauts de ligne un champ quoté est déclaré fautif.
    ///
    /// **Le compromis le plus visible de ce lecteur.** RFC 4180 dit qu'un guillemet ouvert
    /// protège les sauts de ligne — c'est même sa raison d'être, un synopsis sur trois
    /// lignes est légitime. Mais mesuré : sur 5 000 lignes dont la 2 501e ouvre un
    /// guillemet jamais refermé, un lecteur strictement conforme rend **2 502 lignes** au
    /// lieu de 5 001. Le champ resté ouvert avale les 2 500 suivantes, et la moitié du
    /// catalogue disparaît de l'aperçu sans autre signal qu'une ligne fautive.
    ///
    /// Huit lignes : au-delà, on referme le champ de force, on marque la ligne
    /// `unterminatedQuote`, et on reprend à la ligne suivante. Aucun champ du modèle n'a
    /// besoin de plus — `summary` est du texte libre, pas un roman.
    public static let maximumQuotedLines = 8

    public let delimiter: UInt8
    public let hasHeaderRow: Bool

    public init(delimiter: Character = ";", hasHeaderRow: Bool = true) {
        self.delimiter = Array(String(delimiter).utf8).first ?? 0x3B
        self.hasHeaderRow = hasHeaderRow
    }

    /// Le résultat d'une lecture : l'en-tête, les lignes de données, et rien de perdu.
    public struct Document: Sendable, Hashable {
        /// Les noms de colonnes, vides si le fichier n'a pas d'en-tête.
        public let header: [String]
        /// Les lignes de données, dans l'ordre du fichier, fautives comprises.
        public let rows: [CSVRow]

        public init(header: [String], rows: [CSVRow]) {
            self.header = header
            self.rows = rows
        }

        /// Les lignes exploitables : celles dont le découpage n'a rien signalé.
        public var wellFormedRows: [CSVRow] { rows.filter { !$0.isMalformed } }
        /// Les lignes que le découpage a marquées.
        public var malformedRows: [CSVRow] { rows.filter(\.isMalformed) }
    }

    /// Découpe `data`.
    ///
    /// Le BOM éventuel est retiré une seule fois, en tête : sans ça, le nom de la première
    /// colonne serait `"\u{FEFF}title"` et ne correspondrait à aucune correspondance
    /// mémorisée. Le cas est réel — c'est **notre** export qui en écrit un, et le rapport
    /// des lignes écartées est conçu pour être redéposé.
    public func read(_ data: Data) -> Document {
        var lines = split(data)

        guard hasHeaderRow, !lines.isEmpty else {
            return Document(header: [], rows: lines)
        }
        let headerRow = lines.removeFirst()
        let header = headerRow.fields

        // Le nombre de colonnes se vérifie après le découpage, pas pendant : une ligne à
        // deux champs de trop doit rester lisible et signalée, pas faire échouer la
        // lecture — c'est précisément ce que `TabularData` fait et qu'on refuse.
        let checked = lines.map { row -> CSVRow in
            guard row.malformation == nil, row.fields.count != header.count else { return row }
            return CSVRow(
                number: row.number,
                fields: row.fields,
                malformation: .fieldCountMismatch(expected: header.count, found: row.fields.count)
            )
        }
        return Document(header: header, rows: checked)
    }

    // MARK: - Le découpage

    /// Une passe sur les octets, avec son état.
    ///
    /// Extrait en type plutôt que laissé en fonction : la boucle porte sept variables
    /// mutables, et les passer entre fonctions libres les aurait rendues invisibles. Ici
    /// chaque méthode est courte et l'état est nommé une fois.
    private struct LineSplitter {
        let delimiter: UInt8
        var rows: [CSVRow] = []
        var fields: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var quoteOpenedAtLine = 0
        var linesInsideQuote = 0
        var lineNumber = 1
        var hadInvalidEncoding = false

        /// Termine le champ courant.
        ///
        /// `String(bytes:encoding:)` et non `String(decoding:as:)` : le second remplace un
        /// octet invalide par U+FFFD sans rien dire, et « Ren?e » passerait pour une
        /// valeur. Ici l'échec rend une cellule vide **et** marque la ligne : l'utilisateur
        /// voit qu'il y a un problème d'encodage au lieu de lire un nom déformé.
        mutating func endField() {
            if let text = String(bytes: field, encoding: .utf8) {
                fields.append(text)
            } else {
                hadInvalidEncoding = true
                fields.append("")
            }
            field.removeAll(keepingCapacity: true)
        }

        mutating func endRow(malformation: CSVMalformation?) {
            endField()
            // Une malformation de découpage l'emporte sur l'encodage : elle est plus
            // probable et plus actionnable.
            let reported = malformation ?? (hadInvalidEncoding ? .invalidEncoding : nil)
            rows.append(CSVRow(number: lineNumber, fields: fields, malformation: reported))
            fields.removeAll(keepingCapacity: true)
            hadInvalidEncoding = false
            lineNumber += 1
        }

        /// Un octet à l'intérieur d'un champ entre guillemets.
        ///
        /// - Returns: `true` si l'octet suivant a été consommé (guillemet doublé).
        mutating func consumeQuoted(_ byte: UInt8, nextIsQuote: Bool) -> Bool {
            switch byte {
            case 0x22 where nextIsQuote:
                field.append(0x22)  // guillemet doublé : un vrai guillemet
                return true
            case 0x22:
                inQuotes = false
            case 0x0A where linesInsideQuote >= CSVReader.maximumQuotedLines:
                // Resynchronisation : le guillemet ne se refermera pas. On rend la ligne
                // fautive et on reprend proprement à la suivante.
                inQuotes = false
                let resumeAt = quoteOpenedAtLine + linesInsideQuote + 1
                lineNumber = quoteOpenedAtLine
                endRow(malformation: .unterminatedQuote)
                lineNumber = resumeAt
                linesInsideQuote = 0
            case 0x0A:
                linesInsideQuote += 1
                field.append(byte)
            default:
                field.append(byte)
            }
            return false
        }

        /// Un octet hors guillemets.
        mutating func consumeUnquoted(_ byte: UInt8) {
            switch byte {
            case 0x22:
                inQuotes = true
                quoteOpenedAtLine = lineNumber
                linesInsideQuote = 0
            case delimiter:
                endField()
            case 0x0A:
                endRow(malformation: nil)
            case 0x0D:
                break  // CRLF : c'est le LF qui termine la ligne
            default:
                field.append(byte)
            }
        }

        /// Ce qui reste en fin de fichier.
        ///
        /// Un champ resté ouvert est fautif, mais la ligne est rendue : ses valeurs sont
        /// peut-être exploitables, et l'utilisateur doit voir laquelle corriger.
        mutating func finish() {
            if inQuotes {
                endRow(malformation: .unterminatedQuote)
            } else if !field.isEmpty || !fields.isEmpty {
                endRow(malformation: nil)
            }
        }
    }

    private func split(_ data: Data) -> [CSVRow] {
        var splitter = LineSplitter(delimiter: delimiter)
        var index = startIndex(of: data)

        while index < data.endIndex {
            let byte = data[index]
            if splitter.inQuotes {
                let next = data.index(after: index)
                let nextIsQuote = next < data.endIndex && data[next] == 0x22
                if splitter.consumeQuoted(byte, nextIsQuote: nextIsQuote) {
                    index = next
                }
            } else {
                splitter.consumeUnquoted(byte)
            }
            index = data.index(after: index)
        }

        splitter.finish()
        return splitter.rows
    }

    /// Le premier octet du contenu, marque d'ordre des octets exclue.
    private func startIndex(of data: Data) -> Data.Index {
        let start = data.startIndex
        guard data.count >= 3 else { return start }
        let bom = CSVWriter.byteOrderMark
        guard data[start] == bom[0],
            data[data.index(start, offsetBy: 1)] == bom[1],
            data[data.index(start, offsetBy: 2)] == bom[2]
        else { return start }
        return data.index(start, offsetBy: 3)
    }
}
