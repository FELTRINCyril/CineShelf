import Foundation

// MARK: - Le brouillon d'import : un fichier, pas une entité
//
// **Pourquoi un fichier.** Le schéma est fermé depuis le 2026-08-03 et aucune entité ne porte
// un brouillon d'import ; en ajouter une exigerait un `VersionedSchema` et un `MigrationStage`
// pour un état qui ne doit surtout pas être synchronisé. Car c'est le fond de l'affaire : un
// brouillon référence un fichier de **cet** appareil, et « un seul brouillon à la fois » est une
// notion d'appareil. Le synchroniser ferait apparaître sur le Mac un import commencé sur
// l'iPhone, dont le fichier source est introuvable — `ImportMapping`, elle, est synchronisée,
// parce qu'un mappage est un travail réutilisable et non un état de session.
//
// Ce que le brouillon contient, et pourquoi il est autonome : les **lignes** du fichier, et pas
// son chemin. Un chemin se périme — l'utilisateur déplace son fichier, vide ses téléchargements,
// ou dépose depuis un dossier temporaire que le système nettoie. Reprendre un import dont le
// fichier a disparu est l'échec le plus banal qu'on puisse s'épargner. Le coût est mesurable et
// modeste : 1 284 lignes de quatorze colonnes pèsent quelques centaines de kilo-octets.

/// Un import commencé, repris tel quel.
public struct ImportDraft: Codable, Sendable, Hashable {

    /// La version du format sérialisé.
    ///
    /// Même motif que `ColumnMapping` et `ImportBatchDiff` : ce fichier survit à une mise à
    /// jour de l'app, donc une version inconnue se **refuse** plutôt que de se deviner. Un
    /// brouillon mal relu rejouerait des corrections dans les mauvaises colonnes.
    public static let currentVersion = 1

    public let version: Int
    /// Le nom du fichier d'origine, montré dans le bandeau de reprise.
    public let fileName: String
    /// L'entité importée.
    public let entity: ActivityEntityType
    /// L'en-tête du fichier, tel quel.
    public let header: [String]
    /// Les lignes de données, telles qu'elles ont été découpées.
    public let rawRows: [RawRow]
    /// La correspondance des colonnes décidée à l'étape 1.
    public let mapping: ColumnMapping
    /// Les corrections de masse déjà appliquées, dans l'ordre où elles l'ont été.
    ///
    /// Rejouées à la reprise plutôt que stockées sous forme de lignes corrigées : l'ordre
    /// compte — une correction peut en découvrir une autre — et rejouer donne exactement l'état
    /// où l'utilisateur s'est arrêté, y compris les refus qui restent.
    public let corrections: [ImportCorrection]
    /// Quand le brouillon a été posé. Le bandeau de reprise l'affiche.
    public let savedAt: Date

    public init(
        version: Int = ImportDraft.currentVersion,
        fileName: String,
        entity: ActivityEntityType,
        header: [String],
        rawRows: [RawRow],
        mapping: ColumnMapping,
        corrections: [ImportCorrection],
        savedAt: Date
    ) {
        self.version = version
        self.fileName = fileName
        self.entity = entity
        self.header = header
        self.rawRows = rawRows
        self.mapping = mapping
        self.corrections = corrections
        self.savedAt = savedAt
    }

    /// Une ligne, avec son numéro de fichier et son incident de découpage éventuel.
    ///
    /// Le numéro est conservé et non recalculé : c'est celui du tableur, celui que l'utilisateur
    /// doit corriger, et une ligne perdue par une resynchronisation décale tout ce qui suit.
    public struct RawRow: Codable, Sendable, Hashable {
        public let number: Int
        public let fields: [String]
        /// La malformation, en texte de cause. `nil` si la ligne était bien découpée.
        ///
        /// **La cause et non l'objet.** `CSVMalformation` porte des nombres — « 13 colonnes au
        /// lieu de 14 » — et l'encoder tel quel figerait dans le brouillon une forme qui change
        /// avec le lecteur. La clé de cause suffit à retrouver le refus, et elle est stable.
        public let malformationCauseKey: String?

