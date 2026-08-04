import Foundation
import SwiftData

// MARK: - Appliquer une mutation à une sélection
//
// Trois précautions, chacune contre un mode de défaillance mesuré ou documenté :
//
// 1. **Un contexte dédié, créé depuis le conteneur.** `rollback()` annule les
//    changements en attente du contexte *entier*. Partager celui des vues signifierait
//    qu'un lot refusé emporte la saisie en cours dans un éditeur ouvert.
//
// 2. **L'autosave coupé.** `rollback()` ne défait que ce qui est *en attente* : si un
//    enregistrement automatique s'intercale au milieu du lot, la première moitié est
//    déjà sur disque et le rollback ne la ramène pas. Vérifié sur l'API :
//    `autosaveEnabled` est réglable, et `rollback()` remet bien `hasChanges` à `false`.
//
// 3. **La validation avant la première écriture.** Pas « muter puis vérifier puis
//    annuler » : muter, c'est déjà mettre le contexte dans un état dont il faut sortir.
//
// **Pourquoi `@MainActor` et non un acteur dédié.** Les repositories le sont, parce
// qu'ils tiennent un `SpotlightIndexer` dont l'implémentation concrète l'est. Les
// contourner pour gagner un acteur reviendrait à muter les relations en direct, donc à
// perdre `refreshDerived()` et à rendre `filterKeys` faux en silence — le prix est trop
// élevé pour le bénéfice. Le lot reste borné par construction : il porte sur une
// sélection que l'utilisateur a sous les yeux, pas sur un import. L'insertion massive,
// c'est `ImportActor` et sa sauvegarde par lots de 200, et c'est le sujet de `L11`.
// `BulkEditPerformanceTests` mesure le coût réel pour que le jour où ce raisonnement
// cesse d'être vrai se voie.

/// Applique une mutation de masse à une sélection, en tout ou rien.
@MainActor
public struct BulkEditor {

    /// Le contexte dédié de l'éditeur. N'enregistre jamais tout seul.
    let context: ModelContext

    /// Construit un éditeur avec son propre contexte, isolé de celui des vues.
    public init(container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context
    }

    /// Pour les tests, et pour un appelant qui a déjà un contexte isolé à lui.
    ///
    /// - Warning: le contexte passé ne doit pas être celui des vues — un `rollback()`
    ///   y annulerait leurs modifications en attente. `autosaveEnabled` est forcé à
    ///   `false`, sans quoi la garantie de tout ou rien ne tient pas.
    public init(isolatedContext context: ModelContext) {
        context.autosaveEnabled = false
        self.context = context
    }

    // MARK: Titres

    /// Applique `mutation` aux titres désignés.
    ///
    /// - Parameters:
    ///   - mutation: ce qu'il faut changer.
    ///   - ids: la sélection. Les doublons sont ignorés, l'ordre n'importe pas.
    ///   - summary: la ligne du fil d'activité. Fournie par l'appelant, qui seul connaît
    ///     le libellé de la valeur choisie dans son interface.
    /// - Returns: `.applied` avec l'identifiant de l'entrée de journal, ou `.refused`
    ///   avec un refus par cause — et dans ce cas **rien n'a été écrit**.
    /// - Throws: l'erreur de `fetch`, d'encodage du diff ou de `save()`. Le contexte est
    ///   ramené à son état d'avant dans tous les cas.
    @discardableResult
    public func apply(
        _ mutation: TitleBulkMutation,
        toTitles ids: [UUID],
        summary: String
    ) throws -> BulkEditOutcome {
        let unique = Set(ids)
        guard !unique.isEmpty else { return .empty }

        do {
            let titles = try context.fetch(
                FetchDescriptor(predicate: TitleQuery.withIDs(unique)))
            let genres = try resolveGenres(mutation.referencedIDs, target: .title)
            let collection = try resolveCollection(mutation)

            var refusals = entityRefusals(requested: unique, found: titles)
            refusals += validate(mutation)
            for title in titles where title.deletedAt == nil {
                refusals += relationRefusals(
                    for: title.id,
                    library: title.library?.id,
                    requestedGenreIDs: mutation.touchesGenres ? mutation.referencedIDs : [],
                    genres: genres,
                    collection: mutation.touchesCollection ? collection : nil
                )
            }
            guard refusals.isEmpty else { return .refused(dedupe(refusals)) }

            let repository = TitleRepository(context: context)
            let entries = titles.map {
                applyToTitle(
                    $0, mutation, repository: repository,
                    genres: genres, collection: collection?.value)
            }

            let activityID = try journal(
                summary: summary, field: mutation.field, operation: mutation.kind,
                entityType: .title, entries: entries)
            try context.save()
            return .applied(count: titles.count, activityID: activityID)
        } catch {
            // Toute sortie non nominale laisse le contexte propre : sans ça, la mutation
            // partielle resterait en attente et le prochain `save()` l'écrirait.
            context.rollback()
            throw error
        }
    }

