import Foundation
import Testing

@testable import CineShelfCore

// Le format CSV, dans les deux sens.
//
// Les fixtures sont **construites dans les tests**, pas déposées en ressources : les
// octets exacts — marque d'ordre, `CRLF`, guillemets doublés — restent lisibles à côté de
// l'assertion au lieu d'être cachés dans un binaire que personne ne rouvre. C'est aussi ce
// qui permet de tester un fichier volontairement corrompu sans l'expliquer en commentaire.
//
// MARK: - Les sources de ce fichier
//
// **Cette section existe parce que ce fichier décide d'un format de données, et qu'il a
// laissé passer le pire défaut du dépôt.** Le séparateur multivaleur destructeur est né à
// `L12` sous douze tests verts ; une sonde a ensuite trouvé six pertes sur treize entrées.
// L'audit du 2026-08-07 a mesuré la cause : 34 fonctions ici, **une** citation de source.
// Chaque test portait une *justification* — souvent excellente, souvent une mesure — mais
// presque aucun ne disait **qui décide**. Un test qui ne cite que lui-même décrit une
// implémentation ; il ne peut pas contredire l'intention de son auteur.
//
// Les quatre autorités, et ce que chacune tranche :
//
// - **RFC 4180** — norme externe. Le doublement du guillemet (§2.7), le guillemet
//   significatif **en début de champ seulement** (§2.5), les fins de ligne `CRLF` (§2.1).
//   C'est la seule source qu'on ne peut pas amender.
// - **`docs/04-ARCHITECTURE-SWIFTUI.md`, « Écriture CSV »** — « sérialiseur maison, UTF-8
//   **avec BOM** (sinon Excel massacre les accents), séparateur `;` en locale française,
//   échappement RFC 4180 ». C'est la source du format d'**écriture**.
// - **`docs/PROMPTS.md`, fiche `L11a`** — le lecteur tolérant, `TabularData` exclu pour
//   l'import (une ligne fautive fait rejeter le fichier entier), et la resynchronisation.
// - **`docs/journal.md`, 2026-08-04** — les six défauts du lecteur trouvés par revue, et le
//   **regard en avant** qui les a fermés. Autorité empirique : ce qui a été mesuré.
//
// **Un désaccord relevé par cet audit, et il était muet.** `docs/04` et `docs/PROMPTS.md`
// écrivent tous deux « resynchronisation au-delà de **huit** lignes englobées ». Le code dit
// `maximumQuotedLines = 32`. Le journal du 2026-08-04 explique le passage de 8 à 32 puis
// l'arrivée du regard en avant, qui a fait du budget un simple garde-fou — mais les deux
// documents n'ont jamais suivi. C'est le code qui a raison, avec sa mesure ; les documents
// sont corrigés, et le nom d'un test d'ici disait « huit » lui aussi.
//
// **Les assertions qui n'ont aucune source documentaire sont marquées `SANS SOURCE`.** Elles
// ne sont pas fausses — elles sont des décisions prises dans le code et jamais arbitrées
// ailleurs. Les nommer est le but de la passe : c'est là qu'un test décrit l'implémentation
// plutôt que l'exigence, donc là où le prochain défaut de format naîtra.

struct CSVWriterTests {

    private let writer = CSVWriter()

    /// Source : `docs/04`, « Écriture CSV » — « UTF-8 **avec BOM** (sinon Excel massacre les
    /// accents) ». La séquence `EF BB BF` est celle d'Unicode pour UTF-8.
    @Test("La marque d'ordre des octets est en tête, et c'est ce qui sauve les accents")
    func byteOrderMarkComesFirst() {
        let data = writer.data(header: ["titre"], rows: [["Éléphant"]])
        #expect(data.starts(with: CSVWriter.byteOrderMark))
        // Sans la marque, Excel lit le fichier en Windows-1252 et « Éléphant » devient
        // « Ãlephant ». Mesuré : `DataFrame.csvRepresentation` ne l'écrit pas.
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    /// Sources, et elles sont deux : le point-virgule vient de `docs/04`, « séparateur `;` en
    /// locale française » — repris par la fiche `L11a` de `docs/PROMPTS.md`. Le `CRLF` vient de
    /// **RFC 4180 §2.1**, et c'est ce qu'Excel écrit.
    @Test("Le séparateur est le point-virgule, et les lignes finissent en CRLF")
    func delimiterAndNewline() throws {
        let data = writer.data(header: ["a", "b"], rows: [["1", "2"]])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "a;b\r\n1;2\r\n")
    }

