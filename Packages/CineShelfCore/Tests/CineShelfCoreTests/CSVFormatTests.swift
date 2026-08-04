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
        // **Un compte exact, et non `>= 40`.** La première version de ce test tolérait neuf
        // disparitions sans le dire : sur 50 lignes dont une fautive, elle passait à 41
        // comme à 49. Une revue a mesuré 41, c'est-à-dire huit lignes évaporées derrière un
        // test vert. Depuis qu'un guillemet n'ouvre qu'en début de champ, la ligne 26 est la
        // seule perdue — elle commence vraiment par un guillemet jamais refermé — et le
        // compte est celui-là, sans marge.
        #expect(usable.count == 49, "Les lignes saines doivent survivre : \(usable.count)")
        #expect(document.malformedRows.count == 1)
        #expect(
            document.malformedRows.allSatisfy { $0.malformation?.isUnterminatedQuote == true },
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
        let long = Array(repeating: "l", count: 40).joined(separator: "\n")
        let document = reader.read(file(["a", "\"\(long)", "suite;normale"]))
        #expect(document.rows.contains { $0.malformation?.isUnterminatedQuote == true })
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

// Les six défauts du lecteur trouvés par la revue du 2026-08-04.
//
// Tous mesurés sur des entrées que la première batterie n'atteignait pas : un pouce dans un
// titre, un synopsis long mais correct, un fichier « CSV (Macintosh) », un en-tête fautif.
// Ils sont ici parce que chacun était **muet** — le lecteur rendait moins de lignes qu'il
// n'en avait reçu, et le rapport ne le disait pas.
struct CSVReaderRegressionTests {

    private let reader = CSVReader()

    private func file(_ lines: [String], newline: String = "\r\n") -> Data {
        CSVWriter.byteOrderMark + Data((lines.joined(separator: newline) + newline).utf8)
    }

    @Test("Un guillemet au milieu d'un champ n'ouvre rien, et ne coûte aucune ligne")
    func quoteInsideFieldIsLiteral() throws {
        // RFC 4180 ne compte un guillemet que collé au **début** d'un champ. La première
        // version ouvrait sur n'importe lequel : mesuré, `Le mur de 6" de haut` faisait rendre
        // 7 lignes sur 15 — huit titres valides avalés, et le rapport annonçait sereinement
        // « 7 analysées ».
        var lines = ["titre;annee"]
        for index in 1...15 {
            lines.append(index == 3 ? "Le mur de 6\" de haut;2001" : "Titre \(index);2001")
        }
        let document = reader.read(file(lines))

        #expect(document.rows.count == 15)
        #expect(document.malformedRows.isEmpty)
        let pouce = try #require(document.rows.first { $0.number == 4 })
        #expect(pouce.fields[0] == "Le mur de 6\" de haut")
    }

    @Test("Un synopsis de douze lignes correctement quoté reste intact")
    func longQuotedFieldSurvives() throws {
        // Le seuil de lignes seul ne savait pas distinguer un synopsis d'un guillemet oublié.
        // Mesuré avant correction : trois lignes utilisables sur dix, quatre fautives, trois
        // évaporées, et les paragraphes du synopsis remontés en **fausses lignes de données**.
        let synopsis = (1...12).map { "paragraphe \($0)" }.joined(separator: "\n")
        var lines = ["titre;resume"]
        for index in 1...10 {
            lines.append(index == 4 ? "Long synopsis;\"\(synopsis)\"" : "Titre \(index);court")
        }
        let document = reader.read(file(lines))

        #expect(document.rows.count == 10)
        #expect(document.malformedRows.isEmpty)
        let long = try #require(document.rows.first { $0.fields[0] == "Long synopsis" })
        #expect(long.fields[1] == synopsis)
        // Et aucun paragraphe ne s'est échappé en ligne de données.
        #expect(document.rows.contains { $0.fields[0].hasPrefix("paragraphe") } == false)
    }

    @Test("Un guillemet jamais refermé ne coûte qu'une ligne, et le dit")
    func unterminatedQuoteCostsExactlyOneLine() throws {
        // C'est le regard en avant qui rend ce compte possible : aucun guillemet fermant
        // n'existe dans la suite du fichier, donc le champ est refermé au premier saut de
        // ligne au lieu d'absorber un budget entier.
        var lines = ["titre;annee"]
        for index in 1...20 {
            lines.append(index == 5 ? "\"cassé;1970" : "Titre \(index);1970")
        }
        let document = reader.read(file(lines))

        #expect(document.wellFormedRows.count == 19)
        let faulty = try #require(document.malformedRows.first)
        #expect(faulty.malformation == .unterminatedQuote(absorbedLines: 0))
        // Les lignes d'après sont relues pour de vrai, guillemets rendus à leur sens.
        #expect(document.wellFormedRows.contains { $0.fields.first == "Titre 20" })
    }

