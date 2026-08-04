import Foundation
import SwiftData

// MARK: - Muter, et enregistrer ce qu'on a changé
//
// Chaque mutation passe par `repository.update` ou par un mutateur de relation : ce sont
// eux qui appellent `refreshDerived()`, donc qui maintiennent `sortName`, `searchText` et
// `filterKeys`. Écrire `title.genres = …` en direct ici compilerait — on est dans le
// module, la règle SwiftLint ne s'y applique pas — et rendrait le filtre par genre faux
// en silence. C'est le seul endroit du fichier où la discipline remplace l'outil, donc
// c'est écrit gros.
//
// Le diff est capturé **avant** chaque écriture, valeur par valeur. Pas après : une
// relation lue après coup a déjà changé, et un `updatedAt` relu ne dit plus ce qu'il
// valait. C'est ce qui rend le lot annulable par `L20`.

@MainActor
extension BulkEditor {

    /// Aiguille vers la famille de la mutation.
    ///
    /// Ce `switch` est **exhaustif et sans `default`** : c'est lui le filet. Un cas
    /// ajouté à `TitleBulkMutation` casse la compilation ici, ce qui force à décider de
    /// quelle famille il relève. Les deux corps, eux, ont un `default` — il n'est
    /// atteignable que si cet aiguillage est faux.
    func applyToTitle(
        _ title: Title,
        _ mutation: TitleBulkMutation,
        repository: TitleRepository,
        genres: [UUID: Genre],
        collection: TitleCollection?
    ) -> BulkEditDiff.Entry {
        switch mutation {
        case .setRating, .clearRating, .setRuntime, .clearRuntime:
            entry(for: title, titleNumberFields(title, mutation, repository: repository))
        case .setReleaseDate, .clearReleaseDate:
            entry(for: title, titleDateFields(title, mutation, repository: repository))
        case .setKind, .setSummary, .clearSummary, .setArchived, .setPrivate:
            entry(for: title, titleTextAndFlagFields(title, mutation, repository: repository))
        case .setCollection, .clearCollection, .setGenres, .addGenres, .removeGenres,
            .clearGenres:
            titleRelationChange(
                title, mutation, repository: repository, genres: genres, collection: collection)
        }
    }

    /// Enveloppe des changements scalaires dans une entrée de diff.
    private func entry(
        for title: Title,
        _ fields: [BulkEditDiff.FieldChange]
    ) -> BulkEditDiff.Entry {
        BulkEditDiff.Entry(
            entityID: title.id, entityType: .title, fields: fields.filter { !$0.isNoOp })
    }

    /// Note et durée : les deux champs numériques optionnels.
    private func titleNumberFields(
        _ title: Title,
        _ mutation: TitleBulkMutation,
        repository: TitleRepository
    ) -> [BulkEditDiff.FieldChange] {
        var fields: [BulkEditDiff.FieldChange] = []
        switch mutation {
        case .setRating(let value):
            fields.append(
                change("rating", BulkValueCoding.encode(title.rating), BulkValueCoding.encode(value)))
            repository.update(title, journal: .batched) { $0.rating = value }

        case .clearRating:
            fields.append(change("rating", BulkValueCoding.encode(title.rating), nil))
            repository.update(title, journal: .batched) { $0.rating = nil }

        case .setRuntime(let minutes):
            fields.append(
                change(
                    "runtimeMinutes", BulkValueCoding.encode(title.runtimeMinutes),
                    BulkValueCoding.encode(minutes)))
            repository.update(title, journal: .batched) { $0.runtimeMinutes = minutes }

        case .clearRuntime:
            fields.append(
                change("runtimeMinutes", BulkValueCoding.encode(title.runtimeMinutes), nil))
            repository.update(title, journal: .batched) { $0.runtimeMinutes = nil }

        default:
            assertionFailure("Cas non numérique aiguillé ici : \(mutation)")
        }
        return fields
    }

