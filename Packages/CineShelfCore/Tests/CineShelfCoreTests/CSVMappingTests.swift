import Foundation
import Testing

@testable import CineShelfCore

// La correspondance des colonnes : l'étape 1 de l'import.
//
// Fixtures écrites à la volée, comme la première moitié de `L11a` : les octets exacts
// restent lisibles à côté de l'assertion.
//
// Les colonnes des fichiers d'exemple viennent de la planche 11d de l'addendum
// (`docs/design/CineShelf - Addendum - Erreurs et import.dc.html`, section 11d) : `title`,
// `year`, `runtime_min`, `media`, `shelf_ref`, `my_score`, `dir`, `cast_1`, `genre_raw`,
// `bought_at`, `price_eur`, `notes_perso`, `added`, `watched_count`. C'est un mock de
// **rendu**, mais la liste de colonnes qu'il montre est un cas d'usage réel, et c'est à ce
// titre qu'elle sert ici — pas comme source d'une règle de modèle.

struct HeaderSignatureTests {

    @Test("Deux en-têtes de même contenu ont la même signature, quel que soit l'ordre")
    func signatureIgnoresOrder() {
        let first = ColumnMapping.headerSignature(for: ["Titre", "Année", "Genres"])
        let second = ColumnMapping.headerSignature(for: ["Genres", "Titre", "Année"])
        // La correspondance est mémorisée **par nom de colonne** : déplacer une colonne dans
        // le tableur ne change rien à ce qu'elle décide.
        #expect(first == second)
    }

    @Test("La casse et les accents ne changent pas la signature")
    func signatureFoldsCaseAndDiacritics() {
        #expect(
            ColumnMapping.headerSignature(for: ["ANNÉE", "Titre"])
                == ColumnMapping.headerSignature(for: ["annee", "TITRE"]))
    }

    @Test("Les colonnes vides ne comptent pas")
    func signatureDropsEmptyColumns() {
        // Un export qui finit par un point-virgule solitaire produit une colonne sans nom.
        // Sans ce filtre, le même fichier aurait deux signatures.
        #expect(
            ColumnMapping.headerSignature(for: ["Titre", "Année", ""])
                == ColumnMapping.headerSignature(for: ["Titre", "Année"]))
    }

    @Test("Deux en-têtes différents ont deux signatures")
    func differentHeadersDiffer() {
        #expect(
            ColumnMapping.headerSignature(for: ["Titre"])
                != ColumnMapping.headerSignature(for: ["Titre", "Année"]))
    }

    @Test("La signature est calculée sous locale invariante")
    func signatureIsLocaleInvariant() {
        // Même contrôle que `LocaleInvarianceTests`, et pour la même raison : la signature
        // est **écrite** par un appareil et **comparée** par un autre, parce que
        // `ImportMapping` est synchronisée par CloudKit. Deux repliages différents des deux
        // côtés ne se rencontrent jamais, et la correspondance mémorisée devient
        // introuvable — sans erreur, sans signal. Voir `docs/02` §3.
        let turkish = Locale(identifier: "tr_TR")
        let header = ["ITALIA", "Interstellar"]

        let produced = ColumnMapping.headerSignature(for: header)
        let underTurkish =
            header
            .map {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: turkish)
            }
            .sorted()
            .joined(separator: "\u{1F}")

        #expect(produced != underTurkish)
        #expect(produced == "interstellar\u{1F}italia")
    }
}

struct ColumnMatcherTests {

    private let matcher = ColumnMatcher(schema: .title)

    @Test("Un en-tête exporté par CineShelf est reconnu avec certitude")
    func exportedHeaderIsCertain() {
        // Le premier geste d'un utilisateur qui déplace son catalogue : exporter, puis
        // réimporter. Rien ne doit y être « déduit ».
        let keys = CSVSchema.title.defaultExportFields.map(\.key)
        let analysis = matcher.analyze(header: CSVSchema.title.header(for: keys))

        #expect(analysis.matches.allSatisfy { $0.quality == .certain })
        #expect(analysis.ignoredColumnNames.isEmpty)
        #expect(analysis.canProceed)
    }

    @Test("La clé stable est reconnue aussi bien que l'en-tête lisible")
    func stableKeyIsCertain() {
        let analysis = matcher.analyze(header: ["title", "year", "runtime"])
        #expect(analysis.matches.map(\.fieldKey) == ["title", "year", "runtime"])
        #expect(analysis.matches.allSatisfy { $0.quality == .certain })
    }

    @Test("Un alias déclaré produit une correspondance déduite, pas sûre")
    func aliasIsInferred() throws {
        let analysis = matcher.analyze(header: ["runtime_min", "my_score"])
        let runtime = try #require(analysis.matches.first)

        #expect(runtime.fieldKey == "runtime")
        // Déduite et non sûre : l'écran la montre comme à vérifier. C'est ce qui remplace le
        // profil Movix intégré, refusé par l'arbitrage du 2026-08-04.
        #expect(runtime.quality == .inferred)
        #expect(analysis.matches[1].fieldKey == "rating")
    }

