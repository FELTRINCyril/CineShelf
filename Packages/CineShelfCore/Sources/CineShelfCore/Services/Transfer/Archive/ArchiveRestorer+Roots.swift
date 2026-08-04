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
            if state.assets[record.id] != nil {
                state.report.note(skipped: .mediaAssets)
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
                // Un média manquant **n'annule pas** la restauration : refuser l'archive
                // entière ferait perdre 999 affiches pour une absente, alors que l'asset
                // sans image reste réparable — sa fiche existe, son recadrage aussi, et
                // le bilan nomme l'identifiant. Une donnée récupérable ne justifie pas de
                // jeter celles qui ne le sont pas.
                //
                // Le compteur couvre les **deux** façons de finir sans octets : le fichier
                // absent de l'archive, et `mediaSource` non fourni. La première version ne
                // comptait que la première, et une restauration sans source rendait alors
                // un catalogue complet sans une seule image en annonçant zéro anomalie —
                // trouvé par la sonde, qui l'a mesuré au lieu de le supposer. Du point de
                // vue du résultat c'est la même perte, donc le même compteur.
                let bytes = mediaSource.flatMap {
                    reader.mediaData(forAssetID: record.id, in: $0)
                }
                if let bytes {
                    model.data = bytes
                } else {
                    state.report.missingMediaAssetIDs.append(record.id)
                }
            }
            context.insert(model)
            state.assets[record.id] = model
            state.createdIDs.insert(record.id)
            state.report.note(created: .mediaAssets)
            try checkpoint(state)
        }
    }
}
