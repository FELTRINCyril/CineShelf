import Foundation

// MARK: - Faire correspondre les colonnes d'un fichier aux champs de CineShelf
//
// L'étape 1 de l'import (planche 11d de l'addendum), et **aucune écriture** : ce fichier
// ne connaît ni `ModelContext` ni `@Model`. C'est ce qui permet de le tester entièrement
// sans magasin, et c'est la frontière que la coupe `L11a` / `L11b` a choisie.
//
// Trois qualités de correspondance, et la troisième n'est pas une erreur — la planche le
// dit mot pour mot : « Elles ne sont pas une erreur : par défaut elles sont ignorées, et
// l'import peut avancer sans y toucher. »

/// À quel point une correspondance colonne → champ est certaine.
///
/// Un `enum` et non un booléen « sûre / pas sûre » : l'écran affiche trois marques
/// distinctes, et l'utilisateur ne relit pas les mêmes. Une correspondance **sûre** ne
/// demande rien, une **déduite** demande un coup d'œil, une colonne **non reconnue** est
/// une information à ne pas perdre.
public enum ColumnMatchQuality: String, Sendable, Hashable, CaseIterable {
    /// Le nom de colonne est l'en-tête ou la clé du champ, au repliage près.
    case certain
    /// Déduite d'un alias ou du contenu des premières valeurs. À vérifier.
    case inferred
    /// Aucun champ ne correspond. Ignorée par défaut, et **nommée** dans le rapport.
    case unrecognized

    /// Le libellé montré à côté de la colonne. Dans le modèle et non dans une vue :
    /// même motif que `PersonRole.label`, `CineShelfCore` n'importe pas SwiftUI.
    public var label: String {
        switch self {
        case .certain: "sûre"
        case .inferred: "déduite"
        case .unrecognized: "ignorée"
        }
    }
}

/// Une colonne du fichier, et le champ qu'elle alimente — ou rien.
public struct ColumnMatch: Sendable, Hashable, Identifiable {

    /// La position dans le fichier, à partir de 0.
    ///
    /// C'est elle qui sert à lire la cellule, et non le nom : deux colonnes peuvent
    /// porter le même nom dans un export bancal, et lire par nom en perdrait une.
    public let columnIndex: Int
    /// Le nom de colonne, tel qu'il est écrit dans le fichier.
    public let columnName: String
    /// La clé du champ visé, `nil` si la colonne n'est pas reconnue.
    public let fieldKey: String?
    public let quality: ColumnMatchQuality
    /// Ce qui a produit la déduction, pour que l'écran puisse le dire. `nil` si sûre.
    public let rationale: String?

    public var id: Int { columnIndex }
    public var isMapped: Bool { fieldKey != nil }

    public init(
        columnIndex: Int,
        columnName: String,
        fieldKey: String?,
        quality: ColumnMatchQuality,
        rationale: String? = nil
    ) {
        self.columnIndex = columnIndex
        self.columnName = columnName
        self.fieldKey = fieldKey
        self.quality = quality
        self.rationale = rationale
    }
}

// MARK: - La correspondance, telle qu'elle se mémorise

/// La correspondance complète d'un fichier, sérialisable.
///
/// **Versionnée dès la première livraison**, sur le patron de `BulkEditDiff` : elle part
/// dans `ImportMapping.columnMapData`, une entité synchronisée par CloudKit. Un `payload`
/// déjà écrit ne se relit pas autrement, et une version inconnue se **refuse** plutôt que
/// se devine — un mappage mal deviné écrit les mauvaises colonnes dans les mauvais champs,
/// et rien ne le signale.
///
/// Ce qui est mémorisé est la décision de l'utilisateur — `nom de colonne → clé de champ`
/// — et non le résultat de la déduction. La déduction se refait, une décision non.
public struct ColumnMapping: Sendable, Hashable, Codable {

    /// La version du format sérialisé. À incrémenter à **toute** modification de forme.
    public static let currentVersion = 1

    public let version: Int
    /// L'entité visée. Une correspondance de titres ne s'applique pas à des personnes.
    public let entity: ActivityEntityType
    /// Nom de colonne du fichier → clé de champ. Les colonnes ignorées en sont absentes.
    public let columnToField: [String: String]

    public init(
        version: Int = Self.currentVersion,
        entity: ActivityEntityType,
        columnToField: [String: String]
    ) {
        self.version = version
        self.entity = entity
        self.columnToField = columnToField
    }