    @Test("Une colonne inconnue n'est pas une erreur : elle est ignorée et nommée")
    func unknownColumnIsIgnoredNotRejected() {
        let analysis = matcher.analyze(header: ["Titre", "bought_at", "notes_perso"])

        // La planche 11d le dit mot pour mot : « Elles ne sont pas une erreur : par défaut
        // elles sont ignorées, et l'import peut avancer sans y toucher. »
        #expect(analysis.canProceed)
        #expect(analysis.ignoredColumnNames == ["bought_at", "notes_perso"])
        #expect(analysis.matches(quality: .unrecognized).count == 2)
    }

    @Test("Une colonne se déduit de son contenu quand son nom ne dit rien")
    func contentDecidesWhenNameDoesNot() throws {
        let document = CSVReader().read(
            csv(
                header: ["Titre", "col_1"],
                rows: [["Dune", "2021"], ["Tenet", "2020"], ["Nope", "2022"]]))
        let analysis = matcher.analyze(header: document.header, rows: document.rows)
        let deduced = try #require(analysis.matches.last)

        #expect(deduced.fieldKey == "year")
        #expect(deduced.quality == .inferred)
        // La déduction dit sur quoi elle s'est faite : une déduction qu'on ne peut pas
        // vérifier d'un coup d'œil est pire qu'une colonne laissée non reconnue.
        #expect(deduced.rationale?.contains("2021") == true)
    }

    @Test("Une forme ambiguë ne décide de rien")
    func ambiguousShapeAbstains() {
        // Trois dates : ça peut être `release_date` comme `added_at`. Deviner écrirait la
        // mauvaise valeur dans le bon champ, ce qui ne se voit jamais.
        let document = CSVReader().read(
            csv(
                header: ["Titre", "col_1"],
                rows: [["Dune", "2021-10-20"], ["Tenet", "2020-08-26"]]))
        let analysis = matcher.analyze(header: document.header, rows: document.rows)

        #expect(analysis.matches.last?.quality == .unrecognized)
    }

    @Test("Un champ n'est jamais alimenté par deux colonnes")
    func fieldIsClaimedOnce() {
        // `year` est sûr, `annee` est un alias du même champ. Sans la règle, les deux
        // gagneraient et personne ne saurait laquelle a écrit la valeur.
        let analysis = matcher.analyze(header: ["year", "annee"])

        #expect(analysis.matches[0].fieldKey == "year")
        #expect(analysis.matches[0].quality == .certain)
        #expect(analysis.matches[1].fieldKey == nil)
    }

    @Test("Un champ requis sans colonne bloque l'étape 1")
    func missingRequiredFieldBlocks() {
        let analysis = matcher.analyze(header: ["year", "runtime"])

        // La quatrième statistique de 11d. Sans titre, l'aperçu ne dirait que « toutes les
        // lignes en erreur », ce qui n'aide personne.
        #expect(analysis.missingRequiredFieldKeys == ["title"])
        #expect(analysis.canProceed == false)
    }

    @Test("Réaffecter une colonne à la main la rend sûre et libère l'ancienne")
    func manualAssignmentReclaimsField() throws {
        let analysis = matcher.analyze(header: ["Titre", "col_1"])
        let corrected = analysis.assigning(fieldKey: "title", toColumnAt: 1)

        #expect(corrected.matches[1].fieldKey == "title")
        #expect(corrected.matches[1].quality == .certain)
        // La colonne qui tenait le champ le perd : deux colonnes pour un champ est le cas
        // que la passe de reconnaissance évite déjà.
        #expect(corrected.matches[0].fieldKey == nil)
        #expect(corrected.canProceed)
    }

    @Test("Retirer l'affectation d'une colonne rend le champ requis manquant")
    func unassigningReportsMissingRequirement() {
        let analysis = matcher.analyze(header: ["Titre", "Année"])
        let stripped = analysis.assigning(fieldKey: nil, toColumnAt: 0)

        #expect(stripped.missingRequiredFieldKeys == ["title"])
        #expect(stripped.canProceed == false)
    }

    @Test("Les lignes mal découpées ne servent pas à déduire")
    func malformedRowsDoNotFeedInference() {
        // Leurs champs sont décalés : la valeur qu'on lit en colonne 2 appartient à une
        // autre colonne. Déduire là-dessus, c'est déduire sur du bruit.
        let document = CSVReader().read(
            csv(
                header: ["Titre", "col_1"],
                rows: [["Dune", "2021", "de trop"], ["Tenet", "2020"], ["Nope", "2022"]]))
        let analysis = matcher.analyze(header: document.header, rows: document.rows)

        #expect(document.malformedRows.count == 1)
        #expect(analysis.matches.last?.fieldKey == "year")
    }

