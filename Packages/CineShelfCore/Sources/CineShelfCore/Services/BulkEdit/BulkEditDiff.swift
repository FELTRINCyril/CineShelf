import Foundation

// MARK: - Le diff inversable
//
// Ce qui est écrit dans `ActivityEntry.payload`, et que `L20` relira pour défaire un
// lot. Sa forme est le contrat entre les deux tâches, donc elle est versionnée.
//
// **Les valeurs sont des `String?`, avec un encodage explicite par type.** Ce n'est pas
// de la paresse : `Codable` n'encode pas de valeur hétérogène sans un `AnyCodable`
// maison, et un tel type se met à accepter n'importe quoi — le jour où une valeur
// s'encode en dictionnaire imbriqué, l'annulation ne sait plus la relire. Les types en
// jeu sont peu nombreux et tous représentables sans perte : `String`, `Int`, `Double`,
// `Bool`, `Date` en ISO 8601, et les enums par leur `rawValue`.
//
// `nil` signifie **absence de valeur** (le champ était `nil`), pas « inconnu ». La
// distinction compte : restaurer `nil` est une action, pas une abstention.

/// Le diff d'une opération de masse, encodé dans `ActivityEntry.payload`.
public struct BulkEditDiff: Codable, Sendable, Hashable {

    /// La version du format.
    ///
    /// Un `payload` écrit aujourd'hui sera relu par `L20`, puis par des versions
    /// ultérieures. Sans ce numéro, un changement de forme rendrait les anciens lots
    /// silencieusement inannulables — ou pire, mal annulables. `L20` doit refuser une
    /// version qu'il ne connaît pas plutôt que de deviner.
    public static let currentVersion = 1

    public let version: Int
    /// Ce que l'opération a fait, en une ligne, pour le fil d'activité.
    public let summary: String
    /// Le champ visé, tel que nommé par la mutation.
    public let field: String
    /// L'opération appliquée.
    public let operation: BulkOperationKind
    /// Un enregistrement par entité touchée.
    public let entries: [Entry]

    public init(
        version: Int = BulkEditDiff.currentVersion,
        summary: String,
        field: String,
        operation: BulkOperationKind,
        entries: [Entry]
    ) {
        self.version = version
        self.summary = summary
        self.field = field
        self.operation = operation
        self.entries = entries
    }

    /// Ce qui a changé sur une entité.
    public struct Entry: Codable, Sendable, Hashable {
        public let entityID: UUID
        public let entityType: ActivityEntityType
        /// Les changements de valeur scalaire.
        public let fields: [FieldChange]
        /// Les identifiants rattachés à une relation par l'opération.
        public let attached: [UUID]
        /// Les identifiants détachés d'une relation par l'opération.
        public let detached: [UUID]

        public init(
            entityID: UUID,
            entityType: ActivityEntityType,
            fields: [FieldChange] = [],
            attached: [UUID] = [],
            detached: [UUID] = []
        ) {
            self.entityID = entityID
            self.entityType = entityType
            self.fields = fields
            self.attached = attached
            self.detached = detached
        }

        /// `true` si cette entité n'a en réalité rien changé.
        ///
        /// Utile à `L20` : réappliquer l'inverse d'un non-changement est inoffensif mais
        /// inutile, et une entrée vide dans un diff signale plutôt une erreur d'analyse.
        public var isEmpty: Bool {
            fields.isEmpty && attached.isEmpty && detached.isEmpty
        }
    }

    /// Le passage d'une valeur à une autre sur un champ.
    public struct FieldChange: Codable, Sendable, Hashable {
        public let field: String
        /// La valeur d'avant. `nil` = le champ était vide.
        public let before: String?
        /// La valeur d'après. `nil` = le champ a été vidé.
        public let after: String?

        public init(field: String, before: String?, after: String?) {
            self.field = field
            self.before = before
            self.after = after
        }

        /// `true` si les deux valeurs sont identiques — donc rien à défaire.
        public var isNoOp: Bool { before == after }
    }

