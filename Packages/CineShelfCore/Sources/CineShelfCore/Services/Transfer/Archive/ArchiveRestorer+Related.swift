import Foundation
import SwiftData

// Passe 2 — les entités qui n'existent que par ce qu'elles relient.
//
// Un crédit sans titre ni personne ne veut rien dire, un recadrage sans média non plus :
// elles se créent et se relient d'un seul geste, puisque tout ce qu'elles peuvent viser
// est déjà dans les index après la passe 1.
extension ArchiveRestorer {
    func restoreRelated(_ document: ArchiveDocument, into state: RestoreState) throws {
        try restoreCreditsAndHandles(document, into: state)
        try restoreMediaRelations(document, into: state)
        try restoreLinks(document, into: state)
        try restoreFlags(document, into: state)
        try restoreJournals(document, into: state)
    }

    private func restoreCreditsAndHandles(
        _ document: ArchiveDocument, into state: RestoreState
    ) throws {
        for record in document.credits {
            if try exists(Credit.self, record.id) {
                state.report.note(skipped: .credits)
                continue
            }
            let model = Credit()
            model.id = record.id
            model.roleRaw = record.roleRaw
            model.characterName = record.characterName
            model.orderIndex = record.orderIndex
            model.createdAt = record.createdAt
            model.title = state.title(record.titleID)
            model.person = state.person(record.personID)
            context.insert(model)
            // **Le titre doit être rafraîchi, même s'il n'a pas été créé ici.**
            //
            // `Title.refreshDerived()` compose `filterKeys` depuis `credits` : un crédit
            // rendu à un titre déjà en base entre dans le magasin sans que l'index qui le
            // rend interrogeable ne bouge. Mesuré par la revue — la relation existe, la
            // fiche affiche la personne, et « filtrer par cette personne » rend **0 titre
            // au lieu de 1**, sans qu'aucun compteur du bilan ne bouge.
            //
            // C'est la classe de défaut de `L1` et de la grille vide : le titre s'affiche
            // parfaitement et n'existe pour aucun critère. Le rafraîchissement est donc
            // demandé pour tout titre touché, créé ou non.
            state.needsRefresh(titleID: record.titleID)
            state.report.note(created: .credits)
            try checkpoint(state)
        }

        for record in document.socialHandles {
            if try exists(SocialHandle.self, record.id) {
                state.report.note(skipped: .socialHandles)
                continue
            }
            let model = SocialHandle()
            model.id = record.id
            model.platform = record.platform
            model.handle = record.handle
            model.urlString = record.urlString
            model.createdAt = record.createdAt
            model.person = state.person(record.personID)
            context.insert(model)
            state.report.note(created: .socialHandles)
            try checkpoint(state)
        }
    }

    private func restoreMediaRelations(
        _ document: ArchiveDocument, into state: RestoreState
    ) throws {
        for record in document.mediaCrops {
            if try exists(MediaCrop.self, record.id) {
                state.report.note(skipped: .mediaCrops)
                continue
            }
            let model = MediaCrop()
            model.id = record.id
            model.contextRaw = record.contextRaw
            model.positionX = record.positionX
            model.positionY = record.positionY
            model.zoom = record.zoom
            model.updatedAt = record.updatedAt
            model.asset = state.asset(record.assetID)
            context.insert(model)
            state.report.note(created: .mediaCrops)
            try checkpoint(state)
        }

        for record in document.mediaAttachments {
            if try exists(MediaAttachment.self, record.id) {
                state.report.note(skipped: .mediaAttachments)
                continue
            }
            let model = MediaAttachment()
            model.id = record.id
            model.slotRaw = record.slotRaw
            model.orderIndex = record.orderIndex
            model.createdAt = record.createdAt
            model.asset = state.asset(record.assetID)
            model.title = state.title(record.titleID)
            model.person = state.person(record.personID)
            model.collection = state.collection(record.collectionID)
            if !model.hasExactlyOneOwner { state.report.invalidAttachmentCount += 1 }
            context.insert(model)
            state.report.note(created: .mediaAttachments)
            try checkpoint(state)
        }
    }

