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
    /// reprendre de force.
    ///
    /// **`absorbedLines` n'est pas décoratif : c'est la perte, et elle doit être dite.**
    /// La première version de ce cas n'avait aucune valeur associée, et le rapport annonçait
    /// alors « 7 lignes analysées » sur un fichier de 15 — huit titres valides avalés par un
    /// guillemet, sans un mot nulle part. Un lecteur qui refuse `TabularData` parce qu'il
    /// perd tout le fichier ne peut pas en perdre huit lignes en silence.
    case unterminatedQuote(absorbedLines: Int)
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
        case .unterminatedQuote(let absorbed) where absorbed > 0:
            """
            Un guillemet n'est pas fermé, et \(absorbed) ligne\(absorbed > 1 ? "s" : "") \
            suivante\(absorbed > 1 ? "s ont" : " a") été absorbée\(absorbed > 1 ? "s" : "") \
            avec celle-ci. Vérifier les guillemets à partir de cette ligne.
            """
        case .unterminatedQuote:
            "Un guillemet n'est pas fermé. Vérifier les guillemets de cette ligne."
        case .fieldCountMismatch(let expected, let found):
            "\(found) colonnes au lieu de \(expected). Vérifier les points-virgules de cette ligne."
        case .invalidEncoding:
            "Cette ligne n'est pas en UTF-8. Réenregistrer le fichier en UTF-8 depuis le tableur."
        }
    }

    /// `true` si la ligne a été coupée par un guillemet non fermé, quel qu'en soit le coût.
    ///
    /// Sert aux assertions et aux filtres : comparer à `.unterminatedQuote(absorbedLines: 0)`
    /// obligerait chaque appelant à connaître un compte qui ne l'intéresse pas.
    public var isUnterminatedQuote: Bool {
        if case .unterminatedQuote = self { return true }
        return false
    }
}

/// Découpe un CSV, ligne par ligne, sans jamais rejeter le fichier entier.
public struct CSVReader: Sendable {

    /// Au-delà de combien de sauts de ligne un champ quoté est déclaré fautif — **quand il
    /// reste un doute**.
    ///
    /// RFC 4180 dit qu'un guillemet ouvert protège les sauts de ligne : c'est sa raison
    /// d'être, un synopsis sur trois lignes est légitime. Mais mesuré : sur 5 000 lignes dont
    /// la 2 501e ouvre un guillemet jamais refermé, un lecteur strictement conforme rend
    /// **2 502 lignes** au lieu de 5 001. La moitié du catalogue disparaît de l'aperçu.
    ///
    /// **Ce seuil ne décide plus seul, et c'est ce qui a résolu le compromis.** Un budget de
    /// lignes oppose deux besoins qu'il ne sait pas distinguer : un synopsis de douze lignes
    /// est légitime, un guillemet jamais refermé doit coûter le moins possible. Un seuil bas
    /// déclare le synopsis fautif ; un seuil haut fait payer 32 lignes au fichier corrompu.
    /// Mesuré dans les deux sens, sur les mêmes fixtures.
    ///
    /// La sortie est de **regarder** au lieu de parier : au premier saut de ligne dans un
    /// champ quoté, `closingQuoteExists` cherche en avant un guillemet fermant. S'il n'y en a
    /// pas, le champ ne se refermera jamais — ce n'est plus une hypothèse — et la ligne est
    /// close **immédiatement**, sans rien absorber. S'il y en a un, le champ est du texte
    /// multiligne légitime et ce seuil sert alors de garde-fou : il borne le cas tordu où un
    /// guillemet parasite trouve un fermant appartenant à une *autre* cellule, plus loin dans
    /// le fichier.
    public static let maximumQuotedLines = 32

    /// Jusqu'où chercher le guillemet fermant.
    ///
    /// Le coût de la recherche est payé **une fois par champ quoté multiligne**, ce qui est
    /// rare, et jamais sur un fichier de cellules courtes. Le plafond évite qu'un fichier
    /// entièrement quoté dégénère en coût quadratique. 64 Kio : aucune cellule de ce modèle
    /// n'approche cette taille, et au-delà la ligne est de toute façon signalée — jamais
    /// avalée en silence.
    static let closingQuoteSearchLimit = 64 * 1024

