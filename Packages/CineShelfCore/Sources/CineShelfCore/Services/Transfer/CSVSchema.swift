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

/// Ce qu'une cellule doit contenir.
///
/// **Portée par le champ, et lue par deux clients.** La déduction de correspondance s'en
/// sert pour reconnaître une colonne à son **contenu** — quatre chiffres dans 1888…2030 est
/// une année, quoi que dise l'en-tête — et la validation s'en sert pour convertir la cellule
/// et nommer le refus. Une seule déclaration pour les deux : si elles divergeaient, une
/// colonne serait reconnue comme une année puis refusée parce qu'elle n'en est pas une.
public enum CSVValueShape: String, Sendable, Hashable, CaseIterable {
    /// Texte libre. Ne se déduit jamais du contenu : tout est du texte.
    case text
    /// Plusieurs valeurs dans une cellule, séparées par `CSVSchema.multiValueSeparator`.
    case multiValue
    /// Une année sur quatre chiffres. Une date complète est acceptée à la validation.
    case year
    /// Une date `AAAA-MM-JJ`.
    case date
    /// Un entier positif.
    case integer
    /// Un nombre, décimales acceptées.
    case decimal
    /// `oui` / `non`, et les formes que les tableurs écrivent.
    case boolean
    /// Une valeur d'énumération fermée : type de titre, rôles.
    case enumerated
}

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

    /// Les autres noms sous lesquels cette colonne se rencontre dans un fichier étranger.
    ///
    /// **Une donnée, et c'est la raison d'être de ce champ.** L'arbitrage du 2026-08-04 a
    /// refusé de livrer un profil Movix intégré — le script source est inaccessible, et un
    /// profil `isBuiltIn` faux ne se retire plus. Restait le besoin qu'il servait :
    /// reconnaître `runtime_min` ou `my_score` sans que l'utilisateur ait à le dire. Des
    /// alias par champ le couvrent, sans figer un profil entier : ils produisent une
    /// correspondance **déduite**, que l'écran montre comme telle et qui se corrige.
    ///
    /// Repliés à la comparaison, jamais comparés tels quels — voir `ColumnMatcher`.
    public let aliases: [String]

    /// Ce que la cellule doit contenir.
    public let shape: CSVValueShape
    /// Les bornes de la valeur, quand elle en a. Source : `CatalogBounds`.
    public let range: ClosedRange<Double>?
    /// Le vocabulaire fermé, quand le champ en a un.
    ///
    /// Une **donnée** et non un `switch` dans le validateur : `TitleKind` et `PersonRole`
    /// gagneront des cas, et un `switch` oublié refuserait à l'import une valeur que le
    /// modèle accepte. Vide = pas de vocabulaire, la valeur est libre.
    public let allowedValues: [String]

    public var id: String { key }

    /// `true` si la cellule peut porter plusieurs valeurs.
    public var isMultiValue: Bool { shape == .multiValue }

    public init(
        key: String,
        header: String,
        help: String,
        isRequiredForImport: Bool = false,
        isDefaultForExport: Bool = true,
        aliases: [String] = [],
        shape: CSVValueShape = .text,
        range: ClosedRange<Double>? = nil,
        allowedValues: [String] = []
    ) {
        self.key = key
        self.header = header
        self.help = help
        self.isRequiredForImport = isRequiredForImport
        self.isDefaultForExport = isDefaultForExport
        self.aliases = aliases
        self.shape = shape
        self.range = range
        self.allowedValues = allowedValues
    }
}