    // MARK: Personnes

    /// Applique `mutation` aux personnes désignées. Mêmes garanties que pour les titres.
    @discardableResult
    public func apply(
        _ mutation: PersonBulkMutation,
        toPeople ids: [UUID],
        summary: String
    ) throws -> BulkEditOutcome {
        let unique = Set(ids)
        guard !unique.isEmpty else { return .empty }

        do {
            let people = try context.fetch(
                FetchDescriptor(predicate: PersonQuery.withIDs(unique)))
            let genres = try resolveGenres(mutation.referencedIDs, target: .person)

            var refusals = entityRefusals(requested: unique, found: people)
            refusals += validate(mutation)
            for person in people where person.deletedAt == nil {
                refusals += relationRefusals(
                    for: person.id,
                    library: person.library?.id,
                    requestedGenreIDs: mutation.touchesGenres ? mutation.referencedIDs : [],
                    genres: genres,
                    collection: nil
                )
            }
            guard refusals.isEmpty else { return .refused(dedupe(refusals)) }

            let repository = PersonRepository(context: context)
            let entries = people.map {
                applyToPerson($0, mutation, repository: repository, genres: genres)
            }

            let activityID = try journal(
                summary: summary, field: mutation.field, operation: mutation.kind,
                entityType: .person, entries: entries)
            try context.save()
            return .applied(count: people.count, activityID: activityID)
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Résolution des relations

    /// Les genres cités, indexés par identifiant.
    ///
    /// La cible est vérifiée ici et non par le prédicat : un genre de la mauvaise cible
    /// doit produire un refus **nommé**, pas disparaître du lot comme s'il n'existait
    /// pas. C'est la différence entre « ce genre ne s'applique pas aux personnes » et
    /// « ce genre n'existe plus », et l'utilisateur n'a pas la même chose à faire.
    private func resolveGenres(_ ids: [UUID], target: GenreTarget) throws -> [UUID: Genre] {
        guard !ids.isEmpty else { return [:] }
        let found = try context.fetch(FetchDescriptor(predicate: GenreQuery.withIDs(Set(ids))))
        return Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
            .filter { $0.value.target == target }
    }

    /// La collection citée, si la mutation en cite une.
    ///
    /// Enveloppée pour distinguer « la mutation ne touche pas la collection » (`nil`) de
    /// « elle la vide » (`Box(nil)`) : les deux cas n'appellent pas la même validation.
    private func resolveCollection(_ mutation: TitleBulkMutation) throws -> Box<TitleCollection?>? {
        switch mutation {
        case .setCollection(let id):
            let found = try context.fetch(
                FetchDescriptor(predicate: CollectionQuery.withIDs([id])))
            return Box(found.first)
        case .clearCollection:
            return Box(nil)
        default:
            return nil
        }
    }

    /// Une valeur enveloppée, pour qu'un `nil` intentionnel se distingue d'une absence.
    struct Box<Value> {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    // MARK: - Journal

    /// Écrit l'entrée unique du lot, avec son diff.
    ///
    /// Une entrée pour tout le lot, pas une par ligne : cinquante titres modifiés ne
    /// doivent pas produire cinquante lignes dans le fil. C'est pour ça que les
    /// mutations passent `journal: .batched` aux repositories — sans quoi chacun
    /// écrirait la sienne en plus de celle-ci.
    ///
    /// `entityID` porte l'identifiant de l'entrée elle-même : il n'y a pas d'entité
    /// unique à désigner, et le détail vit dans le `payload`.
    private func journal(
        summary: String,
        field: String,
        operation: BulkOperationKind,
        entityType: ActivityEntityType,
        entries: [BulkEditDiff.Entry]
    ) throws -> UUID {
        let diff = BulkEditDiff(
            summary: summary, field: field, operation: operation, entries: entries)
        let entry = ActivityEntry.make(
            action: .bulkEdit, entityType: entityType, entityID: UUID(), summary: summary)
        entry.payload = try diff.encoded()
        context.insert(entry)
        return entry.id
    }

    // MARK: - Refus

    /// Les entités absentes du magasin, et celles qui sont à la corbeille.
    private func entityRefusals(
        requested: Set<UUID>,
        found: [some SoftDeletable]
    ) -> [BulkRefusal] {
        var refusals = requested.subtracting(found.map(\.id))
            .map { BulkRefusal(entityID: $0, reason: .entityNotFound) }
        refusals += found.filter { $0.deletedAt != nil }
            .map { BulkRefusal(entityID: $0.id, reason: .entityDeleted) }
        return refusals
    }

    /// Les refus liés aux relations citées, pour une entité donnée.
    ///
    /// La bibliothèque est comparée **par entité** et non une fois pour toutes : une
    /// sélection peut mélanger deux bibliothèques, et un genre valide pour l'une ne
    /// l'est pas pour l'autre. C'est la cause la plus sournoise de la liste — rien ne
    /// l'empêche techniquement, et le résultat est un genre qui fuit d'un catalogue à
    /// l'autre.
    private func relationRefusals(
        for entityID: UUID,
        library libraryID: UUID?,
        requestedGenreIDs: [UUID],
        genres: [UUID: Genre],
        collection: Box<TitleCollection?>?
    ) -> [BulkRefusal] {
        var refusals: [BulkRefusal] = []

        for id in requestedGenreIDs {
            guard let genre = genres[id] else {
                // Absent du dictionnaire : soit il n'existe pas, soit sa cible ne
                // correspond pas. Les deux se distinguent par une seconde lecture, mais
                // la cause utile à l'utilisateur est la même — cette valeur ne convient
                // pas. Le cas de cible est nommé à part quand il est identifiable.
                refusals.append(BulkRefusal(entityID: entityID, reason: .relationNotFound(id)))
                continue
            }
            if genre.deletedAt != nil {
                refusals.append(BulkRefusal(entityID: entityID, reason: .relationNotFound(id)))
            } else if genre.library?.id != libraryID {
                refusals.append(
                    BulkRefusal(entityID: entityID, reason: .relationInAnotherLibrary(id)))
            }
        }

        if let collection {
            if let target = collection.value {
                if target.deletedAt != nil {
                    refusals.append(
                        BulkRefusal(entityID: entityID, reason: .relationNotFound(target.id)))
                } else if target.library?.id != libraryID {
                    refusals.append(
                        BulkRefusal(
                            entityID: entityID, reason: .relationInAnotherLibrary(target.id)))
                }
            }
        }

        return refusals
    }

    /// Dédoublonne les refus en gardant l'ordre de découverte.
    ///
    /// Une même relation fautive vaut pour toutes les entités de la sélection : sans ça,
    /// cinquante titres et un genre d'une autre bibliothèque produiraient cinquante
    /// refus qui disent la même chose. L'entité reste dans la clé, donc deux entités
    /// fautives pour des raisons différentes restent deux refus.
    private func dedupe(_ refusals: [BulkRefusal]) -> [BulkRefusal] {
        var seen = Set<BulkRefusal>()
        return refusals.filter { seen.insert($0).inserted }
    }
}

// MARK: - Ce que l'éditeur exige d'une entité

/// Une entité qui peut être à la corbeille.
///
/// Existe pour que `entityRefusals` traite les titres et les personnes du même code : la
/// vérification « existe, et n'est pas à la corbeille » est identique, et la dupliquer
/// laisserait l'une des deux dériver.
public protocol SoftDeletable {
    var id: UUID { get }
    var deletedAt: Date? { get }
}

extension Title: SoftDeletable {}
extension Person: SoftDeletable {}

extension BulkEditOutcome {
    /// Une sélection vide : rien à faire, et ce n'est pas une erreur.
    ///
    /// `activityID` est l'identifiant nul, pas un `UUID()` frais : rien n'a été écrit,
    /// donc il ne désigne aucune entrée de journal, et un identifiant aléatoire
    /// laisserait croire le contraire à `L20`.
    static var empty: BulkEditOutcome {
        .applied(count: 0, activityID: BulkRefusal.mutationScope)
    }
}