    public let delimiter: UInt8
    public let hasHeaderRow: Bool

    /// - Precondition: `delimiter` est un caractère ASCII. Le découpage travaille sur des
    ///   octets, donc un délimiteur multi-octets couperait au milieu d'une séquence UTF-8 et
    ///   produirait des cellules invalides. Le refuser tôt vaut mieux que le découvrir sur un
    ///   fichier.
    public init(delimiter: Character = ";", hasHeaderRow: Bool = true) {
        precondition(delimiter.isASCII, "Le délimiteur doit être un caractère ASCII.")
        self.delimiter = Array(String(delimiter).utf8).first ?? 0x3B
        self.hasHeaderRow = hasHeaderRow
    }

    /// Le résultat d'une lecture : l'en-tête, les lignes de données, et rien de perdu.
    public struct Document: Sendable, Hashable {
        /// Les noms de colonnes, vides si le fichier n'a pas d'en-tête.
        public let header: [String]
        /// Les lignes de données, dans l'ordre du fichier, fautives comprises.
        public let rows: [CSVRow]
        /// L'incident qui a frappé la **ligne d'en-tête**, s'il y en a un.
        ///
        /// **Il était jeté, et c'est le fichier entier qu'on perdait.** `read` prenait les
        /// champs de la première ligne et abandonnait sa malformation. Sur un en-tête à
        /// guillemet non fermé, le résultat était donc : `header` = tout le fichier, `rows`
        /// vide, et un rapport annonçant « champ requis `title` sans colonne » devant un
        /// fichier qui *contient* une colonne titre. Le lecteur promet « rien de perdu » ;
        /// c'est ce champ qui rend la promesse tenable pour la première ligne aussi.
        public let headerMalformation: CSVMalformation?