        public init(number: Int, fields: [String], malformationCauseKey: String?) {
            self.number = number
            self.fields = fields
            self.malformationCauseKey = malformationCauseKey
        }
    }
}

public enum ImportDraftError: Error, Sendable, Hashable {
    case unsupportedVersion(Int)
}

// MARK: - Où il vit

/// Lit et écrit le brouillon d'import, à un seul endroit.
///
/// **Un seul brouillon à la fois**, donc un chemin fixe et pas un dossier : la contrainte de
/// l'addendum est portée par le système de fichiers plutôt que par une vérification qu'on
/// pourrait oublier. Déposer un nouveau fichier alors qu'un brouillon existe est une question à
/// poser à l'utilisateur — `existingDraft()` la rend possible — et non un écrasement.
public struct ImportDraftStore: Sendable {

    /// Le dossier d'accueil. Injectable pour que les tests n'écrivent pas dans le vrai.
    public let directory: URL

    /// Le nom du fichier. Fixe : c'est lui qui matérialise « un seul à la fois ».
    public static let fileName = "import-draft.json"

    public var url: URL { directory.appendingPathComponent(Self.fileName) }

    /// Le dossier de l'app, hors de `Documents` : un brouillon n'est pas un document de
    /// l'utilisateur, et il n'a pas à apparaître dans l'app Fichiers.
    public static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("CineShelf", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public init(directory: URL) {
        self.directory = directory
    }

    /// Le brouillon en attente, s'il y en a un.
    ///
    /// - Throws: `ImportDraftError.unsupportedVersion` si le format vient d'une version
    ///   postérieure de l'app. Un fichier illisible pour une autre raison — tronqué, corrompu —
    ///   rend `nil` : c'est un état local reconstructible, et refuser d'ouvrir l'app pour un
    ///   brouillon abîmé serait disproportionné. Le cas est distinct d'un `payload` de journal,
    ///   qui est de la donnée de l'utilisateur.
    public func existingDraft() throws -> ImportDraft? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let draft = try? JSONDecoder().decode(ImportDraft.self, from: data) else {
            return nil
        }
        guard draft.version >= 1, draft.version <= ImportDraft.currentVersion else {
            throw ImportDraftError.unsupportedVersion(draft.version)
        }
        return draft
    }

    /// Pose le brouillon, en remplaçant celui qui s'y trouvait.
    ///
    /// **Écriture atomique.** Un brouillon écrit à moitié — l'app quittée pendant la
    /// sauvegarde — serait illisible, et l'utilisateur perdrait ses corrections en croyant les
    /// avoir mises à l'abri. `.atomic` écrit un fichier temporaire puis le déplace, donc
    /// l'ancien brouillon survit à une interruption.
    public func save(_ draft: ImportDraft) throws {
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url, options: .atomic)
    }

    /// Supprime le brouillon. « Tout abandonner » de la planche 11g.
    ///
    /// Ne touche pas au fichier source, comme la planche le dit : il appartient à l'utilisateur.
    public func discard() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - Le pont entre un brouillon et une analyse

extension ImportDraft {

    /// Le brouillon d'une analyse en cours.
    public init(
        analysis: ImportAnalysis,
        fileName: String,
        corrections: [ImportCorrection],
        savedAt: Date
    ) {
        self.init(
            fileName: fileName,
            entity: analysis.columns.entity,
            header: analysis.header,
            rawRows: analysis.rows.map {
                RawRow(
                    number: $0.number,
                    fields: $0.rawFields,
                    malformationCauseKey: $0.issues.lazy
                        .compactMap { issue -> String? in
                            guard case .rowMalformed(let malformation) = issue.reason else {
                                return nil
                            }
                            return malformation.causeKey
                        }
                        .first)
            },
            mapping: analysis.columns.mapping,
            corrections: corrections,
            savedAt: savedAt)
    }
}
