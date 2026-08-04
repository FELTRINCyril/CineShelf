import Foundation
import SwiftData

// Passe 1 — les entités qui existent par elles-mêmes.
//
// Elles sont créées **sans leurs relations** : la passe 3 les relie, une fois que toutes
// les cibles possibles sont dans les index. Les créer et les relier d'un seul geste
// obligerait à trier les dix-neuf entités par dépendance, ce qui n'a pas de solution —
// `Title.collection` et `TitleCollection.titles` se pointent mutuellement.
extension ArchiveRestorer {
    func restoreRoots(
        _ document: ArchiveDocument, into state: RestoreState, mediaSource: URL?
    ) throws {
        try restoreLibrariesAndProfiles(document, into: state)
        try restoreCollectionsAndGenres(document, into: state)
        try restoreTitlesAndPeople(document, into: state)
        try restoreAssets(document, into: state, mediaSource: mediaSource)
    }

    private func restoreLibrariesAndProfiles(
        _ document: ArchiveDocument, into state: RestoreState
    ) throws {
        for record in document.libraries {
            if state.libraries[record.id] != nil {
                state.report.note(skipped: .libraries)
                continue
            }
            let model = Library()
            model.id = record.id
            model.name = record.name
            model.isDefault = record.isDefault
            model.isSandbox = record.isSandbox
            model.sortIndex = record.sortIndex
            model.createdAt = record.createdAt
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.libraries[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .libraries)
            try checkpoint(state)
        }

        for record in document.profiles {
            if state.profiles[record.id] != nil {
                state.report.note(skipped: .profiles)
                continue
            }
            let model = Profile()
            model.id = record.id
            model.name = record.name
            model.avatarSymbol = record.avatarSymbol
            model.avatarEmoji = record.avatarEmoji
            model.accentRaw = record.accentRaw
            model.isDefault = record.isDefault
            model.sortIndex = record.sortIndex
            model.requiresBiometry = record.requiresBiometry
            model.hidesPrivateContent = record.hidesPrivateContent
            model.createdAt = record.createdAt
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.profiles[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .profiles)
            try checkpoint(state)
        }
    }

    private func restoreCollectionsAndGenres(
        _ document: ArchiveDocument, into state: RestoreState
    ) throws {
        for record in document.collections {
            if state.collections[record.id] != nil {
                state.report.note(skipped: .collections)
                continue
            }
            let model = TitleCollection()
            model.id = record.id
            model.name = record.name
            model.summary = record.summary
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            // Les dérivés sont posés **dès maintenant**, et reposés en passe 3 une fois les
            // relations en place. Sans ce premier appel, `checkpoint()` commet des lignes
            // dont `sortName` et `searchText` sont vides : mesuré par la revue, 700 titres
            // sur 700 traversent le disque introuvables en recherche, et une interruption
            // (jetsam, `save()` qui lève) les y laisse pour de bon. Le second appel reste
            // nécessaire — `filterKeys` a besoin des relations.
            model.refreshDerived()
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.collections[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .collections)
            try checkpoint(state)
        }

        for record in document.genres {
            if state.genres[record.id] != nil {
                state.report.note(skipped: .genres)
                continue
            }
            let model = Genre()
            model.id = record.id
            model.name = record.name
            model.targetRaw = record.targetRaw
            model.colorToken = record.colorToken
            model.isPinned = record.isPinned
            model.pinIndex = record.pinIndex
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            model.refreshDerived()
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.genres[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .genres)
            try checkpoint(state)
        }
    }

    private func restoreTitlesAndPeople(
        _ document: ArchiveDocument, into state: RestoreState
    ) throws {
        for record in document.titles {
            if state.titles[record.id] != nil {
                state.report.note(skipped: .titles)
                continue
            }
            let model = Title()
            model.id = record.id
            model.kindRaw = record.kindRaw
            model.name = record.name
            model.originalName = record.originalName
            model.summary = record.summary
            model.releaseDate = record.releaseDate
            model.releasePrecisionRaw = record.releasePrecisionRaw
            model.runtimeMinutes = record.runtimeMinutes
            model.seasonCount = record.seasonCount
            model.episodeCount = record.episodeCount
            model.rating = record.rating
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            model.refreshDerived()
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.titles[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .titles)
            try checkpoint(state)
        }

        for record in document.people {
            if state.people[record.id] != nil {
                state.report.note(skipped: .people)
                continue
            }
            let model = Person()
            model.id = record.id
            model.firstName = record.firstName
            model.lastName = record.lastName
            model.birthDate = record.birthDate
            model.deathDate = record.deathDate
            model.bio = record.bio
            model.roleValues = record.roleValues
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            model.refreshDerived()
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.people[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .people)
            try checkpoint(state)
        }
    }