        public init(header: [String], rows: [CSVRow], headerMalformation: CSVMalformation? = nil) {
            self.header = header
            self.rows = rows
            self.headerMalformation = headerMalformation
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
        let headerMalformation = headerRow.malformation

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
        return Document(header: header, rows: checked, headerMalformation: headerMalformation)
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
        /// `true` entre la refermeture forcée d'un champ quoté et la fin de sa ligne
        /// physique. Voir `consumeRecovering`.
        var recovering = false

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
        /// - Returns: `true` si l'octet suivant a été consommé (guillemet doublé, ou `CR` de
        ///   fin de ligne).
        mutating func consumeQuoted(_ byte: UInt8, next: UInt8?, closingQuoteAhead: Bool) -> Bool {
            switch byte {
            case 0x22 where next == 0x22:
                field.append(0x22)  // guillemet doublé : un vrai guillemet
                return true
            case 0x22:
                inQuotes = false
            case 0x0D:
                // **Un `CRLF` dans une cellule devient un `LF`.** Sans cette normalisation,
                // le même synopsis donne deux valeurs de `summary` selon que le tableur a
                // écrit `\n` ou `\r\n` — deux fichiers que l'utilisateur tient pour
                // identiques, et rien ne montre la différence. Hors guillemets, le `CR` est
                // déjà traité comme une fin de ligne : les deux côtés s'accordent.
                appendLineBreakInsideQuote(closingQuoteAhead: closingQuoteAhead)
                return next == 0x0A
            case 0x0A:
                appendLineBreakInsideQuote(closingQuoteAhead: closingQuoteAhead)
            default:
                field.append(byte)
            }
            return false
        }

        /// Un saut de ligne à l'intérieur d'un champ quoté, ou la refermeture forcée.
        ///
        /// - Parameter closingQuoteAhead: `false` s'il est **établi** qu'aucun guillemet
        ///   fermant ne suit. La ligne est alors close tout de suite, sans rien absorber :
        ///   c'est ce qui fait qu'un guillemet parasite coûte une ligne et non huit.
        private mutating func appendLineBreakInsideQuote(closingQuoteAhead: Bool) {
            guard closingQuoteAhead else {
                // **Pas de phase de reprise ici, et c'était une ligne de trop.** L'octet
                // courant *est* le saut de ligne : la ligne fautive s'arrête donc exactement
                // là, il n'y a rien à jeter derrière. Y entrer quand même faisait consommer la
                // ligne **suivante** en entier — 48 lignes utilisables au lieu de 49 sur la
                // fixture de 50. Les guillemets reprennent leur sens dès la ligne d'après.
                inQuotes = false
                endRow(malformation: .unterminatedQuote(absorbedLines: linesInsideQuote))
                linesInsideQuote = 0
                return
            }
            guard linesInsideQuote >= CSVReader.maximumQuotedLines else {
                linesInsideQuote += 1
                field.append(0x0A)
                return
            }
            // Le garde-fou de dernier recours : un guillemet fermant existe quelque part,
            // mais il appartient probablement à une autre cellule. La ligne est rendue
            // fautive avec le **compte** de ce qu'elle a absorbé, et la phase de reprise jette
            // ce qui reste du champ jusqu'au prochain saut de ligne — ce texte est déjà
            // déclaré perdu, et le relire ferait rouvrir un champ sur son guillemet fermant.
            inQuotes = false
            recovering = true
            let absorbed = linesInsideQuote
            let resumeAt = quoteOpenedAtLine + linesInsideQuote + 1
            lineNumber = quoteOpenedAtLine
            endRow(malformation: .unterminatedQuote(absorbedLines: absorbed))
            lineNumber = resumeAt
            linesInsideQuote = 0
        }

        /// Les octets jetés entre la refermeture forcée et la fin de la ligne physique.
        ///
        /// **Sans cette phase, la refermeture forcée corrompait la fin du fichier.** L'état
        /// de quote était remis à `false` mais la lecture reprenait *au milieu* du champ
        /// d'origine : le guillemet fermant, quand il arrivait, était relu comme un
        /// guillemet **ouvrant** et avalait tout jusqu'à la fin du fichier. Mesuré sur dix
        /// lignes dont un synopsis de douze lignes correctement quoté : trois lignes
        /// utilisables, quatre fautives, trois évaporées, et les paragraphes du synopsis
        /// remontés en fausses lignes de données.
        ///
        /// Ici les guillemets n'ont plus de sens jusqu'au prochain saut de ligne : ce qui
        /// reste du champ est du texte déjà déclaré perdu, et le rouvrir n'a aucun intérêt.
        ///
        /// - Returns: `true` si l'octet suivant a été consommé.
        mutating func consumeRecovering(_ byte: UInt8, next: UInt8?) -> Bool {
            switch byte {
            case 0x0A:
                recovering = false
            case 0x0D:
                recovering = false
                return next == 0x0A
            default:
                break
            }
            return false
        }

        /// Un octet hors guillemets.
        ///
        /// - Returns: `true` si l'octet suivant a été consommé (`LF` d'un `CRLF`).
        mutating func consumeUnquoted(_ byte: UInt8, next: UInt8?) -> Bool {
            switch byte {
            // **Un guillemet n'ouvre un champ qu'en début de champ**, comme RFC 4180 le dit.
            // La première version ouvrait sur n'importe quel guillemet : `Le mur de 6" de
            // haut` déclenchait alors une resynchronisation, et coûtait huit titres valides
            // sans que rien ne le signale. Un pouce, une taille d'écran ou une citation dans
            // un titre suffisaient.
            case 0x22 where field.isEmpty:
                inQuotes = true
                quoteOpenedAtLine = lineNumber
                linesInsideQuote = 0
            case delimiter:
                endField()
            case 0x0A:
                endRow(malformation: nil)
            case 0x0D:
                // `CRLF` : le `LF` est consommé avec le `CR`. Un `CR` **seul** termine la
                // ligne — c'est le format « CSV (Macintosh) », que la première version
                // jetait octet par octet : le fichier entier devenait un en-tête, zéro
                // ligne, et le rapport réclamait une colonne titre que le fichier
                // contenait.
                endRow(malformation: nil)
                return next == 0x0A
            default:
                field.append(byte)
            }
            return false
        }

        /// Ce qui reste en fin de fichier.
        ///
        /// Un champ resté ouvert est fautif, mais la ligne est rendue : ses valeurs sont
        /// peut-être exploitables, et l'utilisateur doit voir laquelle corriger.
        mutating func finish() {
            if inQuotes {
                endRow(malformation: .unterminatedQuote(absorbedLines: linesInsideQuote))
            } else if !recovering, !field.isEmpty || !fields.isEmpty {
                endRow(malformation: nil)
            }
        }
    }

