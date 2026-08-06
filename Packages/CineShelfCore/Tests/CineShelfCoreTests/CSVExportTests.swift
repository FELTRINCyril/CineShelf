import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// L'export, et le schéma de colonnes qui le pilote.
//
// Le test qui compte n'est aucun des deux pris seul : c'est l'aller-retour. Un export dont
// on ne relit pas le produit ne prouve rien — c'est la même classe d'erreur que le test de
// `#Predicate` qui ne passe pas par le magasin.

@MainActor
struct CSVSchemaTests {

    @Test("Les clés sont uniques, et aucune n'est vide")
    func keysAreUnique() {
        for schema in CSVSchema.all {
            let keys = schema.fields.map(\.key)
            #expect(Set(keys).count == keys.count, "\(schema.entity.rawValue) : clé en double")
            #expect(keys.allSatisfy { !$0.isEmpty })
            let headers = schema.fields.map(\.header)
            #expect(Set(headers).count == headers.count, "\(schema.entity.rawValue) : en-tête en double")
        }
    }

    @Test("Chaque schéma a au moins un champ requis à l'import")
    func everySchemaHasARequiredField() {
        // Sans champ requis, une ligne vide serait un import valide.
        for schema in CSVSchema.all {
            #expect(schema.requiredFields.isEmpty == false, "\(schema.entity.rawValue)")
        }
    }

    @Test("Un champ requis est proposé par défaut à l'export")
    func requiredFieldsAreExportedByDefault() {
        // Exporter un fichier qu'on ne pourrait pas réimporter serait absurde : c'est
        // l'aller-retour qui donne sa valeur à l'export.
        for schema in CSVSchema.all {
            for field in schema.requiredFields {
                #expect(field.isDefaultForExport, "\(schema.entity.rawValue).\(field.key)")
            }
        }
    }

    @Test("Une clé inconnue ne produit pas de colonne fantôme")
    func unknownKeysAreDropped() {
        // Une sélection mémorisée par une version antérieure peut citer un champ retiré.
        let header = CSVSchema.title.header(for: ["title", "cle_qui_nexiste_pas", "year"])
        #expect(header == ["Titre", "Année"])
    }

    @Test("Les valeurs multiples se coupent sur la barre verticale, pas sur la virgule")
    func multiValueSeparator() {
        // La virgule est le séparateur décimal en locale française, le point-virgule est
        // déjà le séparateur de colonnes — et la **barre oblique**, essayée d'abord, apparaît
        // dans les noms de genres eux-mêmes : « Action/Aventure » se coupait en deux à
        // l'aller-retour, mesuré le 2026-08-06. La barre verticale n'a pas ce défaut.
        #expect(CSVSchema.splitMultiValue("action|thriller") == ["action", "thriller"])
        #expect(CSVSchema.splitMultiValue(" action | thriller ") == ["action", "thriller"])
        #expect(CSVSchema.splitMultiValue("action||thriller") == ["action", "thriller"])
        #expect(CSVSchema.splitMultiValue("").isEmpty)
        #expect(CSVSchema.joinMultiValue(["action", "thriller"]) == "action|thriller")
    }
}

@MainActor
struct CSVExportTests {

    private let exporter = CSVExporter()

    private func makeTitle(in context: ModelContext, library: Library) -> Title {
        TitleRepository(context: context).create(name: "Le Conformiste", in: library)
    }