    @Test("Un guillemet parasite qui trouve un fermant étranger dit ce qu'il a absorbé")
    func absorbedLinesAreReported() throws {
        // Le cas qui reste après le regard en avant : un guillemet fermant existe plus loin,
        // mais il appartient à une autre cellule. Le garde-fou de `maximumQuotedLines`
        // reprend alors la main — et la perte doit être **chiffrée**, parce qu'un rapport qui
        // annonce moins de lignes qu'il n'en a reçu sans expliquer pourquoi est exactement ce
        // que ce lecteur refuse.
        var lines = ["titre;resume"]
        lines.append("\"jamais refermé;1970")
        for index in 1...40 {
            lines.append("Titre \(index);court")
        }
        lines.append("Dernier;\"un résumé quoté, tout à fait légitime\"")
        let document = reader.read(file(lines))

        let faulty = try #require(document.malformedRows.first)
        #expect(faulty.malformation == .unterminatedQuote(absorbedLines: CSVReader.maximumQuotedLines))
        #expect(faulty.malformation?.message.contains("\(CSVReader.maximumQuotedLines) lignes") == true)
    }

    @Test("Un guillemet doublé dans un champ multiligne ne passe pas pour un fermant")
    func doubledQuoteIsNotAClosingQuote() throws {
        // Le regard en avant saute les paires : sinon un synopsis contenant une citation se
        // ferait passer pour terminé, et le champ se couperait au milieu d'une phrase.
        let document = reader.read(
            file(["titre;resume", "Dune;\"il a dit \"\"non\"\"\nà la ligne suivante\""]))

        #expect(document.rows.count == 1)
        #expect(document.rows[0].isMalformed == false)
        #expect(document.rows[0].fields[1] == "il a dit \"non\"\nà la ligne suivante")
    }

    @Test("Un fichier à fins de ligne CR seules se lit — c'est le format CSV (Macintosh)")
    func carriageReturnOnlyFile() {
        // La première version jetait les CR octet par octet : le fichier entier devenait un
        // en-tête, zéro ligne, et le rapport réclamait une colonne titre que le fichier
        // portait. Mesuré : `header == ["titre", "anneeDune", "2021Tenet", "2020"]`.
        let document = reader.read(file(["titre;annee", "Dune;2021", "Tenet;2020"], newline: "\r"))

        #expect(document.header == ["titre", "annee"])
        #expect(document.rows.count == 2)
        #expect(document.rows[0].fields == ["Dune", "2021"])
    }

    @Test("Un CRLF à l'intérieur d'une cellule devient un LF")
    func crlfInsideCellIsNormalised() {
        // Sans normalisation, le même synopsis donne deux valeurs de `summary` selon que le
        // tableur a écrit `\n` ou `\r\n` : deux fichiers que l'utilisateur tient pour
        // identiques, et rien ne montre la différence.
        let data = CSVWriter.byteOrderMark + Data("titre;resume\r\nDune;\"l1\r\nl2\"\r\n".utf8)
        let document = reader.read(data)

        #expect(document.rows[0].fields[1] == "l1\nl2")
    }

    @Test("Une ligne d'en-tête fautive est nommée au lieu d'être jetée")
    func headerMalformationIsReported() throws {
        // Elle était jetée par `read`, et c'était le fichier entier qu'on perdait : `header`
        // valait tout le fichier, `rows` était vide, et le rapport annonçait « champ requis
        // sans colonne » devant un fichier qui contient une colonne titre. L'utilisateur
        // cherchait une colonne manquante au lieu d'un guillemet.
        let data = CSVWriter.byteOrderMark + Data("\"titre;annee\r\nDune;2021\r\n".utf8)
        let document = reader.read(data)

        let malformation = try #require(document.headerMalformation)
        #expect(malformation.isUnterminatedQuote)
    }

    @Test("Un en-tête sain ne signale rien")
    func healthyHeaderReportsNothing() {
        #expect(reader.read(file(["titre;annee", "Dune;2021"])).headerMalformation == nil)
    }

    @Test("La reprise après un guillemet parasite redonne les bons numéros de ligne")
    func resynchronisationKeepsLineNumbers() throws {
        // L'arithmétique de reprise est la seule du lecteur, et rien ne la vérifiait. Le
        // numéro est celui du **tableur** : c'est ce que l'utilisateur doit corriger.
        var lines = ["titre;annee"]
        for index in 1...10 {
            lines.append(index == 3 ? "\"cassé;1970" : "Titre \(index);1970")
        }
        let document = reader.read(file(lines))

        #expect(document.malformedRows.map(\.number) == [4])
        // La ligne suivante reprend à 5, sans trou ni doublon.
        #expect(document.rows.map(\.number) == Array(2...11))
    }
}