    /// Les entités réellement modifiées.
    public var touchedEntityIDs: [UUID] {
        entries.filter { !$0.isEmpty }.map(\.entityID)
    }
}

// MARK: - Encodage des valeurs
//
// Un seul endroit pour convertir une valeur en `String` et inversement. Les deux sens
// vivent côte à côte **exprès** : c'est ce qui rend visible qu'un encodage sans
// décodage correspondant est un diff qu'on ne saura pas défaire.

/// Convertit les valeurs de champ vers et depuis leur forme textuelle.
public enum BulkValueCoding {

    /// ISO 8601 avec la date et l'heure, en UTC.
    ///
    /// Pas `DateFormatter` avec un format maison : celui-là dépend de la locale et du
    /// fuseau, donc un diff écrit à Paris en juillet ne se relit pas à l'identique en
    /// janvier. `releaseDate` porte parfois une précision à l'année seule, mais c'est
    /// `releasePrecision` qui le dit — la date elle-même reste une date complète.
    /// `ISO8601FormatStyle` et non `ISO8601DateFormatter` : le second est une classe a
    /// etat mutable, donc non `Sendable`, et une constante statique de ce type ne
    /// compile pas en concurrence stricte. Le style, lui, est une valeur.
    static let dateStyle = Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt)

    public static func encode(_ value: String?) -> String? { value }
    public static func encode(_ value: Int?) -> String? { value.map(String.init) }
    public static func encode(_ value: Bool) -> String { value ? "true" : "false" }

    /// `Double` en notation non localisée, avec assez de chiffres pour un aller-retour.
    ///
    /// `String(describing:)` suffirait pour les notes sur 5, mais pas pour une valeur
    /// venue d'un import : `%.17g` garantit que le décodage rend le même `Double`.
    public static func encode(_ value: Double?) -> String? {
        value.map { String(format: "%.17g", $0) }
    }

    public static func encode(_ value: Date?) -> String? {
        value.map { dateStyle.format($0) }
    }

    public static func encode(_ values: [String]) -> String {
        values.sorted().joined(separator: ",")
    }

    public static func decodeString(_ text: String?) -> String? { text }

    public static func decodeInt(_ text: String?) -> Int? {
        text.flatMap(Int.init)
    }

    public static func decodeDouble(_ text: String?) -> Double? {
        text.flatMap(Double.init)
    }

    public static func decodeBool(_ text: String?) -> Bool? {
        switch text {
        case "true": true
        case "false": false
        default: nil
        }
    }

    public static func decodeDate(_ text: String?) -> Date? {
        text.flatMap { try? dateStyle.parse($0) }
    }

    public static func decodeStringList(_ text: String?) -> [String] {
        guard let text, !text.isEmpty else { return [] }
        return text.split(separator: ",").map(String.init)
    }
}

// MARK: - Sérialisation

extension BulkEditDiff {

    /// Le JSON à poser dans `ActivityEntry.payload`.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        // Sortie stable : deux diffs identiques donnent deux `Data` identiques, ce qui
        // rend les tests comparables et le stockage déduplicable.
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Relit un `payload`.
    ///
    /// - Throws: `BulkEditDiffError.unsupportedVersion` si le diff vient d'une version
    ///   dont on ne connaît pas la forme. Refuser explicitement plutôt que de deviner :
    ///   une annulation qui interprète mal un diff écrit dans la base est pire que pas
    ///   d'annulation du tout.
    public static func decoded(from data: Data) throws -> BulkEditDiff {
        let diff = try JSONDecoder().decode(BulkEditDiff.self, from: data)
        guard diff.version == currentVersion else {
            throw BulkEditDiffError.unsupportedVersion(diff.version)
        }
        return diff
    }
}

public enum BulkEditDiffError: Error, Equatable, Sendable {
    /// Le diff a été écrit dans un format qu'on ne sait pas relire.
    case unsupportedVersion(Int)
}