    @Test("Un titre complet s'exporte, valeur par valeur")
    func titleRowIsComplete() throws {
        let (context, library) = try makeTestLibrary()
        let title = makeTitle(in: context, library: library)
        let repository = TitleRepository(context: context)

        var components = DateComponents()
        components.year = 1970
        components.month = 6
        components.day = 15
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))

        repository.update(title, journal: .perEntity) {
            $0.originalName = "Il conformista"
            $0.releaseDate = date
            $0.releasePrecision = .day
            $0.runtimeMinutes = 111
            $0.rating = 8.4
            $0.summary = "Un résumé ; avec un point-virgule"
            $0.isPrivate = true
        }
        let saga = CollectionRepository(context: context).create(name: "Bertolucci", in: library)
        repository.setCollection(saga, on: title, journal: .perEntity)
        let genre = try GenreRepository(context: context)
            .findOrCreate(name: "Drame", target: .title, in: library)
        repository.setGenres([genre], on: title, journal: .perEntity)
        try context.save()

        #expect(exporter.value(of: title, forKey: "title") == "Le Conformiste")
        #expect(exporter.value(of: title, forKey: "original_title") == "Il conformista")
        #expect(exporter.value(of: title, forKey: "kind") == "movie")
        #expect(exporter.value(of: title, forKey: "year") == "1970")
        #expect(exporter.value(of: title, forKey: "release_date") == "1970-06-15")
        #expect(exporter.value(of: title, forKey: "runtime") == "111")
        // Point décimal et non virgule : un fichier n'est pas relu par la machine qui
        // l'a écrit, et les deux conventions coexisteraient selon la locale.
        #expect(exporter.value(of: title, forKey: "rating") == "8.4")
        #expect(exporter.value(of: title, forKey: "collection") == "Bertolucci")
        #expect(exporter.value(of: title, forKey: "genres") == "Drame")
        #expect(exporter.value(of: title, forKey: "is_private") == "oui")
        #expect(exporter.value(of: title, forKey: "is_archived") == "non")
    }

    @Test("Une note entière n'est pas écrite avec un point décimal inutile")
    func wholeRatingIsWrittenWithoutDecimal() throws {
        let (context, library) = try makeTestLibrary()
        let title = makeTitle(in: context, library: library)
        TitleRepository(context: context).update(title, journal: .perEntity) { $0.rating = 8 }
        try context.save()
        #expect(exporter.value(of: title, forKey: "rating") == "8")
    }

    @Test("Les champs vides rendent une cellule vide, pas la chaîne « nil »")
    func emptyFieldsAreEmpty() throws {
        let (context, library) = try makeTestLibrary()
        let title = makeTitle(in: context, library: library)
        try context.save()

        for key in [
            "original_title", "release_date", "runtime", "rating", "summary",
            "collection", "genres", "season_count", "episode_count"
        ] {
            #expect(exporter.value(of: title, forKey: key).isEmpty, "\(key)")
        }
    }

    @Test("Une clé inconnue rend une cellule vide, sans décaler les colonnes")
    func unknownKeyDoesNotShiftColumns() throws {
        let (context, library) = try makeTestLibrary()
        let title = makeTitle(in: context, library: library)
        try context.save()

        let row = exporter.row(for: title, keys: ["title", "inconnue", "kind"])
        #expect(row.count == 3)
        #expect(row == ["Le Conformiste", "", "movie"])
    }

    @Test("Une personne s'exporte, rôles triés")
    func personRow() throws {
        let (context, library) = try makeTestLibrary()
        let person = PersonRepository(context: context)
            .create(firstName: "Bernardo", lastName: "Bertolucci", roles: [.director, .actor], in: library)
        try context.save()

        #expect(exporter.value(of: person, forKey: "first_name") == "Bernardo")
        #expect(exporter.value(of: person, forKey: "last_name") == "Bertolucci")
        // Triés : sans ça, deux exports du même catalogue différeraient selon l'ordre
        // d'itération de l'ensemble.
        #expect(exporter.value(of: person, forKey: "roles") == "actor|director")
    }

    // MARK: L'aller-retour

    @Test("Un export se relit, cellule par cellule")
    func exportIsReadableBack() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let first = repository.create(name: "A;B", in: library)
        let second = repository.create(name: "Éléphant \"géant\"", in: library)
        repository.update(second, journal: .perEntity) { $0.summary = "ligne 1\nligne 2" }
        try context.save()

        let keys = ["title", "summary"]
        let data = exporter.export(titles: [first, second], keys: keys)
        let document = CSVReader().read(data)

        #expect(document.header == ["Titre", "Résumé"])
        #expect(document.rows.count == 2)
        #expect(document.rows.allSatisfy { !$0.isMalformed })
        // Les trois pièges du format dans un seul aller-retour : le séparateur dans une
        // valeur, le guillemet dans une valeur, le saut de ligne dans une valeur.
        #expect(document.rows[0].fields[0] == "A;B")
        #expect(document.rows[1].fields[0] == "Éléphant \"géant\"")
        #expect(document.rows[1].fields[1] == "ligne 1\nligne 2")
    }

    @Test("Un gabarit vierge porte les en-têtes par défaut du schéma")
    func templateUsesDefaultFields() {
        let data = exporter.template(for: .title)
        let document = CSVReader().read(data)

        #expect(document.rows.isEmpty)
        #expect(document.header == CSVSchema.title.defaultExportFields.map(\.header))
        // Et il doit être réimportable : les champs requis y sont.
        for field in CSVSchema.title.requiredFields {
            #expect(document.header.contains(field.header), "\(field.key)")
        }
    }

    @Test("Un export vide reste un fichier valide, avec son en-tête")
    func emptyExportKeepsHeader() {
        // Exporter une sélection vide ne doit pas produire un fichier de zéro octet, que
        // le tableur refuserait d'ouvrir.
        let data = exporter.export(titles: [], keys: ["title", "year"])
        let document = CSVReader().read(data)
        #expect(document.header == ["Titre", "Année"])
        #expect(document.rows.isEmpty)
        #expect(data.starts(with: CSVWriter.byteOrderMark))
    }
}

