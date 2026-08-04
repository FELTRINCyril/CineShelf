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
    public func escaped(_ field: String) -> String {
        let needsQuoting =
            field.contains(delimiter)
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
            // Un champ à espaces de bord perd ses espaces sans guillemets, et
            // « 1970 » deviendrait « 1970 » sans qu'on sache d'où vient la différence.
            || field.hasPrefix(" ")
            || field.hasSuffix(" ")

        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
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
