import Foundation
import SwiftData

/// Ce qu'une restauration a fait, entité par entité, et ce qu'elle a trouvé d'anormal.
///
/// Un bilan et non un booléen : la question qu'on se pose après une restauration n'est
/// pas « ça a marché ? » mais « qu'est-ce qui est entré, et qu'est-ce qui manque ». Même
/// forme que le rapport d'import de `L11a`, pour la même raison.
public struct ArchiveRestoreReport: Sendable, Equatable {
    /// Entités créées, par nom de fichier d'entité.
    public var created: [String: Int] = [:]
    /// Entités déjà présentes sous le même identifiant, donc laissées intactes.
    public var skipped: [String: Int] = [:]
    /// Assets restaurés **sans** leurs octets, alors que l'archive en annonçait.
    ///
    /// Deux causes, un seul compteur : le fichier était absent de `media/`, ou aucune
    /// source de médias n'a été fournie. L'état final est le même — une fiche sans image —
    /// donc le distinguer dans le bilan n'aiderait personne, et ne pas compter le second
    /// cas laissait une restauration sans images annoncer zéro anomalie.
    ///
    /// L'asset est créé sans image plutôt que refusé : voir `ArchiveRestorer`.
    public var missingMediaAssetIDs: [UUID] = []
    /// Références vers un identifiant qu'on ne trouve ni dans l'archive ni dans le
    /// magasin. La relation reste nulle, et le compte le dit.
    public var danglingReferenceCount = 0
    /// Rattachements qui violent `hasExactlyOneOwner`. Comptés, pas corrigés : l'archive
    /// restitue ce qu'elle a trouvé, et `L16` est la tâche qui nettoie.
    public var invalidAttachmentCount = 0
    /// Fichiers de `media/` que nul asset ne réclame.
    public var orphanedMediaFileCount = 0

    public var totalCreated: Int { created.values.reduce(0, +) }
    public var totalSkipped: Int { skipped.values.reduce(0, +) }

    mutating func note(created file: ArchiveEntityFile) {
        created[file.rawValue, default: 0] += 1
    }

    mutating func note(skipped file: ArchiveEntityFile) {
        skipped[file.rawValue, default: 0] += 1
    }
}

/// L'état d'une restauration en cours : les index, le bilan, et ce qui a été créé.
///
/// Une classe et non une structure, pour que les trois passes la partagent sans se
/// passer six `inout` en cascade. Elle ne franchit aucune frontière d'isolation — elle
/// vit le temps d'un appel à `ArchiveRestorer.restore(_:from:)` — et elle n'a donc pas
/// à être `Sendable`, ce qu'aucun `@Model` n'est de toute façon.
final class RestoreState {
    var report = ArchiveRestoreReport()

    /// Les identifiants créés par **cette** restauration.
    ///
    /// Distinct des index, qui contiennent aussi les entités préexistantes : la passe des
    /// dérivés ne doit toucher que ce qu'elle a créé. Rafraîchir une entité déjà en base
    /// écraserait son `updatedAt` avec la valeur de l'archive, donc rajeunirait ou
    /// vieillirait une fiche que l'utilisateur a modifiée depuis la sauvegarde.
    var createdIDs: Set<UUID> = []

    var libraries: [UUID: Library] = [:]
    var profiles: [UUID: Profile] = [:]
    var titles: [UUID: Title] = [:]
    var people: [UUID: Person] = [:]
    var collections: [UUID: TitleCollection] = [:]
    var genres: [UUID: Genre] = [:]
    var assets: [UUID: MediaAsset] = [:]

    private var pending = 0

    /// Vrai quand il est temps de sauvegarder — un lot sur `ArchiveRestorer.batchSize`.
    func shouldSave() -> Bool {
        pending += 1
        return pending.isMultiple(of: ArchiveRestorer.batchSize)
    }

    // MARK: - Résolution des références

    func library(_ id: UUID?) -> Library? { resolve(id, in: libraries) }
    func profile(_ id: UUID?) -> Profile? { resolve(id, in: profiles) }
    func title(_ id: UUID?) -> Title? { resolve(id, in: titles) }
    func person(_ id: UUID?) -> Person? { resolve(id, in: people) }
    func collection(_ id: UUID?) -> TitleCollection? { resolve(id, in: collections) }
    func genre(_ id: UUID?) -> Genre? { resolve(id, in: genres) }
    func asset(_ id: UUID?) -> MediaAsset? { resolve(id, in: assets) }

    /// Une référence **absente** (`nil` dans l'archive) est normale et ne compte pas ; une
    /// référence **présente mais introuvable** est une perte et se compte.
    ///
    /// Confondre les deux rendrait le compteur inutilisable, puisque la plupart des
    /// relations du modèle sont légitimement optionnelles. Et le compteur est le point :
    /// une référence pendante rendue silencieusement nulle donne un catalogue qui
    /// s'affiche sans erreur, avec des titres sans bibliothèque et des crédits sans
    /// personne — exactement la forme de perte qu'une sauvegarde doit empêcher.
    private func resolve<Model>(_ id: UUID?, in table: [UUID: Model]) -> Model? {
        guard let id else { return nil }
        guard let model = table[id] else {
            report.danglingReferenceCount += 1
            return nil
        }
        return model
    }
}

/// Le seul point commun dont les index de restauration ont besoin : un `id`.
///
/// Les dix-neuf `@Model` en ont un, mais aucun protocole du schéma ne le dit — d'où
/// celui-ci, déclaré ici parce qu'il ne sert qu'à l'archive.
protocol Identified {
    var id: UUID { get }
}

extension Library: Identified {}
extension Profile: Identified {}
extension TitleFlag: Identified {}
extension PersonFlag: Identified {}
extension MediaFlag: Identified {}
extension Title: Identified {}
extension Person: Identified {}
extension SocialHandle: Identified {}
extension TitleCollection: Identified {}
extension Genre: Identified {}
extension Credit: Identified {}
extension MediaAsset: Identified {}
extension MediaAttachment: Identified {}
extension MediaCrop: Identified {}
extension ResourceLink: Identified {}
extension SavedLink: Identified {}
extension ActivityEntry: Identified {}
extension ImportMapping: Identified {}
extension LegacyRecord: Identified {}