    /// La date de sortie et sa précision, qui bougent toujours ensemble.
    private func titleDateFields(
        _ title: Title,
        _ mutation: TitleBulkMutation,
        repository: TitleRepository
    ) -> [BulkEditDiff.FieldChange] {
        var fields: [BulkEditDiff.FieldChange] = []
        switch mutation {
        case .setReleaseDate(let date, let precision):
            // Les deux champs bougent ensemble : une date sans sa précision se relit
            // comme une date au jour près, et l'annulation restaurerait une précision
            // qu'on n'avait pas. C'est le bug qui avait dégradé les dates exactes en
            // 1er janvier au prompt 11.
            fields.append(
                change(
                    "releaseDate", BulkValueCoding.encode(title.releaseDate),
                    BulkValueCoding.encode(date)))
            fields.append(
                change("releasePrecision", title.releasePrecisionRaw, precision.rawValue))
            repository.update(title, journal: .batched) {
                $0.releaseDate = date
                $0.releasePrecision = precision
            }

        case .clearReleaseDate:
            fields.append(change("releaseDate", BulkValueCoding.encode(title.releaseDate), nil))
            fields.append(
                change("releasePrecision", title.releasePrecisionRaw, DatePrecision.day.rawValue))
            repository.update(title, journal: .batched) {
                $0.releaseDate = nil
                $0.releasePrecision = .day
            }

        default:
            assertionFailure("Cas non daté aiguillé ici : \(mutation)")
        }
        return fields
    }

    /// Type, résumé et les deux drapeaux de visibilité.
    private func titleTextAndFlagFields(
        _ title: Title,
        _ mutation: TitleBulkMutation,
        repository: TitleRepository
    ) -> [BulkEditDiff.FieldChange] {
        var fields: [BulkEditDiff.FieldChange] = []
        switch mutation {
        case .setKind(let kind):
            fields.append(change("kind", title.kindRaw, kind.rawValue))
            repository.update(title, journal: .batched) { $0.kind = kind }

        case .setSummary(let text):
            fields.append(change("summary", title.summary, text))
            repository.update(title, journal: .batched) { $0.summary = text }

        case .clearSummary:
            fields.append(change("summary", title.summary, nil))
            repository.update(title, journal: .batched) { $0.summary = nil }

        case .setArchived(let value):
            fields.append(
                change("isArchived", BulkValueCoding.encode(title.isArchived), BulkValueCoding.encode(value)))
            repository.update(title, journal: .batched) { $0.isArchived = value }

        case .setPrivate(let value):
            fields.append(
                change("isPrivate", BulkValueCoding.encode(title.isPrivate), BulkValueCoding.encode(value)))
            repository.update(title, journal: .batched) { $0.isPrivate = value }

        default:
            assertionFailure("Cas non textuel aiguillé ici : \(mutation)")
        }
        return fields
    }

    /// Les relations d'un titre : collection et genres.
    private func titleRelationChange(
        _ title: Title,
        _ mutation: TitleBulkMutation,
        repository: TitleRepository,
        genres: [UUID: Genre],
        collection: TitleCollection?
    ) -> BulkEditDiff.Entry {
        var fields: [BulkEditDiff.FieldChange] = []
        var attached: [UUID] = []
        var detached: [UUID] = []

        switch mutation {
        case .setCollection:
            let before = title.collection?.id
            fields.append(
                change("collection", before?.uuidString, collection?.id.uuidString))
            if let before { detached.append(before) }
            if let target = collection { attached.append(target.id) }
            repository.setCollection(collection, on: title, journal: .batched)

        case .clearCollection:
            let before = title.collection?.id
            fields.append(change("collection", before?.uuidString, nil))
            if let before { detached.append(before) }
            repository.setCollection(nil, on: title, journal: .batched)

        case .setGenres(let ids):
            let before = title.genres ?? []
            let beforeIDs = Set(before.map(\.id))
            let wanted = ids.compactMap { genres[$0] }
            let wantedIDs = Set(wanted.map(\.id))
            attached = Array(wantedIDs.subtracting(beforeIDs))
            detached = Array(beforeIDs.subtracting(wantedIDs))
            repository.setGenres(wanted, on: title, journal: .batched)

        case .addGenres(let ids):
            let before = title.genres ?? []
            let beforeIDs = Set(before.map(\.id))
            let added = ids.compactMap { genres[$0] }.filter { !beforeIDs.contains($0.id) }
            attached = added.map(\.id)
            repository.setGenres(before + added, on: title, journal: .batched)

        case .removeGenres(let ids):
            let before = title.genres ?? []
            let removing = Set(ids)
            detached = before.map(\.id).filter(removing.contains)
            repository.setGenres(before.filter { !removing.contains($0.id) }, on: title, journal: .batched)

        case .clearGenres:
            let before = title.genres ?? []
            detached = before.map(\.id)
            repository.setGenres([], on: title, journal: .batched)

        default:
            assertionFailure("Cas scalaire aiguillé vers le corps de relation : \(mutation)")
        }

        return BulkEditDiff.Entry(
            entityID: title.id,
            entityType: .title,
            fields: fields.filter { !$0.isNoOp },
            attached: attached.sorted { $0.uuidString < $1.uuidString },
            detached: detached.sorted { $0.uuidString < $1.uuidString }
        )
    }

