import Foundation
import Testing

@testable import CineShelfCore

// Le format CSV, dans les deux sens.
//
// Les fixtures sont **construites dans les tests**, pas déposées en ressources : les
// octets exacts — marque d'ordre, `CRLF`, guillemets doublés — restent lisibles à côté de
// l'assertion au lieu d'être cachés dans un binaire que personne ne rouvre. C'est aussi ce
// qui permet de tester un fichier volontairement corrompu sans l'expliquer en commentaire.

struct CSVWriterTests {

    private let writer = CSVWriter()

    @Test("La marque d'ordre des octets est en tête, et c'est ce qui sauve les accents")
    func byteOrderMarkComesFirst() {
        let data = writer.data(header: ["titre"], rows: [["Éléphant"]])
        #expect(data.starts(with: CSVWriter.byteOrderMark))
        // Sans la marque, Excel lit le fichier en Windows-1252 et « Éléphant » devient
        // « Ãlephant ». Mesuré : `DataFrame.csvRepresentation` ne l'écrit pas.
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test("Le séparateur est le point-virgule, et les lignes finissent en CRLF")
    func delimiterAndNewline() throws {
        let data = writer.data(header: ["a", "b"], rows: [["1", "2"]])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "a;b\r\n1;2\r\n")
    }

    @Test(
        "Les champs qui l'exigent sont mis entre guillemets",
        arguments: [
            ("simple", "simple"),
            ("avec;séparateur", "\"avec;séparateur\""),
            ("avec\"guillemet", "\"avec\"\"guillemet\""),
            ("avec\nsaut", "\"avec\nsaut\""),
            (" espace de bord", "\" espace de bord\""),
            ("espace de bord ", "\"espace de bord \""),
            ("", "")
        ]
    )
    func quotingRules(field: String, expected: String) {
        // Le guillemet interne est **doublé**, pas échappé par antislash : c'est la forme
        // RFC 4180, et la seule qu'Excel relit.
        #expect(writer.escaped(field) == expected)
    }

    @Test("Une ligne plus courte que l'en-tête est complétée")
    func shortRowsArePadded() throws {
        let data = writer.data(header: ["a", "b", "c"], rows: [["1"]])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "a;b;c\r\n1;;\r\n")
    }

    @Test("Une ligne plus longue n'est pas tronquée")
    func longRowsAreNotTruncated() throws {
        // Perdre une valeur en silence est pire qu'un fichier bancal, qui se voit.
        let data = writer.data(header: ["a"], rows: [["1", "2"]])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "a\r\n1;2\r\n")
    }

    @Test("Un gabarit n'a que son en-tête, et garde la marque d'ordre")
    func templateHasHeaderOnly() throws {
        let data = writer.template(header: ["titre", "année"])
        #expect(data.starts(with: CSVWriter.byteOrderMark))
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "titre;année\r\n")
    }
}

struct CSVReaderTests {

    private let reader = CSVReader()
    private let writer = CSVWriter()

    /// Construit un fichier octet par octet, marque d'ordre comprise.
    private func file(_ lines: [String], bom: Bool = true, newline: String = "\r\n") -> Data {
        var data = bom ? CSVWriter.byteOrderMark : Data()
        data.append(Data(lines.joined(separator: newline).utf8))
        data.append(Data(newline.utf8))
        return data
    }

    @Test("Un fichier simple se lit, en-tête séparé des données")
    func simpleFile() {
        let document = reader.read(file(["titre;année", "A;1970", "B;1980"]))
        #expect(document.header == ["titre", "année"])
        #expect(document.rows.count == 2)
        #expect(document.rows[0].fields == ["A", "1970"])
        // Le numéro est celui du tableur : l'en-tête est la ligne 1.
        #expect(document.rows[0].number == 2)
        #expect(document.rows[1].number == 3)
    }

    @Test("La marque d'ordre ne contamine pas le nom de la première colonne")
    func byteOrderMarkIsStripped() {
        let document = reader.read(file(["titre;année", "A;1970"]))
        #expect(document.header.first == "titre")
        // Sans le retrait, ce serait "\u{FEFF}titre" — et aucune correspondance mémorisée
        // ne reconnaîtrait plus son propre en-tête. Le cas est réel : c'est notre export
        // qui écrit ce BOM, et le rapport des écartées est fait pour être redéposé.
        #expect(document.header.first?.unicodeScalars.first?.value != 0xFEFF)
    }