    @Test("Les quatorze colonnes de la planche 11d se répartissent en trois qualités")
    func addendumFileIsFullyClassified() {
        let header = [
            "title", "year", "runtime_min", "media", "shelf_ref", "my_score", "dir",
            "cast_1", "genre_raw", "bought_at", "price_eur", "notes_perso", "added",
            "watched_count"
        ]
        let analysis = matcher.analyze(header: header)

        #expect(analysis.canProceed)
        #expect(analysis.matches(quality: .certain).map(\.columnName) == ["title", "year"])
        // `media`, `shelf_ref` et `watched_count` sont les trois colonnes que l'arbitrage du
        // 2026-08-04 a décidé d'ignorer faute de champ au modèle — décision assumée, aucune
        // migration. Elles se retrouvent donc ici, **nommées**, avec les trois colonnes que
        // le mock montrait déjà comme ignorées.
        #expect(
            analysis.ignoredColumnNames == [
                "media", "shelf_ref", "bought_at", "price_eur", "notes_perso", "watched_count"
            ])
    }
}

struct ColumnMappingSerializationTests {

    @Test("Une correspondance se relit telle qu'elle a été écrite")
    func roundTrip() throws {
        let mapping = ColumnMapping(entity: .title, columnToField: ["runtime_min": "runtime"])
        let decoded = try ColumnMapping.decoded(from: mapping.encoded())

        #expect(decoded == mapping)
        #expect(decoded.version == ColumnMapping.currentVersion)
    }

    @Test("Une version inconnue est refusée, pas devinée")
    func futureVersionIsRefused() throws {
        // Le cas est réel en synchronisation : un appareil déjà mis à jour écrit un format
        // que celui-ci ne connaît pas. Deviner écrirait les bonnes valeurs dans les mauvais
        // champs — même motif que `BulkEditDiff.decoded(from:)`.
        let future = ColumnMapping(
            version: ColumnMapping.currentVersion + 1,
            entity: .title,
            columnToField: [:])
        let data = try JSONEncoder().encode(future)

        #expect(throws: ColumnMappingError.unsupportedVersion(ColumnMapping.currentVersion + 1)) {
            try ColumnMapping.decoded(from: data)
        }
    }

    @Test("La correspondance ne retient que les colonnes affectées")
    func ignoredColumnsAreNotStored() {
        let analysis = ColumnMatcher(schema: .title).analyze(header: ["Titre", "notes_perso"])
        #expect(analysis.mapping.columnToField == ["Titre": "title"])
    }
}

struct CSVSchemaIntegrityTests {

    @Test("Aucun alias n'est réclamé par deux champs du même schéma")
    func aliasesDoNotCollide() {
        // Une collision rendrait la reconnaissance dépendante de l'ordre de déclaration : le
        // fichier serait lu correctement, puis autrement le jour où une colonne bouge.
        for schema in CSVSchema.all {
            var seen: [String: String] = [:]
            for field in schema.fields {
                for alias in field.aliases {
                    let key = alias.foldedForMatching
                    #expect(seen[key] == nil, "« \(alias) » est réclamé deux fois")
                    seen[key] = field.key
                }
            }
        }
    }

    @Test("Aucun alias ne masque l'en-tête ou la clé d'un autre champ")
    func aliasesDoNotShadowOtherFields() {
        // La passe des noms exacts joue avant celle des alias : un alias qui heurte l'en-tête
        // d'un autre champ ne servirait donc jamais, et donnerait l'illusion d'être couvert.
        for schema in CSVSchema.all {
            for field in schema.fields {
                for alias in field.aliases.map(\.foldedForMatching) {
                    let owner = schema.fields.first {
                        $0.header.foldedForMatching == alias || $0.key.foldedForMatching == alias
                    }
                    #expect(
                        owner == nil || owner?.key == field.key,
                        "« \(alias) » de \(field.key) heurte \(owner?.key ?? "")")
                }
            }
        }
    }

    @Test("Tout champ borné porte une forme numérique")
    func boundedFieldsAreNumeric() {
        // Une borne sur un champ textuel ne serait jamais vérifiée : le validateur ne
        // convertit pas `.text`. Le silence serait total.
        for schema in CSVSchema.all {
            for field in schema.fields where field.range != nil {
                #expect([.year, .integer, .decimal].contains(field.shape), "\(field.key)")
            }
        }
    }

    @Test("Tout champ à vocabulaire fermé est énuméré ou multivaleur")
    func vocabularyImpliesEnumeratedShape() {
        for schema in CSVSchema.all {
            for field in schema.fields where !field.allowedValues.isEmpty {
                #expect([.enumerated, .multiValue].contains(field.shape), "\(field.key)")
            }
        }
    }
}

// MARK: - Fixtures

/// Un CSV construit octet par octet : BOM, `CRLF`, point-virgule.
///
/// La même forme que `CSVWriter` produit, écrite à la main pour que le test ne dépende pas
/// de l'écrivain qu'il sert à éprouver.
func csv(header: [String], rows: [[String]]) -> Data {
    var text = header.joined(separator: ";") + "\r\n"
    for row in rows {
        text += row.joined(separator: ";") + "\r\n"
    }
    return CSVWriter.byteOrderMark + Data(text.utf8)
}