    private func restoreLinks(_ document: ArchiveDocument, into state: RestoreState) throws {
        for record in document.resourceLinks {
            if try exists(ResourceLink.self, record.id) {
                state.report.note(skipped: .resourceLinks)
                continue
            }
            let model = ResourceLink()
            model.id = record.id
            model.urlString = record.urlString
            model.label = record.label
            model.summary = record.summary
            model.faviconData = record.faviconData
            model.orderIndex = record.orderIndex
            model.isArchived = record.isArchived
            model.createdAt = record.createdAt
            model.updatedAt = record.updatedAt
            model.title = state.title(record.titleID)
            model.person = state.person(record.personID)
            model.collection = state.collection(record.collectionID)
            context.insert(model)
            state.report.note(created: .resourceLinks)
            try checkpoint(state)
        }

        for record in document.savedLinks {
            if try exists(SavedLink.self, record.id) {
                state.report.note(skipped: .savedLinks)
                continue
            }
            let model = SavedLink()
            model.id = record.id
            model.urlString = record.urlString
            model.name = record.name
            model.notes = record.notes
            model.faviconData = record.faviconData
            model.kindRaw = record.kindRaw
            model.isPrivate = record.isPrivate
            model.isArchived = record.isArchived
            model.deletedAt = record.deletedAt
            model.createdAt = record.createdAt
            model.library = state.library(record.libraryID)
            model.genre = state.genre(record.genreID)
            // `searchText` est un dérivé : il se recalcule, il ne se transporte pas. Et
            // `refreshDerived()` posant `updatedAt = .now`, la date de l'archive se
            // repose **après** — sinon toute la sauvegarde daterait du jour de sa
            // restauration.
            model.refreshDerived()
            model.updatedAt = record.updatedAt
            context.insert(model)
            state.report.note(created: .savedLinks)
            try checkpoint(state)
        }
    }

    private func restoreFlags(_ document: ArchiveDocument, into state: RestoreState) throws {
        for record in document.titleFlags {
            if try exists(TitleFlag.self, record.id) {
                state.report.note(skipped: .titleFlags)
                continue
            }
            let model = TitleFlag()
            model.id = record.id
            model.isFavorite = record.isFavorite
            model.isInWatchlist = record.isInWatchlist
            model.isWatched = record.isWatched
            model.watchedAt = record.watchedAt
            model.personalRating = record.personalRating
            model.updatedAt = record.updatedAt
            model.profile = state.profile(record.profileID)
            model.title = state.title(record.titleID)
            context.insert(model)
            state.report.note(created: .titleFlags)
            try checkpoint(state)
        }

        for record in document.personFlags {
            if try exists(PersonFlag.self, record.id) {
                state.report.note(skipped: .personFlags)
                continue
            }
            let model = PersonFlag()
            model.id = record.id
            model.isFavorite = record.isFavorite
            model.updatedAt = record.updatedAt
            model.profile = state.profile(record.profileID)
            model.person = state.person(record.personID)
            context.insert(model)
            state.report.note(created: .personFlags)
            try checkpoint(state)
        }

        for record in document.mediaFlags {
            if try exists(MediaFlag.self, record.id) {
                state.report.note(skipped: .mediaFlags)
                continue
            }
            let model = MediaFlag()
            model.id = record.id
            model.isFavorite = record.isFavorite
            model.updatedAt = record.updatedAt
            model.profile = state.profile(record.profileID)
            model.asset = state.asset(record.assetID)
            context.insert(model)
            state.report.note(created: .mediaFlags)
            try checkpoint(state)
        }
    }

