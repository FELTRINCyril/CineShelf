import Foundation
import SwiftData

// MARK: - L20 · Ce qu'une entité sait dire et refaire d'elle-même
//
// **Le miroir de `BulkEditor+Apply`, et il doit le rester.** Là-bas un champ est écrit et son
// avant/après journalisé ; ici le même champ est relu pour vérification, puis remis à sa valeur
// d'avant. Les deux tables se lisent côte à côte, et un champ ajouté d'un seul côté est un
// champ qu'on ne saura pas défaire — silencieusement, puisque le diff le portera quand même.
//
// **Le `default` est un refus, jamais une abstention.** Un nom de champ inconnu rend `nil` à la
// lecture, ce qui ne peut pas égaler la valeur `after` attendue : l'annulation refuse alors le
// lot au lieu de sauter le champ. C'est ce qui fait de l'oubli ci-dessus une erreur visible
// plutôt qu'une restauration muette et incomplète.

/// Une entité qu'un lot a touchée, vue par l'annulation.
///
/// `@MainActor` comme les repositories qu'elle appelle : `BulkEditUndoer` l'est déjà, et
/// laisser ce type nonisolé obligerait chaque appel à traverser une frontière d'acteur pour
/// rien.
///
/// Un `enum` et non un protocole : les deux cas ont des champs disjoints, et un protocole
/// obligerait chaque modèle à porter une table de chaînes qui n'a de sens que pour `L20`.
@MainActor
enum UndoSubject {
    case title(Title)
    case person(Person)

    var deletedAt: Date? {
        switch self {
        case .title(let title): title.deletedAt
        case .person(let person): person.deletedAt
        }
    }

    /// La valeur actuelle d'un champ, **encodée comme le diff l'encode**.
    ///
    /// Passer par `BulkValueCoding` et non par une conversion locale : la comparaison
    /// `current == after` n'a de sens que si les deux côtés sont encodés pareil. Une note de
    /// 4,0 écrite `"4"` d'un côté et `"4.0"` de l'autre ferait refuser une annulation
    /// parfaitement légitime.
    func value(of field: String) -> String? {
        switch self {
        case .title(let title): Self.titleValue(title, field)
        case .person(let person): Self.personValue(person, field)
        }
    }

    /// Découpé en deux par famille, comme l'écriture inverse plus bas et pour la même raison :
    /// `cyclomatic_complexity` refuse la table d'un bloc, et une suite de dix `case` sans
    /// regroupement se relit mal.
    private static func titleValue(_ title: Title, _ field: String) -> String? {
        titleScalarValue(title, field) ?? titleOtherValue(title, field)
    }

    private static func titleScalarValue(_ title: Title, _ field: String) -> String? {
        switch field {
        case "rating": BulkValueCoding.encode(title.rating)
        case "runtimeMinutes": BulkValueCoding.encode(title.runtimeMinutes)
        case "releaseDate": BulkValueCoding.encode(title.releaseDate)
        case "summary": BulkValueCoding.encode(title.summary)
        case "isArchived": BulkValueCoding.encode(title.isArchived)
        case "isPrivate": BulkValueCoding.encode(title.isPrivate)
        default: nil
        }
    }

    private static func titleOtherValue(_ title: Title, _ field: String) -> String? {
        switch field {
        case "kind": title.kindRaw
        case "releasePrecision": title.releasePrecisionRaw
        case "collection": title.collection?.id.uuidString
        // **`deletedAt` est lisible parce qu'une fusion le déplace.** Sans lui, `value(of:)`
        // rendait `nil`, la comparaison avec `after` échouait, et la fusion était refusée pour
        // « champ modifié depuis » alors que rien n'avait bougé.
        case "deletedAt": BulkValueCoding.encode(title.deletedAt)
        default: nil
        }
    }

    private static func personValue(_ person: Person, _ field: String) -> String? {
        switch field {
        case "roles": BulkValueCoding.encode(person.roleValues)
        case "bio": BulkValueCoding.encode(person.bio)
        case "isArchived": BulkValueCoding.encode(person.isArchived)
        case "isPrivate": BulkValueCoding.encode(person.isPrivate)
        case "deletedAt": BulkValueCoding.encode(person.deletedAt)
        default: nil
        }
    }

    /// Les identifiants actuellement rattachés à la relation nommée.
    func relatedIDs(of field: String) -> [UUID] {
        switch (self, field) {
        case (.title(let title), "genres"): (title.genres ?? []).map(\.id)
        case (.person(let person), "genres"): (person.genres ?? []).map(\.id)
        case (.title(let title), "collection"): title.collection.map { [$0.id] } ?? []
        default: []
        }
    }

    /// Remet l'entité dans son état d'avant le lot, **en une seule écriture**.
    ///
    /// L'unicité de l'écriture n'est pas cosmétique : c'est elle qui garantit que
    /// `releaseDate` et `releasePrecision` reviennent ensemble. Les restaurer en deux passes
    /// laisserait, entre les deux, une date au jour près sur une précision à l'année — l'état
    /// exact qui dégradait les dates au prompt 11.
    func restore(
        fields: [String: String?], reattach: [UUID], detach: [UUID], in context: ModelContext
    ) {
        switch self {
        case .title(let title):
            let genres = Self.resolve(reattach, in: context) as [Genre]
            TitleRepository(context: context).update(title, journal: .batched) { title in
                Self.restoreTitle(title, fields: fields, context: context)
                Self.applyRelations(
                    current: title.genres ?? [], reattach: genres, detach: detach,
                    hasRelationChange: !reattach.isEmpty || !detach.isEmpty
                ) { title.genres = $0 }
            }
        case .person(let person):
            let genres = Self.resolve(reattach, in: context) as [Genre]
            PersonRepository(context: context).update(person, journal: .batched) { person in
                Self.restorePerson(person, fields: fields)
                Self.applyRelations(
                    current: person.genres ?? [], reattach: genres, detach: detach,
                    hasRelationChange: !reattach.isEmpty || !detach.isEmpty
                ) { person.genres = $0 }
            }
        }
    }