extension ClosedRange where Bound == Int {
    /// La même borne, en `Double`, pour un `CSVField.range`.
    ///
    /// Les bornes du catalogue sont entières là où la valeur l'est (année, minutes) et
    /// décimale pour la note. Un seul type dans `CSVField` évite deux chemins de validation
    /// dont l'un finirait moins couvert que l'autre.
    var asDouble: ClosedRange<Double> { Double(lowerBound)...Double(upperBound) }
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
                isRequiredForImport: true,
                aliases: ["title", "name", "nom", "film", "movie", "titre du film"]),
            CSVField(
                key: "original_title", header: "Titre original",
                help: "Le titre dans sa langue d'origine, s'il diffère.",
                aliases: ["original_title", "original title", "titre vo", "vo"]),
            CSVField(
                key: "kind", header: "Type",
                help: "Film ou série.",
                aliases: ["kind", "type", "categorie", "category", "format"],
                shape: .enumerated,
                allowedValues: TitleKind.allCases.map(\.rawValue)),
            CSVField(
                key: "year", header: "Année",
                help: "L'année de sortie. Une date complète est acceptée.",
                aliases: ["year", "annee", "sortie", "release_year"],
                shape: .year,
                range: CatalogBounds.years.asDouble),
            CSVField(
                key: "release_date", header: "Date de sortie",
                help: "La date exacte, si elle est connue au jour près.",
                isDefaultForExport: false,
                aliases: ["release_date", "release date", "date sortie"],
                shape: .date),
            CSVField(
                key: "runtime", header: "Durée · minutes",
                help: "En minutes, nombre entier.",
                aliases: ["runtime", "runtime_min", "duree", "duration", "minutes", "length"],
                shape: .integer,
                range: CatalogBounds.runtimeMinutes.asDouble),
            CSVField(
                key: "rating", header: "Note · sur 10",
                help: "De 0 à 10, décimales acceptées.",
                aliases: ["rating", "note", "score", "my_score", "ma note"],
                shape: .decimal,
                range: CatalogBounds.ratings),
            CSVField(
                key: "summary", header: "Résumé",
                help: "Texte libre.",
                aliases: ["summary", "resume", "synopsis", "overview", "description"]),
            CSVField(
                key: "collection", header: "Collection",
                help: "Le nom de la collection. Elle est créée si elle n'existe pas.",
                aliases: ["collection", "saga", "serie de films", "franchise"]),
            CSVField(
                key: "genres", header: "Genres",
                help: "Plusieurs genres séparés par une barre oblique : action/thriller.",
                aliases: ["genres", "genre", "genre_raw", "categories", "tags"],
                shape: .multiValue),
            CSVField(
                key: "director", header: "Réalisation",
                help: "Une ou plusieurs personnes séparées par une barre oblique.",
                aliases: ["director", "directors", "dir", "realisation", "realisateur", "mise en scene"],
                shape: .multiValue),
            CSVField(
                key: "cast", header: "Distribution",
                help: "Les interprètes, séparés par une barre oblique, dans l'ordre du générique.",
                aliases: ["cast", "cast_1", "actors", "acteurs", "distribution", "interpretes"],
                shape: .multiValue),
            CSVField(
                key: "added_at", header: "Ajouté le",
                help: "La date d'ajout au catalogue, au format AAAA-MM-JJ.",
                isDefaultForExport: false,
                aliases: ["added", "added_at", "date_added", "ajoute le", "ajout"],
                shape: .date),
            CSVField(
                key: "season_count", header: "Saisons",
                help: "Pour une série.",
                isDefaultForExport: false,
                aliases: ["seasons", "season_count", "saisons", "nb saisons"],
                shape: .integer,
                range: CatalogBounds.seasonCount.asDouble),
            CSVField(
                key: "episode_count", header: "Épisodes",
                help: "Pour une série.",
                isDefaultForExport: false,
                aliases: ["episodes", "episode_count", "nb episodes"],
                shape: .integer,
                range: CatalogBounds.episodeCount.asDouble),
            CSVField(
                key: "is_private", header: "Privé",
                help: "oui ou non.",
                isDefaultForExport: false,
                aliases: ["private", "is_private", "prive", "masque"],
                shape: .boolean),
            CSVField(
                key: "is_archived", header: "Archivé",
                help: "oui ou non.",
                isDefaultForExport: false,
                aliases: ["archived", "is_archived", "archive"],
                shape: .boolean)
        ]
    )

    public static let person = CSVSchema(
        entity: .person,
        fields: [
            CSVField(
                key: "first_name", header: "Prénom",
                help: "Le prénom. Vide pour un nom unique.",
                isDefaultForExport: true,
                aliases: ["first_name", "firstname", "prenom", "given name"]),
            CSVField(
                key: "last_name", header: "Nom",
                help: "Le nom de famille, ou le nom unique.",
                isRequiredForImport: true,
                aliases: ["last_name", "lastname", "nom", "name", "surname", "family name"]),
            CSVField(
                key: "roles", header: "Rôles",
                help: "Plusieurs rôles séparés par une barre oblique : interprétation/réalisation.",
                aliases: ["roles", "role", "fonction", "metier"],
                shape: .multiValue,
                allowedValues: PersonRole.allCases.map(\.rawValue)),
            CSVField(
                key: "birth_date", header: "Naissance",
                help: "Date, au format AAAA-MM-JJ.",
                aliases: ["birth_date", "birthdate", "naissance", "date de naissance", "born"],
                shape: .date),
            CSVField(
                key: "death_date", header: "Décès",
                help: "Date, au format AAAA-MM-JJ.",
                aliases: ["death_date", "deathdate", "deces", "date de deces", "died"],
                shape: .date),
            CSVField(
                key: "bio", header: "Biographie",
                help: "Texte libre.",
                aliases: ["bio", "biographie", "biography", "description"]),
            CSVField(
                key: "genres", header: "Genres",
                help: "Plusieurs genres séparés par une barre oblique.",
                isDefaultForExport: false,
                aliases: ["genres", "genre", "genre_raw", "tags"],
                shape: .multiValue),
            CSVField(
                key: "is_private", header: "Privé",
                help: "oui ou non.",
                isDefaultForExport: false,
                aliases: ["private", "is_private", "prive"],
                shape: .boolean),
            CSVField(
                key: "is_archived", header: "Archivé",
                help: "oui ou non.",
                isDefaultForExport: false,
                aliases: ["archived", "is_archived", "archive"],
                shape: .boolean)
        ]
    )

    /// Les schémas connus, pour qu'un écran puisse les énumérer.
    public static let all: [CSVSchema] = [.title, .person]

    public static func schema(for entity: ActivityEntityType) -> CSVSchema? {
        all.first { $0.entity == entity }
    }
}