    private func restoreJournals(_ document: ArchiveDocument, into state: RestoreState) throws {
        for record in document.activityEntries {
            if try exists(ActivityEntry.self, record.id) {
                state.report.note(skipped: .activityEntries)
                continue
            }
            let model = ActivityEntry()
            model.id = record.id
            model.actionRaw = record.actionRaw
            model.entityTypeRaw = record.entityTypeRaw
            model.entityID = record.entityID
            model.summary = record.summary
            model.createdAt = record.createdAt
            model.payload = record.payload
            model.undoneAt = record.undoneAt
            context.insert(model)
            state.report.note(created: .activityEntries)
            try checkpoint(state)
        }

        for record in document.importMappings {
            if try exists(ImportMapping.self, record.id) {
                state.report.note(skipped: .importMappings)
                continue
            }
            let model = ImportMapping()
            model.id = record.id
            model.name = record.name
            model.headerSignature = record.headerSignature
            model.columnMapData = record.columnMapData
            model.isBuiltIn = record.isBuiltIn
            model.createdAt = record.createdAt
            model.updatedAt = record.updatedAt
            model.library = state.library(record.libraryID)
            context.insert(model)
            state.report.note(created: .importMappings)
            try checkpoint(state)
        }

        for record in document.legacyRecords {
            if try exists(LegacyRecord.self, record.id) {
                state.report.note(skipped: .legacyRecords)
                continue
            }
            let model = LegacyRecord()
            model.id = record.id
            model.entityTypeRaw = record.entityTypeRaw
            model.entityID = record.entityID
            model.legacyTable = record.legacyTable
            model.legacyID = record.legacyID
            model.importedAt = record.importedAt
            context.insert(model)
            state.report.note(created: .legacyRecords)
            try checkpoint(state)
        }
    }

    // MARK: - Passe 3

    /// Relie les entités de la passe 1, puis rafraîchit leurs dérivés.
    ///
    /// Séparée de la passe 1 parce que `Title.refreshDerived()` lit `collection`, `genres`
    /// et `credits` pour composer `filterKeys` : l'appeler avant que les relations
    /// existent rendrait un filtre vide, et le titre serait **introuvable par tout
    /// critère** — muet, puisque sa fiche s'affiche parfaitement.
    ///
    /// Et `refreshDerived()` posant `updatedAt = .now`, la date de l'archive se repose
    /// après chaque appel. Sans ça, une archive restaurée daterait entièrement du jour de
    /// la restauration, et « trié par date de modification » deviendrait faux pour le
    /// catalogue complet — sans qu'aucun test de compte ne le voie.
    func restoreDerived(_ document: ArchiveDocument, into state: RestoreState) {
        for record in document.titles where state.createdIDs.contains(record.id) {
            guard let model = state.titles[record.id] else { continue }
            model.library = state.library(record.libraryID)
            model.collection = state.collection(record.collectionID)
            model.genres = record.genreIDs.compactMap { state.genre($0) }
            model.refreshDerived()
            model.updatedAt = record.updatedAt
        }
        for record in document.people where state.createdIDs.contains(record.id) {
            guard let model = state.people[record.id] else { continue }
            model.library = state.library(record.libraryID)
            model.genres = record.genreIDs.compactMap { state.genre($0) }
            model.refreshDerived()
            model.updatedAt = record.updatedAt
        }
        for record in document.collections where state.createdIDs.contains(record.id) {
            guard let model = state.collections[record.id] else { continue }
            model.library = state.library(record.libraryID)
            model.refreshDerived()
            model.updatedAt = record.updatedAt
        }
        for record in document.genres where state.createdIDs.contains(record.id) {
            guard let model = state.genres[record.id] else { continue }
            model.library = state.library(record.libraryID)
            model.refreshDerived()
            model.updatedAt = record.updatedAt
        }
        for record in document.profiles where state.createdIDs.contains(record.id) {
            state.profiles[record.id]?.library = state.library(record.libraryID)
        }

        refreshTouchedTitles(in: state)
    }

    /// Les titres qui **existaient déjà** et qu'une relation vient de toucher.
    ///
    /// Leur `updatedAt` est celui de la **base**, pas celui de l'archive : la fiche
    /// appartient à l'utilisateur, seul son index dérivé était périmé. C'est la différence
    /// avec les titres créés, dont la date vient de la sauvegarde.
    private func refreshTouchedTitles(in state: RestoreState) {
        for id in state.titlesNeedingRefresh {
            guard let model = state.titles[id] else { continue }
            let stamp = model.updatedAt
            model.refreshDerived()
            model.updatedAt = stamp
            state.report.refreshedDerivedCount += 1
        }
    }
}