    // MARK: L'écriture inverse, champ par champ

    /// **Découpé en deux comme `BulkEditor+Apply` l'est en trois**, et pour la même raison :
    /// `cyclomatic_complexity` refuse la table entière d'un bloc, et la règle a raison — une
    /// suite de neuf `case` sans regroupement se relit mal. Le découpage suit les familles de
    /// l'aller, pour que les deux tables restent lisibles côte à côte.
    private static func restoreTitle(
        _ title: Title, fields: [String: String?], context: ModelContext
    ) {
        for (field, value) in fields {
            if restoreTitleScalar(title, field: field, value: value) { continue }
            restoreTitleRelationalOrEnum(title, field: field, value: value, context: context)
        }
    }

    /// Les champs qui se posent sans résolution : nombres, texte, drapeaux.
    ///
    /// - Returns: `true` si le champ a été traité ici.
    private static func restoreTitleScalar(
        _ title: Title, field: String, value: String?
    ) -> Bool {
        switch field {
        case "rating": title.rating = BulkValueCoding.decodeDouble(value)
        case "runtimeMinutes": title.runtimeMinutes = BulkValueCoding.decodeInt(value)
        case "releaseDate": title.releaseDate = BulkValueCoding.decodeDate(value)
        case "summary": title.summary = BulkValueCoding.decodeString(value)
        case "isArchived": title.isArchived = BulkValueCoding.decodeBool(value) ?? false
        case "isPrivate": title.isPrivate = BulkValueCoding.decodeBool(value) ?? false
        case "deletedAt": title.deletedAt = BulkValueCoding.decodeDate(value)
        default: return false
        }
        return true
    }

    /// Les champs qui demandent une résolution : énumérations et relation de collection.
    private static func restoreTitleRelationalOrEnum(
        _ title: Title, field: String, value: String?, context: ModelContext
    ) {
        switch field {
        case "kind":
            // Un `rawValue` inconnu laisse le champ tel quel plutôt que de poser un repli :
            // le diff vient de la base, et une valeur qu'on ne sait pas relire ne doit pas
            // devenir « film » par défaut.
            if let raw = value, let kind = TitleKind(rawValue: raw) { title.kind = kind }
        case "releasePrecision":
            if let raw = value, let precision = DatePrecision(rawValue: raw) {
                title.releasePrecision = precision
            }
        case "collection":
            let collectionID = value.flatMap(UUID.init(uuidString:))
            let collections: [TitleCollection] =
                collectionID.map { Self.resolve([$0], in: context) } ?? []
            title.collection = collections.first
        default:
            // Inatteignable : `value(of:)` a déjà rendu `nil` sur ce champ, donc la
            // vérification l'a refusé avant d'arriver ici. L'assertion existe pour que
            // l'ajout d'un champ à `BulkEditor+Apply` sans son pendant ici se voie en
            // développement plutôt qu'à la première annulation.
            assertionFailure("Champ de titre sans écriture inverse : \(field)")
        }
    }

    private static func restorePerson(_ person: Person, fields: [String: String?]) {
        for (field, value) in fields {
            switch field {
            case "roles":
                let names = BulkValueCoding.decodeStringList(value)
                let roles = Set(names.compactMap(PersonRole.init(rawValue:)))
                // Un rôle vide rendrait la personne inclassable et le filtre par rôle faux ;
                // `L10` refuse déjà de poser un ensemble vide, donc n'en écrire aucun ici est
                // cohérent avec ce que le lot pouvait produire.
                if !roles.isEmpty { person.roles = roles }
            case "bio": person.bio = BulkValueCoding.decodeString(value)
            case "isArchived": person.isArchived = BulkValueCoding.decodeBool(value) ?? false
            case "isPrivate": person.isPrivate = BulkValueCoding.decodeBool(value) ?? false
            case "deletedAt": person.deletedAt = BulkValueCoding.decodeDate(value)
            default:
                assertionFailure("Champ de personne sans écriture inverse : \(field)")
            }
        }
    }

    /// Rejoue l'inverse d'un mouvement de relation.
    ///
    /// **`hasRelationChange` et non « les listes sont vides »** : un lot qui a seulement vidé
    /// une relation a `detached` non vide et `attached` vide, et un lot qui n'a pas touché la
    /// relation a les deux vides. Sans ce drapeau, réécrire la relation dans le second cas
    /// ferait tourner `refreshDerived()` — donc `filterKeys` — sans raison, et journaliserait
    /// un changement qui n'a pas eu lieu.
    private static func applyRelations<T: PersistentModel & Identifiable>(
        current: [T],
        reattach: [T],
        detach: [UUID],
        hasRelationChange: Bool,
        write: ([T]) -> Void
    ) where T.ID == UUID {
        guard hasRelationChange else { return }
        let removed = Set(detach)
        var result = current.filter { !removed.contains($0.id) }
        let present = Set(result.map(\.id))
        result += reattach.filter { !present.contains($0.id) }
        write(result)
    }

    private static func resolve<T: PersistentModel & Identifiable>(
        _ ids: [UUID], in context: ModelContext
    ) -> [T] where T.ID == UUID {
        guard !ids.isEmpty else { return [] }
        let wanted = Set(ids)
        guard let all = try? context.fetch(FetchDescriptor<T>()) else { return [] }
        return all.filter { wanted.contains($0.id) }
    }
}
