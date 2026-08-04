import Foundation

// MARK: - Les colonnes sont une donnée, pas une vue
//
// La fiche l'exige mot pour mot : « la liste des champs exportables est une **donnée**,
// pas une vue ». Conséquence concrète : l'écran d'export ne connaît aucune colonne, il
// parcourt `CSVSchema.title.fields` et coche. Ajouter une colonne exportable est une ligne
// ici, et aucune modification d'interface.
//
// **Les clés sont stables et ne se renomment pas.** Elles voyagent dans
// `ImportMapping.columnMapData`, une entité synchronisée par CloudKit : renommer `runtime`
// en `duration` casserait toutes les correspondances déjà mémorisées, sur tous les
// appareils, sans le moindre signal. L'en-tête lisible, lui, peut changer librement — c'est
// du texte pour un tableur.

/// Un champ exportable d'une entité.
public struct CSVField: Sendable, Hashable, Identifiable {

    /// La clé stable. **Ne jamais renommer** : elle est persistée dans les correspondances.
    public let key: String
    /// L'en-tête écrit dans le fichier. Modifiable sans casser l'existant.
    public let header: String
    /// Ce que la colonne contient, en une ligne, pour l'écran de sélection.
    public let help: String
    /// `true` si l'import ne peut rien faire d'une ligne sans cette colonne.
    public let isRequiredForImport: Bool
    /// `true` si la colonne est proposée par défaut à l'export.
    public let isDefaultForExport: Bool

    public var id: String { key }

    public init(
        key: String,
        header: String,
        help: String,
        isRequiredForImport: Bool = false,
        isDefaultForExport: Bool = true
    ) {
        self.key = key
        self.header = header
        self.help = help
        self.isRequiredForImport = isRequiredForImport
        self.isDefaultForExport = isDefaultForExport
    }
}

/// Le schéma de colonnes d'une entité.
public struct CSVSchema: Sendable, Hashable {

    /// L'entité décrite. Sert au libellé et au nom de fichier proposé.
    public let entity: ActivityEntityType
    public let fields: [CSVField]

    public init(entity: ActivityEntityType, fields: [CSVField]) {
        self.entity = entity
        self.fields = fields
    }

    /// Les champs sans lesquels une ligne d'import n'a pas de sens.
    public var requiredFields: [CSVField] { fields.filter(\.isRequiredForImport) }
    /// La sélection proposée à l'ouverture de l'écran d'export.
    public var defaultExportFields: [CSVField] { fields.filter(\.isDefaultForExport) }

    public func field(forKey key: String) -> CSVField? {
        fields.first { $0.key == key }
    }

    /// L'en-tête d'un fichier, pour une sélection de clés.
    ///
    /// Les clés inconnues sont ignorées plutôt que de produire une colonne vide sans nom :
    /// une sélection venue d'une version antérieure peut citer un champ qui n'existe plus.
    public func header(for keys: [String]) -> [String] {
        keys.compactMap { field(forKey: $0)?.header }
    }
}

// MARK: - Les deux schémas
//
// `Title` et `Person`, le même périmètre que `L10` — les deux seules entités qui portent
// `filterKeys`, des relations dénormalisées et un volume réel. Les autres viendront quand
// un besoin réel se présentera, pas « au cas où ».

extension CSVSchema {

    public static let title = CSVSchema(
        entity: .title,
        fields: [
            CSVField(
                key: "title", header: "Titre",
                help: "Le nom du film ou de la série.",
                isRequiredForImport: true),
            CSVField(
                key: "original_title", header: "Titre original",
                help: "Le titre dans sa langue d'origine, s'il diffère."),
            CSVField(
                key: "kind", header: "Type",
                help: "Film ou série."),
            CSVField(
                key: "year", header: "Année",
                help: "L'année de sortie. Une date complète est acceptée."),
            CSVField(
                key: "release_date", header: "Date de sortie",
                help: "La date exacte, si elle est connue au jour près.",
                isDefaultForExport: false),
            CSVField(
                key: "runtime", header: "Durée · minutes",
                help: "En minutes, nombre entier."),
            CSVField(
                key: "rating", header: "Note · sur 10",
                help: "De 0 à 10, décimales acceptées."),
            CSVField(
                key: "summary", header: "Résumé",
                help: "Texte libre."),
            CSVField(
                key: "collection", header: "Collection",
                help: "Le nom de la collection. Elle est créée si elle n'existe pas."),
            CSVField(
                key: "genres", header: "Genres",
                help: "Plusieurs genres séparés par une barre oblique : action/thriller."),
            CSVField(
                key: "season_count", header: "Saisons",
                help: "Pour une série.",
                isDefaultForExport: false),
            CSVField(
                key: "episode_count", header: "Épisodes",
                help: "Pour une série.",
                isDefaultForExport: false),
            CSVField(
                key: "is_private", header: "Privé",
                help: "oui ou non.",
                isDefaultForExport: false),
            CSVField(
                key: "is_archived", header: "Archivé",
                help: "oui ou non.",
                isDefaultForExport: false)
        ]
    )

    public static let person = CSVSchema(
        entity: .person,
        fields: [
            CSVField(
                key: "first_name", header: "Prénom",
                help: "Le prénom. Vide pour un nom unique.",
                isDefaultForExport: true),
            CSVField(
                key: "last_name", header: "Nom",
                help: "Le nom de famille, ou le nom unique.",
                isRequiredForImport: true),
            CSVField(
                key: "roles", header: "Rôles",
                help: "Plusieurs rôles séparés par une barre oblique : interprétation/réalisation."),
            CSVField(
                key: "birth_date", header: "Naissance",
                help: "Date, au format AAAA-MM-JJ."),
            CSVField(
                key: "death_date", header: "Décès",
                help: "Date, au format AAAA-MM-JJ."),
            CSVField(
                key: "bio", header: "Biographie",
                help: "Texte libre."),
            CSVField(
                key: "genres", header: "Genres",
                help: "Plusieurs genres séparés par une barre oblique.",
                isDefaultForExport: false),
            CSVField(
                key: "is_private", header: "Privé",
                help: "oui ou non.",
                isDefaultForExport: false),
            CSVField(
                key: "is_archived", header: "Archivé",
                help: "oui ou non.",
                isDefaultForExport: false)
        ]
    )

    /// Les schémas connus, pour qu'un écran puisse les énumérer.
    public static let all: [CSVSchema] = [.title, .person]

    public static func schema(for entity: ActivityEntityType) -> CSVSchema? {
        all.first { $0.entity == entity }
    }
}

// MARK: - Le séparateur de valeurs multiples
//
// Une barre oblique, et pas une virgule ni un point-virgule : la virgule est le séparateur
// décimal en locale française, le point-virgule est déjà le séparateur de colonnes. Un
// genre nommé « action/aventure » serait coupé en deux — c'est le prix, et il est plus
// faible que celui d'une collision avec le séparateur de champs.

extension CSVSchema {
    /// Sépare les valeurs multiples à l'intérieur d'une cellule.
    public static let multiValueSeparator: Character = "/"

    /// Découpe une cellule multivaleur, en retirant les vides et les espaces de bord.
    public static func splitMultiValue(_ text: String) -> [String] {
        text.split(separator: multiValueSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Joint des valeurs multiples pour une cellule.
    public static func joinMultiValue(_ values: [String]) -> String {
        values.joined(separator: String(multiValueSeparator))
    }
}
