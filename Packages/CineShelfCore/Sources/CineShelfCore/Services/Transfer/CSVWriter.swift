import Foundation

// MARK: - Écrire un CSV qu'Excel relit sans se plaindre
//
// **Ce module n'importe pas `TabularData`, et c'est une décision.** La fiche exigeait déjà
// un sérialiseur maison ; la mesure a ensuite exclu `TabularData` pour la lecture aussi —
// il rejette un fichier entier dès qu'une ligne est mal formée, ce qui rend impossible
// l'aperçu « 771 lignes prêtes, 417 en erreur » de l'addendum. Le cadre ne servant plus à
// rien, ne pas l'importer évite en prime les collisions de noms qu'il aurait causées :
// il expose déjà `Column`, `Row`, `DataFrame` et `CSVType`.
//
// Trois exigences, chacune avec son motif :
//
// 1. **UTF-8 avec BOM.** Sans lui, Excel lit un CSV en Windows-1252 et « Élephant »
//    devient « Ãlephant ». Mesuré : `DataFrame.csvRepresentation` n'en écrit pas.
// 2. **Séparateur `;`.** C'est ce qu'attend un Excel en locale française, où la virgule
//    est le séparateur décimal.
// 3. **RFC 4180.** Un guillemet se double, il ne s'échappe pas par antislash. Les champs
//    contenant un séparateur, un guillemet ou un saut de ligne sont mis entre guillemets.

/// Sérialise des lignes de valeurs en CSV.
public struct CSVWriter: Sendable {

    /// Le préfixe UTF-8 qui dit à Excel comment lire le fichier.
    ///
    /// Trois octets, `EF BB BF`. Ce n'est pas un caractère : c'est une marque d'ordre des
    /// octets, et elle doit précéder le tout premier octet du contenu.
    public static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

    /// Le séparateur de champs.
    public let delimiter: Character
    /// La fin de ligne. `CRLF` par défaut, comme RFC 4180 l'exige.
    public let newline: String
    /// Écrire la marque d'ordre des octets en tête.
    public let includesByteOrderMark: Bool

    public init(
        delimiter: Character = ";",
        newline: String = "\r\n",
        includesByteOrderMark: Bool = true
    ) {
        self.delimiter = delimiter
        self.newline = newline
        self.includesByteOrderMark = includesByteOrderMark
    }

    /// Le CSV complet, prêt à écrire sur disque.
    ///
    /// - Parameters:
    ///   - header: les noms de colonnes. Vide, aucune ligne d'en-tête n'est écrite.
    ///   - rows: une valeur par colonne. Les lignes plus courtes que l'en-tête sont
    ///     complétées de champs vides, les plus longues ne sont **pas** tronquées : perdre
    ///     une valeur en silence serait pire qu'un fichier bancal, qui se voit.
    /// - Returns: les octets du fichier, marque d'ordre comprise si elle est demandée.
    public func data(header: [String], rows: [[String]]) -> Data {
        var output = includesByteOrderMark ? Self.byteOrderMark : Data()
        var text = ""

        if !header.isEmpty {
            text += line(header)
            text += newline
        }
        for row in rows {
            let padded =
                row.count < header.count
                ? row + Array(repeating: "", count: header.count - row.count)
                : row
            text += line(padded)
            text += newline
        }

        output.append(Data(text.utf8))
        return output
    }