    @Test("Un fichier sans marque d'ordre se lit aussi")
    func fileWithoutByteOrderMark() {
        let document = reader.read(file(["titre;année", "A;1970"], bom: false))
        #expect(document.header == ["titre", "année"])
        #expect(document.rows.count == 1)
    }

    @Test("Les fins de ligne LF seules sont acceptées")
    func lineFeedOnly() {
        // Un fichier venu d'un outil Unix n'a pas de CR. Le refuser serait gratuit.
        let document = reader.read(file(["a;b", "1;2"], newline: "\n"))
        #expect(document.rows.count == 1)
        #expect(document.rows[0].fields == ["1", "2"])
    }

    @Test("Un point-virgule dans un champ quoté n'est pas un séparateur")
    func quotedDelimiter() {
        let document = reader.read(file(["a;b", "\"un;deux\";trois"]))
        #expect(document.rows[0].fields == ["un;deux", "trois"])
        #expect(document.rows[0].isMalformed == false)
    }

    @Test("Un guillemet doublé rend un guillemet")
    func doubledQuote() {
        let document = reader.read(file(["a", "\"il a dit \"\"non\"\"\""]))
        #expect(document.rows[0].fields == ["il a dit \"non\""])
    }

    @Test("Un champ quoté multiligne légitime est préservé")
    func legitimateMultilineField() {
        let document = reader.read(file(["a;b", "\"ligne 1\nligne 2\nligne 3\";x"]))
        #expect(document.rows.count == 1)
        #expect(document.rows[0].fields == ["ligne 1\nligne 2\nligne 3", "x"])
        #expect(document.rows[0].isMalformed == false)
    }

    // MARK: Le cas qui a décidé de tout