    /// La correspondance déduite d'une liste de rapprochements.
    ///
    /// **Deux colonnes de même nom rendent une correspondance impossible à mémoriser**, et la
    /// première version en perdait une en silence. `ColumnMatch` documente pourtant le cas :
    /// « deux colonnes peuvent porter le même nom dans un export bancal, et lire par nom en
    /// perdrait une » — puis cet initialiseur écrasait la première par la seconde. Mesuré sur
    /// un en-tête `["Titre", "Titre"]` dont la seconde est affectée à la main : le mappage
    /// mémorisé ne portait plus que `original_title`, et l'affectation du champ **requis**
    /// avait disparu.
    ///
    /// La correspondance est mémorisée par nom parce qu'elle doit survivre à un déplacement
    /// de colonne (voir `headerSignature`) : c'est ce qui la rend indépendante de l'ordre, et
    /// c'est ce qui la rend incapable de distinguer deux homonymes. Le conflit est donc
    /// **nommé** au lieu d'être arbitré — `duplicateColumnNames` le dit, et
    /// `ImportMappingRepository.save` refuse.
    public init(entity: ActivityEntityType, matches: [ColumnMatch]) {
        var map: [String: String] = [:]
        for match in matches {
            guard let key = match.fieldKey else { continue }
            map[match.columnName] = key
        }
        self.init(entity: entity, columnToField: map)
    }

    /// Les noms de colonnes qui apparaissent plus d'une fois dans un en-tête.
    ///
    /// Comparés **repliés**, comme la signature : `Titre` et `TITRE` sont le même nom pour
    /// une correspondance mémorisée, donc ils s'y heurtent aussi. Les colonnes vides sont
    /// ignorées — un export qui finit par un point-virgule solitaire n'est pas un doublon.
    public static func duplicateColumnNames(in header: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: [String] = []
        for name in header {
            let key = name.foldedForMatching.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            if !seen.insert(key).inserted, !duplicates.contains(name) {
                duplicates.append(name)
            }
        }
        return duplicates
    }

    /// Ce que l'entité porte, encodé.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Relit une correspondance mémorisée.
    ///
    /// - Throws: `ColumnMappingError.unsupportedVersion` si le format vient d'une version
    ///   postérieure. Le cas est réel en synchronisation : un appareil déjà mis à jour a
    ///   pu écrire un format que celui-ci ne connaît pas.
    public static func decoded(from data: Data) throws -> ColumnMapping {
        let mapping = try JSONDecoder().decode(ColumnMapping.self, from: data)
        // Bornée **des deux côtés** : la première version ne refusait que le futur, donc une
        // version 0 ou négative passait pour valide. Un JSON tronqué ou fabriqué à la main
        // n'a pas à se lire comme un mappage de la version courante.
        guard mapping.version >= 1, mapping.version <= currentVersion else {
            throw ColumnMappingError.unsupportedVersion(mapping.version)
        }
        return mapping
    }
}

public enum ColumnMappingError: Error, Sendable, Hashable {
    /// Une correspondance écrite par une version plus récente de l'app.
    case unsupportedVersion(Int)
    /// L'entité n'a pas de schéma de colonnes.
    case unknownEntity(ActivityEntityType)
    /// L'en-tête porte deux colonnes de même nom : la correspondance ne peut pas être
    /// mémorisée sans en perdre une.
    case duplicateColumnNames([String])

    /// Le message montré à l'utilisateur. Dit quoi faire, pas ce qui est faux.
    public var message: String {
        switch self {
        case .unsupportedVersion:
            """
            Cette correspondance a été enregistrée par une version plus récente de CineShelf. \
            Mettre l'app à jour, ou refaire la correspondance.
            """
        case .unknownEntity:
            "Cet élément n'a pas de colonnes importables."
        case .duplicateColumnNames(let names):
            """
            \(names.joined(separator: ", ")) : ce nom de colonne apparaît deux fois. \
            Renommer l'une des deux dans le tableur avant de mémoriser la correspondance.
            """
        }
    }
}

// MARK: - Reconnaître « le même en-tête »

extension ColumnMapping {

    /// La signature d'un en-tête : ce qui permet de retrouver la correspondance d'un
    /// fichier de même forme, sans dépendre de l'ordre, de la casse ni des accents.
    ///
    /// **Sous locale invariante**, par `foldedForMatching`. Ce n'est pas une précaution
    /// théorique : `ImportMapping` est synchronisée par CloudKit, donc la signature est
    /// **écrite** par un appareil et **comparée** par un autre. Deux repliages différents
    /// des deux côtés ne se rencontrent jamais, la correspondance mémorisée ne se retrouve
    /// plus, et l'utilisateur refait son travail sans comprendre pourquoi — voir
    /// `TextFolding` et `docs/02` §3.
    ///
    /// **Trié**, parce que la planche dit « les prochains fichiers de même en-tête » sans
    /// parler d'ordre : un tableur qui déplace une colonne produit le même fichier pour
    /// l'utilisateur, et la correspondance est mémorisée **par nom**, donc l'ordre ne
    /// change rien à ce qu'elle décide.
    ///
    /// Les colonnes vides sont retirées : un export qui finit par un point-virgule
    /// solitaire donnerait deux signatures pour le même fichier.
    public static func headerSignature(for header: [String]) -> String {
        header
            .map { $0.foldedForMatching.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "\u{1F}")
    }
}