    /// Une ligne, champs échappés et joints.
    public func line(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: String(delimiter))
    }

    /// Un champ, mis entre guillemets si nécessaire.
    ///
    /// Les guillemets internes sont **doublés** : c'est la forme RFC 4180, et la seule
    /// qu'Excel relit. Un antislash n'échapperait rien et ressortirait tel quel dans la
    /// cellule.
    /// > **Défaut trouvé le 2026-08-07, antérieur à `L11a` : un champ contenant `CRLF` n'était
    /// > jamais mis entre guillemets.** En Swift, `\r\n` est **un seul `Character`** — un
    /// > groupe de graphèmes — donc `field.contains("\r")` **et** `field.contains("\n")` sont
    /// > tous deux **faux** sur `"ligne 1\r\nligne 2"`. Le champ sortait nu, et son `CRLF`
    /// > était relu comme une fin de ligne : un synopsis venu d'Excel cassait la ligne
    /// > exportée **en deux**, décalant toutes les colonnes de la seconde moitié.
    /// >
    /// > Mesuré par une sonde : `escaped("ligne 1\r\nligne 2")` rendait le champ inchangé, là
    /// > où le même texte en `LF` seul était correctement quoté. Aucun test ne le voyait — ils
    /// > construisaient tous leurs fichiers à la main, donc le writer n'était jamais confronté
    /// > à un `CRLF` de cellule.
    /// >
    /// > La normalisation vient donc **avant** le test : après elle, il ne reste que des `\n`
    /// > isolés, sur lesquels `contains` se comporte comme on l'attend. Traiter la cause plutôt
    /// > que d'ajouter un troisième `contains` qui aurait le même angle mort.
    public func escaped(_ field: String) -> String {
        let normalised = Self.normalisedNewlines(field)
        let needsQuoting =
            normalised.contains(delimiter)
            || normalised.contains("\"")
            || normalised.contains("\n")
            // Un champ à espaces de bord perd ses espaces sans guillemets, et
            // « 1970 » deviendrait « 1970 » sans qu'on sache d'où vient la différence.
            || normalised.hasPrefix(" ")
            || normalised.hasSuffix(" ")

        guard needsQuoting else { return normalised }
        return "\"" + normalised.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Ramène les fins de ligne **à l'intérieur d'une cellule** à un `LF` unique.
    ///
    /// **Une normalisation délibérée, et il faut la nommer comme telle** — une modification
    /// silencieuse de la donnée de l'utilisateur est exactement ce que la correction du
    /// séparateur vient de fermer ailleurs.
    ///
    /// **Pourquoi normaliser plutôt que préserver.** Les fins de ligne dans un champ quoté sont
    /// incohérentes d'un tableur à l'autre : Excel écrit `CRLF`, Numbers et Google Sheets
    /// écrivent `LF`. Préserver les octets rendrait donc l'aller-retour **instable selon
    /// l'outil** — le même synopsis, exporté puis réimporté, donnerait deux valeurs de `summary`
    /// différentes selon le logiciel qui a touché le fichier entre les deux, et rien ne
    /// montrerait la différence à l'écran.
    ///
    /// **Ce qui est garanti est l'idempotence, et elle se tient des deux côtés.** `CSVReader`
    /// normalise déjà à la lecture ; sans cette moitié-ci, un champ portant `CRLF` changeait au
    /// **premier** aller-retour puis se stabilisait — la propriété tenait par accident, et un
    /// fichier écrit par CineShelf pouvait contenir des `CRLF` de cellule qu'un autre outil
    /// relirait autrement. Écrire normalisé rend l'invariant vrai dès le premier tour :
    ///
    ///     lire(écrire(x)) == lire(écrire(lire(écrire(x))))
    ///
    /// **Le terminateur de ligne n'est pas touché** : il reste `CRLF`, comme RFC 4180 §2.1 et
    /// `docs/04` l'exigent. Cette fonction ne voit qu'un champ, jamais la ligne qui le porte.
    static func normalisedNewlines(_ field: String) -> String {
        field
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

// MARK: - Gabarits

extension CSVWriter {
    /// Un fichier vierge : l'en-tête seul, sans aucune ligne.
    ///
    /// Sert à donner un modèle à remplir dans un tableur. Le BOM y est aussi nécessaire :
    /// c'est le fichier que l'utilisateur va rouvrir dans Excel, y taper des accents, et
    /// redéposer.
    public func template(header: [String]) -> Data {
        data(header: header, rows: [])
    }
}
