import Foundation
import SwiftData

/// Applique une archive relue à un magasin, **en fusionnant par identifiant**.
///
/// Une entité dont l'identifiant est déjà en base est laissée **intacte** : rien n'est
/// jamais écrasé, et rejouer la même archive deux fois ne change rien la seconde fois.
/// C'est ce qui rend l'opération sûre sur une base qui n'est pas vide — récupérer trois
/// fiches perdues n'oblige pas à tout effacer d'abord — et c'est aussi ce qui la rend
/// testable sans magasin neuf.
///
/// La contrepartie est explicite : **ceci n'est pas un « remplacer par la sauvegarde »**.
/// Une vraie restauration de bout en bout se fait en repartant d'un magasin vide.
public struct ArchiveRestorer {
    /// Même taille de lot que l'import, et pour la même raison mesurée : `save()` sur une
    /// table qui grossit est superlinéaire (écart connu, `L11b`).
    static let batchSize = 200

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// - Parameters:
    ///   - document: l'archive relue, déjà validée par `ArchiveReader`.
    ///   - mediaSource: l'URL du paquet, pour aller y chercher les octets. `nil` restaure
    ///     les données sans les images — utile pour vérifier un aller-retour de structure
    ///     sans payer la copie des médias.
    /// - Returns: le bilan — créés et ignorés par entité, plus les anomalies rencontrées.
    /// - Throws: l'erreur de `ModelContext.save()`. Aucune `ArchiveError` : les refus de
    ///   format ont tous eu lieu à la relecture, et ce qui reste ici est **compté**, pas
    ///   levé — un média absent ne doit pas faire perdre les neuf cent quatre-vingt-dix-
    ///   neuf autres.
    public func restore(
        _ document: ArchiveDocument, from mediaSource: URL?
    ) throws -> ArchiveRestoreReport {
        let state = RestoreState()

        // Les index contiennent **aussi** les entités déjà en base : une entité nouvelle
        // peut parfaitement pointer vers un genre qui existait avant la restauration, et
        // ne pas l'indexer laisserait la relation nulle en comptant un faux orphelin.
        state.libraries = try index(Library.self)
        state.profiles = try index(Profile.self)
        state.titles = try index(Title.self)
        state.people = try index(Person.self)
        state.collections = try index(TitleCollection.self)
        state.genres = try index(Genre.self)
        state.assets = try index(MediaAsset.self)

        try restoreRoots(document, into: state, mediaSource: mediaSource)
        try restoreRelated(document, into: state)
        restoreDerived(document, into: state)

        state.report.unknownEntityFiles = document.unknownEntityFiles
        state.report.mediaFileDelta = document.mediaFileDelta
        if let mediaSource {
            state.report.orphanedMediaFileCount = try ArchiveReader()
                .orphanedMediaFileCount(in: mediaSource, for: document)
        }
        if context.hasChanges { try context.save() }
        return state.report
    }

    /// Sauvegarde si le lot est plein. Appelé après chaque insertion.
    func checkpoint(_ state: RestoreState) throws {
        guard state.shouldSave() else { return }
        try context.save()
    }

    func index<Model: PersistentModel & Identified>(_ type: Model.Type) throws -> [UUID: Model] {
        let models = try context.fetch(FetchDescriptor<Model>())
        return Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Vrai si une entité de ce type porte déjà cet identifiant.
    ///
    /// Un `fetch` par entité, et c'est assumé : mesuré à `L11b`, un fetch par identifiant
    /// coûte 0,14 ms à vide et 0,36 ms sur 5 000 titres — négligeable devant le `save()`,
    /// qui est le vrai coût. Le prédicat passe par le magasin, donc sa traduction SQL est
    /// réellement exercée (règle de `CLAUDE.md`).
    /// - Throws: propage l'erreur du `fetch`. **Ne pas l'avaler** : un `try?` faisait lire
    ///   « n'existe pas » à une erreur de lecture, et la restauration insérait alors un
    ///   doublon d'identifiant — dans une base sans `@Attribute(.unique)`, rien ne l'aurait
    ///   arrêté, et le dédoublonnage applicatif ne regarde pas ces tables. Une erreur de
    ///   magasin doit interrompre, pas se transformer en écriture.
    func exists<Model: PersistentModel & Identified>(_ type: Model.Type, _ id: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<Model>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}
