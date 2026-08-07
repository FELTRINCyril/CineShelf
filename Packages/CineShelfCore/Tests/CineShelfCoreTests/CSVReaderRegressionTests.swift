import Foundation
import Testing

@testable import CineShelfCore

// MARK: - L'encodage et les six défauts du lecteur
//
// **Scindé de `CSVFormatTests` le 2026-08-07**, quand la passe de citation des sources a fait
// dépasser les 500 lignes au fichier d'origine. La coupe n'est pas arbitraire : ce qui suit
// porte sur des entrées **adverses** — un octet Windows-1252, un pouce dans un titre, un
// fichier « CSV (Macintosh) » —, là où `CSVFormatTests` décrit le format nominal.
//
// **Les sources font foi dans `CSVFormatTests`**, en tête de fichier : RFC 4180, `docs/04`,
// la fiche `L11a` de `docs/PROMPTS.md`, et le journal du 2026-08-04 pour ce qui a été mesuré.

// MARK: - L'encodage, nommé plutôt qu'avalé

struct CSVEncodingTests {

    /// Source : `docs/04`, qui liste `invalidEncoding` parmi les incidents que le lecteur doit
    /// **nommer** au lieu d'avaler — même principe que le compte de colonnes.
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

    /// Source : **RFC 4180 §2.5** — un guillemet n'est significatif qu'en début de champ. La
    /// première version ouvrait sur n'importe lequel ; mesure au journal du 2026-08-04.
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

    /// **CONVENTION, aucun document** pour la tolérance elle-même — le format « CSV
    /// (Macintosh) » n'est décrit par aucun texte du dépôt. La **mesure**, elle, est au journal
    /// du 2026-08-04 : sans cette tolérance le fichier entier devenait un en-tête, et le rapport
    /// réclamait une colonne titre que le fichier portait. Un des six défauts de la revue.
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

    /// **NORMALISATION DÉLIBÉRÉE — arbitrée le 2026-08-07**, et documentée dans
    /// `CSVWriter.normalisedNewlines`.
    ///
    /// Elle modifie la donnée de l'utilisateur, ce qui exige une justification explicite : les
    /// fins de ligne dans un champ quoté sont **incohérentes d'un tableur à l'autre** — Excel
    /// écrit `CRLF`, Numbers et Google Sheets écrivent `LF`. Les préserver rendrait
    /// l'aller-retour instable *selon l'outil* : le même synopsis donnerait deux valeurs de
    /// `summary` selon le logiciel qui a touché le fichier entre-temps.
    ///
    /// Ce qui est garanti à la place est l'**idempotence**, tenue des deux côtés — la
    /// normalisation est à la lecture **et** à l'écriture. Le terminateur de ligne, lui, reste
    /// `CRLF` (RFC 4180 §2.1).
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
