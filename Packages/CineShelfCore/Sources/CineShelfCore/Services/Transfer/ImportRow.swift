import Foundation

// MARK: - Une ligne de fichier, et rien qui la double
//
// Ce fichier existe parce que la ligne d'import a une **structure** à défendre, et qu'elle se
// noyait dans la validation. La leçon est datée : `cells` et `rawFields` ont coexisté une
// journée, et cette journée a suffi pour qu'une correction de masse s'écrive dans l'un sans
// l'autre — 214 corrections perdues sans un mot. Ce n'est pas un oubli d'écriture, c'est une
// propriété de la forme : deux stockages des mêmes valeurs finissent par diverger.

/// Où chaque champ retenu se lit dans une ligne du fichier.
///
/// Extrait de `ColumnAnalysis` une fois, puis porté par chaque `ImportRow` : c'est ce qui
/// permet à une ligne de projeter ses propres cellules sans que personne ne lui passe un
/// index — donc sans que personne ne puisse lui en passer un faux.
public struct ColumnLayout: Sendable, Hashable {

    /// Clé de champ → position dans le fichier.
    let indexByField: [String: Int]

    public init(indexByField: [String: Int]) {
        self.indexByField = indexByField
    }

    public init(_ analysis: ColumnAnalysis) {
        var map: [String: Int] = [:]
        for match in analysis.matches {
            guard let key = match.fieldKey else { continue }
            map[key] = match.columnIndex
        }
        self.init(indexByField: map)
    }

    /// La position de la colonne qui alimente ce champ, `nil` si aucune ne le fait.
    public func index(of fieldKey: String) -> Int? { indexByField[fieldKey] }

    /// Les clés de champ alimentées par une colonne.
    public var mappedFieldKeys: [String] { indexByField.keys.sorted() }
}

/// Une ligne de fichier, ses cellules rangées par champ, et ses refus.
///
/// **Une seule source de vérité : `rawFields`.** La première version stockait `cells` **et**
/// `rawFields` côte à côte, et c'est ce qui a produit le défaut le plus coûteux de `L11a` —
/// une correction écrite dans l'un et pas dans l'autre, donc 214 corrections perdues sans un
/// mot dans le fichier de reprise. Le correctif d'alors écrivait les deux ; il traitait le
/// symptôme. La structure restait deux stockages qu'aucune règle n'obligeait à s'accorder :
/// l'initialiseur public acceptait n'importe quelle paire incohérente, et l'appelant
/// calculait lui-même l'index de colonne — un index faux les désaccordait en silence.
///
/// Ici `cells` est **calculé** depuis `rawFields` à travers `layout`. Les deux ne peuvent
/// plus diverger parce qu'il n'y a plus deux choses.
public struct ImportRow: Sendable, Hashable, Identifiable {

    /// Le numéro de ligne **dans le fichier**, en-tête comprise — celui du tableur.
    public let number: Int
    /// La ligne telle qu'elle a été lue, colonnes ignorées comprises. **La source.**
    ///
    /// Le rapport redéposable la rend au fichier, augmentée d'une colonne d'erreur : il a donc
    /// besoin des cellules qu'aucun champ ne réclame, et c'est aussi pourquoi c'est elle qui
    /// porte les corrections.
    public let rawFields: [String]
    /// Où lire chaque champ dans `rawFields`.
    public let layout: ColumnLayout
    /// Les valeurs décidées pour des champs qu'**aucune colonne** n'alimente.
    ///
    /// C'est « Saisir une année pour toutes » de la planche 11f sur un fichier sans colonne
    /// d'année : la valeur existe pour l'import, mais le fichier ne l'a jamais portée et n'a
    /// donc pas à la porter au retour. Ce n'est pas un second stockage des mêmes valeurs — un
    /// champ est dans `layout` **ou** ici, jamais dans les deux, et `settingCell` maintient
    /// cette exclusion.
    public let overrides: [String: String]
    public let issues: [ImportIssue]

    public var id: Int { number }
    public var isReady: Bool { issues.isEmpty }

    public init(
        number: Int,
        rawFields: [String],
        layout: ColumnLayout,
        overrides: [String: String] = [:],
        issues: [ImportIssue] = []
    ) {
        self.number = number
        self.rawFields = rawFields
        self.layout = layout
        self.overrides = overrides
        self.issues = issues
    }

    /// La valeur d'un champ, projetée depuis la ligne.
    ///
    /// Le chemin chaud : la validation appelle ceci une fois par champ et par ligne. Lire
    /// directement plutôt que construire `cells` évite un dictionnaire par accès — sur 1 284
    /// lignes de quatorze colonnes, la différence est de dix-huit mille dictionnaires.
    ///
    /// Une ligne trop courte — c'est un des refus possibles — rend `nil` plutôt que de faire
    /// déborder l'index.
    public func cell(_ fieldKey: String) -> String? {
        if let index = layout.index(of: fieldKey) {
            return index < rawFields.count ? rawFields[index] : nil
        }
        return overrides[fieldKey]
    }

    /// Toutes les cellules retenues, par clé de champ. **Calculé, jamais stocké.**
    public var cells: [String: String] {
        var result = overrides
        for key in layout.mappedFieldKeys {
            guard let value = cell(key) else { continue }
            result[key] = value
        }
        return result
    }

    /// La même ligne, une cellule remplacée.
    ///
    /// La valeur va dans `rawFields` si une colonne alimente ce champ, sinon dans `overrides`.
    /// **L'appelant ne choisit pas** : c'est `layout` qui tranche, et c'est ce qui rend
    /// l'incohérence impossible plutôt que seulement corrigée. La version précédente prenait un
    /// `columnIndex` calculé par l'appelant — un index faux écrivait alors dans la mauvaise
    /// colonne du fichier de reprise.
    ///
    /// - Returns: la ligne corrigée. Ses refus sont inchangés — c'est à l'appelant de la
    ///   revalider, parce qu'une correction peut en découvrir une autre.
    func settingCell(_ value: String, forKey key: String) -> ImportRow {
        guard let index = layout.index(of: key) else {
            var updatedOverrides = overrides
            updatedOverrides[key] = value
            return ImportRow(
                number: number, rawFields: rawFields, layout: layout,
                overrides: updatedOverrides, issues: issues)
        }
        guard index < rawFields.count else { return self }

        var updatedFields = rawFields
        updatedFields[index] = value
        return ImportRow(
            number: number, rawFields: updatedFields, layout: layout,
            overrides: overrides, issues: issues)
    }

    func settingIssues(_ issues: [ImportIssue]) -> ImportRow {
        ImportRow(
            number: number, rawFields: rawFields, layout: layout,
            overrides: overrides, issues: issues)
    }
}
