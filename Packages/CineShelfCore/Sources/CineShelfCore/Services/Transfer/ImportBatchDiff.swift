import Foundation

// MARK: - Ce qu'un import a fait, sous une forme annulable
//
// Écrit dans `ActivityEntry.payload`, sur le patron exact de `BulkEditDiff` : versionné,
// valeurs en `String?` avec un encodage explicite, et une version inconnue se **refuse**.
//
// **Ce fichier est le seul endroit qui rend les quatre suites de l'addendum réalisables**, et
// c'est moins évident qu'il n'y paraît. Le schéma est fermé depuis le 2026-08-03 : aucun champ
// `importBatchID` ne sera ajouté à `Title`. « Voir les 1 081 titres ajoutés » ne peut donc pas
// être un filtre sur un champ — c'est une recherche par la **liste d'identifiants** que porte
// ce diff. Même chose pour « Annuler tout l'import », qui a besoin de savoir non seulement
// quels titres retirer, mais quelles valeurs rétablir sur les fiches qu'il a complétées.

/// Ce qu'un import a écrit, et de quoi le défaire.
public struct ImportBatchDiff: Codable, Sendable, Hashable {

    /// La version du format. À incrémenter à **toute** modification de forme.
    ///
    /// Un `payload` écrit aujourd'hui sera relu par `L20`. Sans ce numéro, un changement de
    /// forme rendrait les imports passés silencieusement inannulables — ou pire, mal annulés.
    public static let currentVersion = 1

    public let version: Int
    /// Le nom du fichier importé, pour le fil d'activité.
    public let fileName: String
    /// L'entité importée.
    public let entity: ActivityEntityType
    /// Les titres créés par cet import, dans l'ordre du fichier.
    ///
    /// C'est cette liste que « voir les titres ajoutés » interroge, et que l'annulation
    /// retire. L'ordre est conservé : il permet de rejouer un rapport ligne par ligne.
    public let createdTitleIDs: [UUID]
    /// Les entités créées **en passant** : personnes, collections, genres.
    ///
    /// Séparées des titres parce qu'elles ne se retirent pas de la même façon. Un genre créé
    /// par l'import peut avoir été rattaché depuis à d'autres titres entre-temps : l'annulation
    /// doit vérifier avant de supprimer, et c'est pour ça que la liste existe plutôt qu'un
    /// simple compte.
    public let createdReferenceIDs: [UUID]
    /// Les fiches existantes que l'import a **complétées**, avec les valeurs d'avant.
    ///
    /// La règle de doublon arrêtée le 2026-08-04 ne crée rien et ne remplace rien : elle
    /// remplit les champs vides d'un titre existant. C'est réversible, mais seulement si l'état
    /// d'avant est écrit — sinon « rétablir les 96 doublons fusionnés » ne peut pas savoir
    /// quels champs étaient vides.
    public let completions: [Completion]

    public init(
        version: Int = ImportBatchDiff.currentVersion,
        fileName: String,
        entity: ActivityEntityType,
        createdTitleIDs: [UUID],
        createdReferenceIDs: [UUID],
        completions: [Completion]
    ) {
        self.version = version
        self.fileName = fileName
        self.entity = entity
        self.createdTitleIDs = createdTitleIDs
        self.createdReferenceIDs = createdReferenceIDs
        self.completions = completions
    }

    /// Une fiche complétée, et ce qu'elle valait avant.
    public struct Completion: Codable, Sendable, Hashable {
        public let entityID: UUID
        /// Clé de champ → valeur d'avant. `nil` signifie **le champ était vide**, ce qui est
        /// une information et non une absence d'information : c'est précisément la valeur à
        /// rétablir.
        public let previousValues: [String: String?]

        public init(entityID: UUID, previousValues: [String: String?]) {
            self.entityID = entityID
            self.previousValues = previousValues
        }
    }

    /// Le nombre de titres touchés, créés ou complétés.
    public var touchedTitleCount: Int { createdTitleIDs.count + completions.count }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Relit le diff d'un import.
    ///
    /// - Throws: `ImportBatchDiffError.unsupportedVersion` si la version n'est pas connue.
    ///   Bornée des deux côtés : une version 0 ou négative vient d'un `payload` tronqué ou
    ///   fabriqué, et la lire comme un diff de la version courante annulerait n'importe quoi.
    public static func decoded(from data: Data) throws -> ImportBatchDiff {
        let diff = try JSONDecoder().decode(ImportBatchDiff.self, from: data)
        guard diff.version >= 1, diff.version <= currentVersion else {
            throw ImportBatchDiffError.unsupportedVersion(diff.version)
        }
        return diff
    }
}

public enum ImportBatchDiffError: Error, Sendable, Hashable {
    case unsupportedVersion(Int)
}