// MARK: - Le séparateur de valeurs multiples, et son échappement
//
// **Deux passes de correction, et la première ne suffisait pas.** Le 2026-08-06, le
// séparateur est passé de `/` à `|` parce qu'un genre nommé « Action/Aventure » se coupait
// en deux à l'aller-retour. Le format était alors *plus sûr*, pas **sûr** : la garantie
// reposait sur « aucun nom ne porte de barre verticale », qui est une probabilité et non une
// invariante. Un séparateur non échappé n'est pas un séparateur, c'est un pari.
//
// Ce fichier tient donc l'invariant plutôt que de l'espérer :
//
//     splitMultiValue(joinMultiValue(x)) == x
//
// pour **toute** liste `x` dont les valeurs sont normalisées — non vides et sans espace de
// bord. La restriction n'est pas une échappatoire : `splitMultiValue` retire les vides et les
// espaces de bord **exprès**, c'est une normalisation d'entrée dont `ImportValidation` dépend
// (une cellule `« | »` doit se lire « aucune valeur », pas « deux valeurs vides »). L'écrire
// dans l'invariant est ce qui distingue une normalisation voulue d'une perte de donnée — les
// confondre aurait produit un test qui exige une propriété fausse.

extension CSVSchema {
    /// Le séparateur de valeurs multiples dans une cellule.
    ///
    /// > **Corrigé le 2026-08-06 : c'était `/`, et l'aller-retour détruisait des genres.**
    /// > Mesuré par une sonde d'import de bout en bout — la première à jouer la couture entre
    /// > l'export et l'import : un genre nommé `Action/Aventure` s'exportait dans une liste
    /// > jointe par `/` et se réimportait en **deux** genres, `Action` et `Aventure`. Le genre
    /// > d'origine disparaissait, sans un mot, et rien ne pouvait le voir — les deux moitiés
    /// > étaient cohérentes **entre elles**.
    /// >
    /// > La barre verticale est aussi ce que l'échantillon d'export de la planche 5 écrit :
    /// > `"Science-fiction|Aventure"`. Elle n'apparaît pratiquement jamais dans un nom de
    /// > genre, là où la barre oblique y est courante — « Action/Aventure », « Science-fiction
    /// > / Fantastique ».
    public static let multiValueSeparator: Character = "|"