    /// Source : **RFC 4180 §2.7** pour le doublement du guillemet, et `docs/04` qui l'adopte
    /// explicitement (« échappement RFC 4180 »).
    ///
    /// **SANS SOURCE — les deux cas d'espace de bord.** RFC 4180 n'exige pas de quoter un champ
    /// pour ses espaces de tête ou de queue : c'est une décision prise dans `CSVWriter`, et sa
    /// raison est réelle (un tableur mange les espaces non protégés, donc l'aller-retour les
    /// perdrait). Elle n'est arbitrée par aucun document. À noter : c'est exactement la même
    /// classe de décision que le `trimmingCharacters` de `splitMultiValue`, qui a failli faire
    /// écrire un invariant faux le 2026-08-07.
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

    /// **SANS SOURCE.** Aucun document ne dit quoi faire d'une ligne trop courte à l'écriture.
    /// La décision — compléter — est cohérente avec le refus de perdre en silence qui gouverne
    /// le lecteur (fiche `L11a`), mais elle n'est écrite nulle part.
    @Test("Une ligne plus courte que l'en-tête est complétée")
    func shortRowsArePadded() throws {
        let data = writer.data(header: ["a", "b", "c"], rows: [["1"]])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "a;b;c\r\n1;;\r\n")
    }

    /// **SANS SOURCE**, même famille que le test précédent. Le principe invoqué — « perdre une
    /// valeur en silence est pire qu'un fichier bancal » — est celui de la fiche `L11a` pour le
    /// *lecteur* ; l'appliquer à l'écriture est une extension raisonnable et non arbitrée.
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

    /// Source du numéro de ligne : **addendum 1**, blocs `11e` et `11f`, qui affichent des
    /// numéros à quatre chiffres à côté de chaque ligne fautive. C'est le numéro du **tableur**
    /// — celui que l'utilisateur doit aller corriger — donc l'en-tête est la ligne 1.
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

    /// **SANS SOURCE.** `docs/04` impose le BOM à l'**écriture** et ne dit rien de la lecture.
    /// L'accepter absent est nécessaire — un fichier tiers n'en a pas — mais non arbitré.
    @Test("Un fichier sans marque d'ordre se lit aussi")
    func fileWithoutByteOrderMark() {
        let document = reader.read(file(["titre;année", "A;1970"], bom: false))
        #expect(document.header == ["titre", "année"])
        #expect(document.rows.count == 1)
    }

    /// **SANS SOURCE**, et c'est une tolérance en lecture plutôt qu'une règle : RFC 4180 §2.1
    /// impose `CRLF`, mais refuser un fichier Unix serait gratuit. La fiche `L11a` demande un
    /// « lecteur tolérant » sans énumérer ce qu'il tolère.
    @Test("Les fins de ligne LF seules sont acceptées")
    func lineFeedOnly() {
        // Un fichier venu d'un outil Unix n'a pas de CR. Le refuser serait gratuit.
        let document = reader.read(file(["a;b", "1;2"], newline: "\n"))
        #expect(document.rows.count == 1)
        #expect(document.rows[0].fields == ["1", "2"])
    }

    /// Source : **RFC 4180 §2.6** — un séparateur à l'intérieur d'un champ quoté est une
    /// donnée.
    @Test("Un point-virgule dans un champ quoté n'est pas un séparateur")
    func quotedDelimiter() {
        let document = reader.read(file(["a;b", "\"un;deux\";trois"]))
        #expect(document.rows[0].fields == ["un;deux", "trois"])
        #expect(document.rows[0].isMalformed == false)
    }

    /// Source : **RFC 4180 §2.7**, le pendant en lecture du test d'écriture plus haut.
    @Test("Un guillemet doublé rend un guillemet")
    func doubledQuote() {
        let document = reader.read(file(["a", "\"il a dit \"\"non\"\"\""]))
        #expect(document.rows[0].fields == ["il a dit \"non\""])
    }

    /// Source : **RFC 4180 §2.6** — un saut de ligne dans un champ quoté est une donnée. C'est
    /// le cas du synopsis, et c'est ce qui rend la resynchronisation difficile : la même
    /// séquence d'octets peut être un synopsis légitime ou un guillemet oublié.
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

    /// **Ce test s'appelait « au-delà de huit lignes » et le seuil vaut 32.**
    ///
    /// Le nom venait de `docs/04` et de la fiche `L11a`, qui disent « huit » tous les deux. Le
    /// journal du 2026-08-04 raconte la suite : le seuil est passé de 8 à 32 — ce qui a fait
    /// **empirer** le pire cas, 24 lignes perdues au lieu de 8 — puis le regard en avant est
    /// arrivé et a réduit le coût d'un guillemet oublié à **une** ligne. Le budget n'est plus
    /// qu'un garde-fou pour le cas où un fermant étranger existe plus loin.
    ///
    /// Le nom mentait donc depuis trois jours, sans qu'aucune assertion ne s'en aperçoive :
    /// 4 < 32 passe, 40 > 32 échoue, et le test est vert avec n'importe quel seuil entre les
    /// deux. **Source de la valeur : `CSVReader.maximumQuotedLines`, et le test la lit au lieu
    /// de la recopier** — c'est ce qui empêche le nom et le code de diverger à nouveau.
    @Test("La resynchronisation s'active au-delà du budget de lignes quotées")
    func resynchronisationThreshold() {
        // En dessous du seuil, le champ multiligne reste légitime : c'est un synopsis.
        let short = reader.read(file(["a", "\"" + Array(repeating: "l", count: 4).joined(separator: "\n") + "\""]))
        #expect(short.rows.allSatisfy { !$0.isMalformed })

        // Au-delà, le guillemet est déclaré fautif plutôt que d'avaler le reste. Le compte est
        // **dérivé du budget** et non écrit en dur : un seuil qui changerait sans que ce test
        // bouge est exactement ce qui a laissé le nom mentir.
        let long = Array(repeating: "l", count: CSVReader.maximumQuotedLines + 8)
            .joined(separator: "\n")
        let document = reader.read(file(["a", "\"\(long)", "suite;normale"]))
        #expect(document.rows.contains { $0.malformation?.isUnterminatedQuote == true })
    }

    /// Source : fiche `L11a` — « `TabularData` est **exclu pour l'import** : mesuré, une seule
    /// ligne mal formée fait rejeter le fichier **entier** ». Signaler sans jeter est la raison
    /// d'être du lecteur maison, et l'aperçu « 771 prêtes, 417 en erreur » de l'addendum en
    /// dépend directement.
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

    /// **SANS SOURCE**, et c'est normal : aucun document ne spécifie le cas dégénéré. Le test
    /// existe pour que le lecteur ne lève pas, pas pour encoder une exigence.
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

    /// **L'aller-retour n'a pas de source : il EST la source.** C'est la propriété que le
    /// format doit tenir, et dont tout le reste découle — `docs/04` exige d'exporter un fichier
    /// réimportable, et `CSVExportTests` vérifie la même chose côté schéma.
    ///
    /// **Bornes de l'invariant, et elles ne sont pas rhétoriques.** Il ne vaut que pour des
    /// lignes de la longueur de l'en-tête : une ligne courte est complétée, une longue n'est pas
    /// tronquée, donc ni l'une ni l'autre ne revient identique. L'énoncer « pour toute liste de
    /// lignes » serait une intention fausse déguisée en rigueur — voir `CLAUDE.md`.
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

    /// Source : **addendum 1**, bloc `11j` — le rapport des écartées est « un CSV au format
    /// d'origine avec une colonne d'erreur en fin de ligne », fait pour être corrigé dans un
    /// tableur puis redéposé. Le nom `cineshelf_erreur` vient de là.
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