    private func restoreAssets(
        _ document: ArchiveDocument, into state: RestoreState, mediaSource: URL?
    ) throws {
        let reader = ArchiveReader()
        for record in document.mediaAssets {
            if let existing = state.assets[record.id] {
                state.report.note(skipped: .mediaAssets)
                // **Un asset déjà là mais sans ses octets se répare.** Il était sauté avant
                // d'arriver ici, donc rejouer une archive avec les images sous la main ne
                // les remettait pas, et ne comptait rien : mesuré par la revue, un asset
                // restauré une première fois sans source restait vide pour toujours, bilan
                // « ignoré », zéro anomalie. C'est le cas d'usage central de la fusion —
                // récupérer ce qui manque — et il ne marchait pas pour les médias.
                //
                // Poser des octets là où il n'y en avait aucun n'est **pas** un écrasement :
                // la règle « rien n'est jamais écrasé » vise les données de l'utilisateur,
                // et `nil` n'en est pas une.
                if record.hasMediaFile, existing.data == nil {
                    restoreBytes(of: record, into: existing, from: mediaSource, reader, state)
                }
                continue
            }
            let model = MediaAsset()
            model.id = record.id
            model.kindRaw = record.kindRaw
            model.externalURLString = record.externalURLString
            model.mimeType = record.mimeType
            model.pixelWidth = record.pixelWidth
            model.pixelHeight = record.pixelHeight
            model.byteSize = record.byteSize
            model.blurHash = record.blurHash
            model.checksum = record.checksum
            model.isGenerated = record.isGenerated
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            model.updatedAt = record.updatedAt
            if record.hasMediaFile {
                restoreBytes(of: record, into: model, from: mediaSource, reader, state)
            }
            context.insert(model)
            state.assets[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .mediaAssets)
            try checkpoint(state)
        }
    }

    /// Pose les octets d'un asset, ou compte la perte.
    ///
    /// Un média manquant **n'annule pas** la restauration : refuser l'archive entière ferait
    /// perdre neuf cent quatre-vingt-dix-neuf affiches pour une absente, alors que l'asset
    /// sans image reste réparable — sa fiche existe, son recadrage aussi, et le bilan nomme
    /// l'identifiant.
    ///
    /// Le compteur couvre **trois** façons de finir sans les bons octets : le fichier absent
    /// de l'archive, `mediaSource` non fourni, et le fichier **tronqué**. Le troisième était
    /// muet : `Data(contentsOf:)` réussit sur un fichier coupé, et rien ne comparait la
    /// taille relue à `byteSize`, pourtant écrit dans l'archive juste à côté. Mesuré par la
    /// revue : 7 octets restaurés pour 4 096 annoncés, zéro compteur.
    ///
    /// Le `checksum` n'est **pas** vérifié ici, et ce n'est pas un oubli : le calculer
    /// demanderait de savoir comment il est produit, ce qui vit dans `MediaKit`, et
    /// `CineShelfCore` ne peut pas en dépendre (`docs/04` §1). `byteSize` attrape la
    /// troncature, qui est le mode de corruption réaliste d'une copie de dossier.
    private func restoreBytes(
        of record: MediaAssetRecord,
        into model: MediaAsset,
        from mediaSource: URL?,
        _ reader: ArchiveReader,
        _ state: RestoreState
    ) {
        guard let mediaSource,
            let bytes = reader.mediaData(forAssetID: record.id, in: mediaSource)
        else {
            state.report.missingMediaAssetIDs.append(record.id)
            return
        }
        guard record.byteSize == 0 || bytes.count == record.byteSize else {
            state.report.truncatedMediaAssetIDs.append(record.id)
            return
        }
        model.data = bytes
    }
}