    /// Le caractère qui neutralise le suivant.
    ///
    /// Un antislash, comme dans à peu près tous les formats textuels : c'est la convention que
    /// le lecteur d'un CSV ouvert dans un éditeur reconnaîtra sans explication. Le CSV lui-même
    /// échappe déjà ses guillemets, par doublement — le doublement était donc le candidat
    /// naturel, et il est **impossible ici** : `« a||b »` signifie déjà « une valeur vide entre
    /// deux séparateurs », et cette lecture est celle dont `ImportValidation` dépend.
    public static let multiValueEscape: Character = "\\"

    /// Découpe une cellule multivaleur, en retirant les vides et les espaces de bord.
    ///
    /// Un séparateur précédé de l'échappement est une **donnée**, pas une coupure. Le parcours
    /// est fait caractère par caractère plutôt que par `split(separator:)` : `split` ne sait pas
    /// regarder derrière lui, et c'est précisément ce qu'il faut ici.
    ///
    /// **Rétrocompatible avec les fichiers antérieurs**, et ce n'est pas un hasard : un `|` qui
    /// n'est pas précédé d'un antislash sépare toujours, donc un export d'une version antérieure
    /// se relit à l'identique. Seule une valeur portant un antislash **juste avant** un `|` se
    /// lit autrement qu'avant, et elle se lisait déjà faux.
    public static func splitMultiValue(_ text: String) -> [String] {
        var values: [String] = []
        var current = ""
        var escaping = false
        for character in text {
            if escaping {
                // Un échappement devant un caractère ordinaire se rend tel quel plutôt que
                // d'être avalé : un fichier écrit à la main par un utilisateur qui a tapé
                // `C:\Films` ne doit pas perdre son antislash pour avoir été relu ici.
                if character != multiValueSeparator && character != multiValueEscape {
                    current.append(multiValueEscape)
                }
                current.append(character)
                escaping = false
            } else if character == multiValueEscape {
                escaping = true
            } else if character == multiValueSeparator {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        // Un antislash isolé en fin de cellule n'échappe rien : il se rend, plutôt que de
        // disparaître. C'est la même règle que ci-dessus, appliquée au bord.
        if escaping { current.append(multiValueEscape) }
        values.append(current)
        return
            values
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Joint des valeurs multiples pour une cellule, en échappant ce qui doit l'être.
    ///
    /// **L'échappement porte sur l'antislash avant le séparateur**, et l'ordre n'est pas
    /// interchangeable : échapper le séparateur d'abord introduirait des antislashs que la
    /// seconde passe redoublerait, et `A|B` sortirait en `A\\|B`, donc se relirait en deux
    /// valeurs `A\` et `B`.
    public static func joinMultiValue(_ values: [String]) -> String {
        values.map(escapedForCell).joined(separator: String(multiValueSeparator))
    }

    /// Une valeur, prête à cohabiter avec ses voisines dans une cellule.
    public static func escapedForCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: String(multiValueEscape), with: String(repeating: multiValueEscape, count: 2))
            .replacingOccurrences(
                of: String(multiValueSeparator),
                with: String(multiValueEscape) + String(multiValueSeparator))
    }

    /// La valeur porte-t-elle un caractère que l'écriture en cellule doit neutraliser ?
    ///
    /// Sert à **le dire** : l'export nomme les valeurs qu'il a dû échapper. L'invariant tient
    /// sans cet avertissement — il n'est pas une condition de correction — mais un fichier qui
    /// part avec des séquences d'échappement dedans est un fichier que l'utilisateur doit savoir
    /// reconnaître s'il le retraite avec un autre outil que CineShelf.
    public static func needsCellEscaping(_ value: String) -> Bool {
        value.contains(multiValueSeparator) || value.contains(multiValueEscape)
    }
}