    @Test("Un guillemet non fermé n'emporte pas les lignes suivantes")
    func unterminatedQuoteDoesNotSwallowTheFile() {
        // C'est LA raison pour laquelle ce lecteur existe. `TabularData`, sur ce fichier,
        // rend « Misplaced quote at row 2501 » et **zéro** ligne exploitable.
        var lines = ["titre;année"]
        for index in 0..<50 {
            lines.append(index == 25 ? "\"cassé;1970" : "Titre \(index);1970")
        }
        let document = reader.read(file(lines))

        let usable = document.wellFormedRows
        #expect(usable.count >= 40, "Les lignes saines doivent survivre : \(usable.count)")
        #expect(document.malformedRows.isEmpty == false)
        #expect(
            document.malformedRows.contains { $0.malformation == .unterminatedQuote },
            "La ligne fautive doit être nommée, pas silencieuse"
        )
        // Et les lignes d'après doivent être relues pour de vrai, pas juste comptées.
        #expect(usable.contains { $0.fields.first == "Titre 49" })
    }

    @Test("La resynchronisation s'active au-delà de huit lignes englobées")
    func resynchronisationThreshold() {
        // En dessous du seuil, le champ multiligne reste légitime : c'est un synopsis.
        let short = reader.read(file(["a", "\"" + Array(repeating: "l", count: 4).joined(separator: "\n") + "\""]))
        #expect(short.rows.allSatisfy { !$0.isMalformed })

        // Au-delà, le guillemet est déclaré fautif plutôt que d'avaler le reste.
        let long = Array(repeating: "l", count: 20).joined(separator: "\n")
        let document = reader.read(file(["a", "\"\(long)", "suite;normale"]))
        #expect(document.rows.contains { $0.malformation == .unterminatedQuote })
    }

    @Test("Un nombre de colonnes incohérent est signalé, la ligne reste lisible")
    func fieldCountMismatchIsReportedNotFatal() {
        // Le cas Excel le plus banal, et le second que `TabularData` refuse en bloc.
        let document = reader.read(file(["a;b", "1;2", "3;4;5", "6"]))
        #expect(document.rows.count == 3)

        #expect(document.rows[0].isMalformed == false)
        #expect(document.rows[1].malformation == .fieldCountMismatch(expected: 2, found: 3))
        #expect(document.rows[2].malformation == .fieldCountMismatch(expected: 2, found: 1))
        // Lisible : les valeurs sont là, l'utilisateur peut voir ce qu'il corrige.
        #expect(document.rows[1].fields == ["3", "4", "5"])
        #expect(document.rows[2].fields == ["6"])
    }

    @Test("Un fichier vide ne casse rien")
    func emptyFile() {
        #expect(reader.read(Data()).rows.isEmpty)
        #expect(reader.read(CSVWriter.byteOrderMark).rows.isEmpty)
    }

    @Test("Un fichier réduit à son en-tête rend zéro ligne")
    func headerOnly() {
        let document = reader.read(file(["titre;année"]))
        #expect(document.header == ["titre", "année"])
        #expect(document.rows.isEmpty)
    }

    // MARK: L'aller-retour, qui est le test qui compte

    @Test("Ce que le writer écrit, le reader le relit à l'identique")
    func roundTrip() {
        let header = ["titre", "résumé", "note"]
        let rows = [
            ["Éléphant", "Un résumé simple", "8,4"],
            ["A;B", "avec un \"guillemet\"", "5"],
            ["Multiligne", "ligne 1\nligne 2", "0"],
            [" espaces ", "", "10"]
        ]

        let data = CSVWriter().data(header: header, rows: rows)
        let document = CSVReader().read(data)

        #expect(document.header == header)
        #expect(document.rows.count == rows.count)
        for (index, expected) in rows.enumerated() {
            #expect(document.rows[index].fields == expected, "ligne \(index)")
            #expect(document.rows[index].isMalformed == false)
        }
    }

    @Test("Le rapport des écartées, redéposé, se relit")
    func rejectedReportIsReimportable() {
        // Le parcours que l'addendum décrit : le rapport est un CSV au format d'origine
        // avec une colonne d'erreur en fin de ligne, corrigé dans un tableur, redéposé.
        // Il porte donc notre propre marque d'ordre — que le lecteur doit retirer.
        let data = CSVWriter().data(
            header: ["titre", "année", "cineshelf_erreur"],
            rows: [["Éléphant", "20211", "Année attendue entre 1888 et 2030"]]
        )
        let document = CSVReader().read(data)
        #expect(document.header == ["titre", "année", "cineshelf_erreur"])
        #expect(document.rows[0].fields[2] == "Année attendue entre 1888 et 2030")
    }
}

// MARK: - L'encodage, nommé plutôt qu'avalé

struct CSVEncodingTests {

    @Test("Un octet non UTF-8 est signalé, la ligne reste lisible")
    func invalidEncodingIsReported() {
        // Le cas réel : un fichier enregistré en Windows-1252 par un vieux tableur.
        // « Renée » y a un 0xE9 isolé là où UTF-8 attend deux octets.
        var data = CSVWriter.byteOrderMark
        data.append(Data("nom\r\n".utf8))
        data.append(Data([0x52, 0x65, 0x6E, 0xE9, 0x65]))  // "Ren" + 0xE9 + "e"
        data.append(Data("\r\n".utf8))

        let document = CSVReader().read(data)
        #expect(document.rows.count == 1)
        #expect(
            document.rows[0].malformation == .invalidEncoding,
            "Un décodage silencieux aurait rendu « Ren?e » sans dire pourquoi"
        )
        // La ligne est rendue quand même : l'utilisateur doit voir ce qu'il corrige.
        #expect(document.rows[0].fields.isEmpty == false)
    }

    @Test("Un fichier UTF-8 valide n'est jamais signalé pour son encodage")
    func validEncodingIsNotReported() {
        // Contrôle négatif : sans lui, le test ci-dessus passerait aussi si toute ligne
        // était marquée.
        var data = CSVWriter.byteOrderMark
        data.append(Data("nom\r\nRenée Falconetti\r\nŒil\r\n".utf8))

        let document = CSVReader().read(data)
        #expect(document.rows.count == 2)
        #expect(document.rows.allSatisfy { $0.malformation != .invalidEncoding })
        #expect(document.rows[0].fields[0] == "Renée Falconetti")
        #expect(document.rows[1].fields[0] == "Œil")
    }
}
