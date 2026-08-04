import Foundation

// MARK: - Lire une cellule
//
// Le pendant exact de `CSVExporter`, qui écrit les cellules. Les deux se lisent ensemble :
// tout ce que l'export écrit, ce fichier doit le relire — sinon exporter puis réimporter
// perd des valeurs, et c'est le premier geste que fera un utilisateur qui déplace son
// catalogue.
//
// **Rien de silencieux.** Chaque fonction rend un optionnel, et l'appelant en fait un refus
// nommé. Un `?? 0` ici écrirait une durée de zéro minute sur une cellule fautive, et
// personne ne le verrait jamais.

/// Convertit une cellule de CSV en valeur du modèle.
public enum CSVValueParser {

    /// Les formes de « vrai » et de « faux » qu'un tableur écrit.
    ///
    /// Notre export écrit `oui` / `non`. Les autres formes viennent des fichiers étrangers :
    /// un export anglophone écrit `yes`, une formule Excel écrit `VRAI`, un script écrit
    /// `1`. Toutes repliées, donc insensibles à la casse et aux accents.
    static let trueValues = ["oui", "o", "yes", "y", "true", "vrai", "1", "x"]
    static let falseValues = ["non", "n", "no", "false", "faux", "0", ""]

    public static func boolean(_ value: String) -> Bool? {
        let key = value.foldedForMatching.trimmingCharacters(in: .whitespaces)
        if trueValues.contains(key) { return true }
        if falseValues.contains(key) { return false }
        return nil
    }

    /// Une date `AAAA-MM-JJ`.
    ///
    /// **Seule cette forme est acceptée, et `JJ/MM/AAAA` est refusé exprès.** `02/04/2019`
    /// est le 2 avril pour un tableur français et le 4 février pour un tableur américain :
    /// choisir, c'est se tromper une fois sur deux sans jamais le signaler. Un refus nommé
    /// dit quoi faire — « attendu au format AAAA-MM-JJ » — et l'utilisateur reformate sa
    /// colonne en une manipulation.
    ///
    /// Fuseau courant, comme `CSVExporter.dateStyle` : les deux doivent se répondre, sinon
    /// exporter puis réimporter décale les dates d'un jour.
    public static func date(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespaces)
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // `date(from:)` accepte un 31 février en le reportant sur mars. La date reconstruite
        // est donc recomparée à ses composantes : sans ça, une faute de frappe deviendrait
        // une date valide mais fausse, ce qui est exactement le genre de silence qu'on
        // refuse ailleurs.
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
            calendar.component(.day, from: date) == day,
            calendar.component(.month, from: date) == month
        else { return nil }
        return date
    }

    /// Une année, en chiffres ou déduite d'une date complète.
    ///
    /// La fiche du champ le dit : « L'année de sortie. Une date complète est acceptée. »
    /// L'année se lit alors dans le fuseau courant, comme `Title.releaseYear`.
    ///
    /// **Aucune contrainte de longueur ici, et un test l'a imposé.** Exiger quatre chiffres
    /// faisait refuser `20211` — la faute de frappe la plus banale sur une année — comme
    /// « attendu en chiffres », alors que c'en est un. Le message était donc faux, et
    /// inactionnable : l'utilisateur relit sa cellule, y voit des chiffres, et ne comprend
    /// pas. Le nombre est lu, puis borné par `CatalogBounds.years`, ce qui produit
    /// « Année attendu entre 1888 et 2030. Trouvé « 20211 » » — la cause « Année hors
    /// bornes » de la planche 11e, avec de quoi agir.
    ///
    /// La reconnaissance de colonne, elle, garde sa règle des quatre chiffres
    /// (`CSVValueSniffer.isYear`) : reconnaître une colonne et valider une cellule ne
    /// demandent pas la même sévérité — la première choisit un champ, la seconde accuse.
    public static func year(_ value: String) -> Int? {
        let text = value.trimmingCharacters(in: .whitespaces)
        if let number = Int(text) { return number }
        guard let date = date(text) else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    public static func integer(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespaces))
    }

    /// Un nombre décimal, virgule **ou** point.
    ///
    /// L'export écrit un point (voir `CSVExporter.decimal`), mais un utilisateur qui saisit
    /// une note dans Excel en français tape une virgule. Refuser `8,4` obligerait à
    /// reformater une colonne pour un caractère.
    ///
    /// `Double(_:)` et non un `NumberFormatter` : le formateur dépend de la locale, donc le
    /// même fichier se lirait différemment selon l'appareil — la classe de bug que le
    /// repliage invariant a fermée ailleurs.
    public static func decimal(_ value: String) -> Double? {
        let text = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty, text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) else {
            return nil
        }
        return Double(text)
    }

    /// Une valeur d'un vocabulaire fermé, repliée des deux côtés.
    ///
    /// Le vocabulaire vient de `CSVField.allowedValues`, donc du modèle : `TitleKind` et
    /// `PersonRole` gagneront des cas sans qu'aucune liste ne soit à mettre à jour ici.
    ///
    /// Les libellés français sont acceptés en plus des `rawValue` : notre export écrit
    /// `movie`, mais un fichier fait à la main écrit « film ». La table de synonymes est
    /// volontairement courte — un synonyme absent est un refus nommé, pas une erreur
    /// silencieuse.
    public static func enumerated(_ value: String, allowedValues: [String]) -> String? {
        let key = value.foldedForMatching.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        if let exact = allowedValues.first(where: { $0.foldedForMatching == key }) { return exact }
        guard let target = synonyms[key] else { return nil }
        return allowedValues.first { $0 == target }
    }

    /// Les libellés français des vocabulaires fermés.
    ///
    /// Clés repliées. Elles couvrent `TitleKind` et `PersonRole`, les deux seules
    /// énumérations qu'un schéma de colonnes expose aujourd'hui.
    static let synonyms: [String: String] = [
        "film": "movie", "serie": "series", "documentaire": "documentary",
        "court metrage": "short", "court-metrage": "short", "autre": "other",
        "acteur": "actor", "actrice": "actor", "interpretation": "actor",
        "realisateur": "director", "realisatrice": "director", "realisation": "director",
        "scenariste": "writer", "scenario": "writer", "ecriture": "writer",
        "equipe": "crew", "technicien": "crew", "social": "social"
    ]
}