    func applyToPerson(
        _ person: Person,
        _ mutation: PersonBulkMutation,
        repository: PersonRepository,
        genres: [UUID: Genre]
    ) -> BulkEditDiff.Entry {
        var fields: [BulkEditDiff.FieldChange] = []
        var attached: [UUID] = []
        var detached: [UUID] = []

        switch mutation {
        case .setRoles(let roles):
            fields.append(
                change(
                    "roles", BulkValueCoding.encode(person.roleValues),
                    BulkValueCoding.encode(roles.map(\.rawValue))))
            repository.setRoles(roles, on: person, journal: .batched)

        case .setBio(let text):
            fields.append(change("bio", person.bio, text))
            repository.update(person, journal: .batched) { $0.bio = text }

        case .clearBio:
            fields.append(change("bio", person.bio, nil))
            repository.update(person, journal: .batched) { $0.bio = nil }

        case .setArchived(let value):
            fields.append(
                change("isArchived", BulkValueCoding.encode(person.isArchived), BulkValueCoding.encode(value)))
            repository.update(person, journal: .batched) { $0.isArchived = value }

        case .setPrivate(let value):
            fields.append(
                change("isPrivate", BulkValueCoding.encode(person.isPrivate), BulkValueCoding.encode(value)))
            repository.update(person, journal: .batched) { $0.isPrivate = value }

        case .setGenres(let ids):
            let before = person.genres ?? []
            let beforeIDs = Set(before.map(\.id))
            let wanted = ids.compactMap { genres[$0] }
            let wantedIDs = Set(wanted.map(\.id))
            attached = Array(wantedIDs.subtracting(beforeIDs))
            detached = Array(beforeIDs.subtracting(wantedIDs))
            repository.setGenres(wanted, on: person, journal: .batched)

        case .addGenres(let ids):
            let before = person.genres ?? []
            let beforeIDs = Set(before.map(\.id))
            let added = ids.compactMap { genres[$0] }.filter { !beforeIDs.contains($0.id) }
            attached = added.map(\.id)
            repository.setGenres(before + added, on: person, journal: .batched)

        case .removeGenres(let ids):
            let before = person.genres ?? []
            let removing = Set(ids)
            detached = before.map(\.id).filter(removing.contains)
            repository.setGenres(before.filter { !removing.contains($0.id) }, on: person, journal: .batched)

        case .clearGenres:
            let before = person.genres ?? []
            detached = before.map(\.id)
            repository.setGenres([], on: person, journal: .batched)
        }

        return BulkEditDiff.Entry(
            entityID: person.id,
            entityType: .person,
            fields: fields.filter { !$0.isNoOp },
            attached: attached.sorted { $0.uuidString < $1.uuidString },
            detached: detached.sorted { $0.uuidString < $1.uuidString }
        )
    }

    private func change(
        _ field: String,
        _ before: String?,
        _ after: String?
    ) -> BulkEditDiff.FieldChange {
        BulkEditDiff.FieldChange(field: field, before: before, after: after)
    }
}