    private func split(_ data: Data) -> [CSVRow] {
        var splitter = LineSplitter(delimiter: delimiter)
        var index = startIndex(of: data)

        while index < data.endIndex {
            let byte = data[index]
            let nextIndex = data.index(after: index)
            let next = nextIndex < data.endIndex ? data[nextIndex] : nil

            let consumedNext: Bool
            if splitter.recovering {
                consumedNext = splitter.consumeRecovering(byte, next: next)
            } else if splitter.inQuotes {
                // Le regard en avant n'est calculé que sur un saut de ligne **dans** un champ
                // quoté : c'est le seul moment où la réponse change une décision, et c'est
                // rare. Une cellule courte ne le paie jamais.
                let isLineBreak = byte == 0x0A || byte == 0x0D
                let ahead =
                    isLineBreak
                    ? Self.closingQuoteExists(in: data, from: nextIndex, delimiter: delimiter)
                    : true
                consumedNext = splitter.consumeQuoted(byte, next: next, closingQuoteAhead: ahead)
            } else {
                consumedNext = splitter.consumeUnquoted(byte, next: next)
            }
            if consumedNext { index = nextIndex }

            index = data.index(after: index)
        }

        splitter.finish()
        return splitter.rows
    }

    /// Existe-t-il, en avant, un guillemet qui **ferme** un champ ?
    ///
    /// Un guillemet fermant est suivi du délimiteur, d'une fin de ligne, ou de la fin du
    /// fichier. Un guillemet doublé — `""` — n'en est pas un : il est sauté par paires, sinon
    /// un synopsis contenant une citation se ferait passer pour terminé et le champ se
    /// couperait au milieu.
    ///
    /// Répondre `true` par défaut au bout du plafond est le choix prudent : on continue de
    /// lire le champ comme légitime, et le garde-fou de `maximumQuotedLines` reprend la main.
    /// Répondre `false` couperait un champ long mais valide.
    static func closingQuoteExists(in data: Data, from start: Data.Index, delimiter: UInt8) -> Bool {
        var index = start
        var scanned = 0
        while index < data.endIndex {
            // **Le plafond rend `true`, la fin du fichier rend `false`, et confondre les deux
            // annulait toute la mécanique.** La première version sortait de la boucle sur les
            // deux conditions puis rendait `true` : arriver au bout du fichier sans trouver de
            // guillemet fermant — c'est-à-dire le cas même qu'on cherche à détecter — se
            // lisait donc « champ légitime », et rien ne se resynchronisait jamais. Mesuré sur
            // la fixture de 50 lignes : 25 lignes utilisables au lieu de 49, sur un fichier
            // qui ne contient qu'**un seul** guillemet.
            guard scanned < closingQuoteSearchLimit else { return true }
            defer {
                index = data.index(after: index)
                scanned += 1
            }
            guard data[index] == 0x22 else { continue }

            let next = data.index(after: index)
            guard next < data.endIndex else { return true }  // guillemet en fin de fichier
            switch data[next] {
            case 0x22:
                // Guillemet doublé : ce n'est pas une fermeture. Sauter le second, sinon la
                // paire serait relue et le premier compté comme fermant.
                index = next
                scanned += 1
            case delimiter, 0x0A, 0x0D:
                return true
            default:
                continue
            }
        }
        return false
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