// Les trois colonnes ajoutées le 2026-08-04, en fin de `L11a`.
//
// Elles viennent de la planche 11d de l'addendum, qui fait correspondre `dir`, `cast_1` et
// `added` à des champs que le schéma d'export n'avait pas : sans elles, un fichier réel
// aurait vu sa réalisation et sa distribution tomber en « colonne ignorée ». Décision prise
// avec Cyril, contre l'option « les laisser non reconnues ».
//
// **L'écriture des crédits à l'import reste `L11b`** : créer une personne depuis une cellule
// demande une résolution de références qui n'existe pas encore (`GenreRepository.findOrCreate`
// n'a pas d'équivalent pour les personnes). Ici, l'export sait les écrire et la validation
// sait les lire comme des cellules multivaleur.
@MainActor
struct CSVCreditColumnsTests {

    private let exporter = CSVExporter()

    @Test("La réalisation et la distribution s'exportent, séparées par une barre verticale")
    func creditsAreExported() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let title = titles.create(name: "Dune", in: library)

        let villeneuve = people.create(firstName: "Denis", lastName: "Villeneuve", in: library)
        let chalamet = people.create(firstName: "Timothée", lastName: "Chalamet", in: library)
        let ferguson = people.create(firstName: "Rebecca", lastName: "Ferguson", in: library)

        titles.addCredit(person: villeneuve, role: .director, orderIndex: 0, to: title)
        titles.addCredit(person: chalamet, role: .cast, orderIndex: 0, to: title)
        titles.addCredit(person: ferguson, role: .cast, orderIndex: 1, to: title)
        try context.save()

        #expect(exporter.value(of: title, forKey: "director") == "Denis Villeneuve")
        // Trié par `orderIndex` et non par nom : une distribution alphabétique mettrait la
        // doublure avant la tête d'affiche, alors que `Credit` porte l'ordre du générique.
        #expect(exporter.value(of: title, forKey: "cast") == "Timothée Chalamet|Rebecca Ferguson")
    }

    @Test("L'ordre du générique est celui du fichier, même si les crédits sont ajoutés à l'envers")
    func castKeepsCreditOrderNotInsertionOrder() throws {
        let (context, library) = try makeTestLibrary()
        let titles = TitleRepository(context: context)
        let people = PersonRepository(context: context)
        let title = titles.create(name: "Tenet", in: library)

        let second = people.create(firstName: "Robert", lastName: "Pattinson", in: library)
        let first = people.create(firstName: "John David", lastName: "Washington", in: library)
        titles.addCredit(person: second, role: .cast, orderIndex: 1, to: title)
        titles.addCredit(person: first, role: .cast, orderIndex: 0, to: title)
        try context.save()

        #expect(exporter.value(of: title, forKey: "cast") == "John David Washington|Robert Pattinson")
    }

    @Test("Un titre sans crédit exporte une cellule vide, pas un séparateur solitaire")
    func creditlessTitleExportsEmptyCell() throws {
        let (context, library) = try makeTestLibrary()
        let title = TitleRepository(context: context).create(name: "Nope", in: library)
        try context.save()

        #expect(exporter.value(of: title, forKey: "director").isEmpty)
        #expect(exporter.value(of: title, forKey: "cast").isEmpty)
    }

    @Test("La date d'ajout s'exporte et se relit à l'identique")
    func addedAtRoundTrips() throws {
        let (context, library) = try makeTestLibrary()
        let title = TitleRepository(context: context).create(name: "Soul", in: library)
        try context.save()

        let written = exporter.value(of: title, forKey: "added_at")
        // Le fuseau courant des deux côtés : `CSVValueParser.date` doit relire ce que
        // `CSVExporter.dateStyle` écrit, sinon l'aller-retour décale les dates d'un jour.
        let reread = try #require(CSVValueParser.date(written))
        #expect(CSVExporter.dateStyle.format(reread) == written)
    }

    @Test("Les trois nouvelles colonnes sont reconnues avec certitude à la relecture")
    func newColumnsAreRecognized() {
        let header = CSVSchema.title.header(for: ["title", "director", "cast", "added_at"])
        let analysis = ColumnMatcher(schema: .title).analyze(header: header)

        #expect(analysis.matches.map(\.fieldKey) == ["title", "director", "cast", "added_at"])
        #expect(analysis.matches.allSatisfy { $0.quality == .certain })
    }

    @Test("Les noms de colonnes du fichier de la planche 11d se déduisent")
    func addendumColumnNamesAreInferred() {
        let analysis = ColumnMatcher(schema: .title).analyze(header: ["title", "dir", "cast_1", "added"])

        #expect(analysis.matches.map(\.fieldKey) == ["title", "director", "cast", "added_at"])
        #expect(analysis.ignoredColumnNames.isEmpty)
    }
}

// MARK: - V8 · L'aller-retour, trouvé par une sonde d'import de bout en bout

@Suite("Aller-retour du séparateur multivaleur")
struct MultiValueRoundTripTests {

    /// **Le défaut que la couture a révélé, et qu'aucune moitié ne pouvait voir.**
    ///
    /// Le séparateur était `/`. Un genre nommé « Action/Aventure » — un nom parfaitement
    /// ordinaire — s'exportait dans une liste jointe par `/`, et se réimportait en **deux**
    /// genres. Le genre d'origine disparaissait sans un mot.
    ///
    /// Les deux moitiés étaient correctes **entre elles** : l'export joignait sur `/`, l'import
    /// coupait sur `/`. C'est exactement le motif de `MediaFill` et de `PosterCardModel(_
    /// person:)` — deux parties justes, un joint absent.
    @Test("Une valeur qui contient une barre oblique survit à l'aller-retour")
    func slashInValueSurvives() {
        let joined = CSVSchema.joinMultiValue(["Action/Aventure", "Science-fiction"])
        #expect(CSVSchema.splitMultiValue(joined) == ["Action/Aventure", "Science-fiction"])
    }

    /// Le cas symétrique : une valeur qui contiendrait le **nouveau** séparateur ne survit pas
    /// davantage. Ce n'est pas une régression, c'est la limite du format — et elle est
    /// acceptable parce qu'aucun nom de genre ne porte de barre verticale, là où la barre
    /// oblique y est courante.
    @Test("La limite du format est nommée, pas niée")
    func pipeInValueIsTheKnownLimit() {
        let joined = CSVSchema.joinMultiValue(["A|B"])
        #expect(CSVSchema.splitMultiValue(joined) == ["A", "B"])
    }
}
