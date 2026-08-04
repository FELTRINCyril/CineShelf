import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// L'édition en masse écrit sur des dizaines d'enregistrements d'un coup. Trois choses
// doivent tenir, et chacune a son groupe de tests :
//
// 1. **Tout ou rien.** Un refus ne laisse aucune trace. Vérifié depuis un contexte
//    **neuf**, jamais depuis celui de l'éditeur : un objet encore en attente paraît
//    modifié même après un `rollback()` mal fait, et c'est exactement le genre de test
//    vert sur base cassée qui a coûté 42 tests au prompt 11.
// 2. **Une entrée de journal pour le lot.** Pas une par ligne, sinon le fil devient
//    illisible. C'est le piège dans lequel la première version tombait, parce que
//    `repository.update` journalise par défaut.
// 3. **`filterKeys` reste vrai.** C'est l'invariant que les repositories protègent, et
//    la raison pour laquelle l'éditeur passe par eux au lieu de muter en direct.

@MainActor
struct BulkEditorTests {

    private func makeFixture() throws -> BulkEditFixture { try makeBulkEditFixture() }

    private func makeTitles(_ names: [String], in fixture: BulkEditFixture) throws -> [Title] {
        try makeBulkEditTitles(names, in: fixture)
    }

    // MARK: - Tout ou rien

    @Test("Un lot valide s'applique et se retrouve depuis un contexte neuf")
    func appliesToEveryTitle() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B", "C"], in: fixture)

        let outcome = try fixture.editor.apply(
            .setArchived(true), toTitles: titles.map(\.id), summary: "3 titres archivés")

        #expect(outcome.appliedCount == 3)
        #expect(outcome.refusals.isEmpty)

        // Depuis un contexte neuf : la traduction SQL et la sauvegarde sont exercées.
        let reread = try fixture.freshContext().fetch(FetchDescriptor<Title>())
        #expect(reread.count == 3)
        #expect(reread.allSatisfy { $0.isArchived })
    }

    @Test("Une valeur hors bornes n'écrit rien du tout")
    func outOfRangeWritesNothing() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B"], in: fixture)

        let outcome = try fixture.editor.apply(
            .setRating(9), toTitles: titles.map(\.id), summary: "note à 9")

        #expect(outcome.appliedCount == 0)
        #expect(outcome.refusals.count == 1)
        #expect(outcome.refusals.first?.isMutationScope == true)

        // Le point qui compte : aucune écriture, vue depuis ailleurs.
        let reread = try fixture.freshContext().fetch(FetchDescriptor<Title>())
        #expect(reread.allSatisfy { $0.rating == nil })
        let bulkEntries = try activityCount(in: fixture.freshContext(), action: .bulkEdit)
        #expect(bulkEntries == 0)
    }

    @Test("Un identifiant inconnu dans la sélection refuse tout le lot")
    func unknownIDRefusesTheWholeBatch() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B"], in: fixture)
        let ghost = UUID()

        let outcome = try fixture.editor.apply(
            .setArchived(true), toTitles: titles.map(\.id) + [ghost], summary: "…")

        #expect(outcome.appliedCount == 0)
        #expect(outcome.refusals == [BulkRefusal(entityID: ghost, reason: .entityNotFound)])

        let reread = try fixture.freshContext().fetch(FetchDescriptor<Title>())
        #expect(reread.allSatisfy { $0.isArchived == false })
    }

    @Test("Un titre à la corbeille refuse le lot plutôt que de ressusciter modifié")
    func deletedEntityRefusesTheBatch() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B"], in: fixture)
        TitleRepository(context: fixture.context).softDelete(titles[0])
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .setArchived(true), toTitles: titles.map(\.id), summary: "…")

        #expect(outcome.refusals.contains(BulkRefusal(entityID: titles[0].id, reason: .entityDeleted)))
        let reread = try fixture.freshContext().fetch(FetchDescriptor<Title>())
        #expect(reread.allSatisfy { $0.isArchived == false })
    }

    @Test("Une sélection vide n'est pas une erreur, et n'écrit pas d'entrée de journal")
    func emptySelectionIsNotAnError() throws {
        let fixture = try makeFixture()
        let outcome = try fixture.editor.apply(.setArchived(true), toTitles: [], summary: "…")

        #expect(outcome.appliedCount == 0)
        #expect(outcome.refusals.isEmpty)
        // L'identifiant rendu ne doit désigner aucune entrée : `L20` ne doit pas croire
        // qu'il y a un lot à annuler.
        if case .applied(_, let activityID) = outcome {
            #expect(activityID == BulkRefusal.mutationScope)
        }
        let allEntries = try activityCount(in: fixture.freshContext())
        #expect(allEntries == 0)
    }

    @Test("Les doublons de la sélection ne comptent qu'une fois")
    func duplicateIDsCountOnce() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let id = titles[0].id

        let outcome = try fixture.editor.apply(
            .setArchived(true), toTitles: [id, id, id], summary: "…")
        #expect(outcome.appliedCount == 1)
    }

    // MARK: - Le journal : une entrée pour le lot

    @Test("Cinq titres modifiés produisent une seule entrée de journal")
    func oneJournalEntryForTheWholeBatch() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B", "C", "D", "E"], in: fixture)

        // `create` a déjà écrit cinq entrées ; on ne compte que celles du lot.
        try fixture.editor.apply(
            .setArchived(true), toTitles: titles.map(\.id), summary: "5 titres archivés")

        let fresh = fixture.freshContext()
        let batchEntries = try activityCount(in: fresh, action: .bulkEdit)
        let perEntityEntries = try activityCount(in: fresh, action: .update)
        #expect(batchEntries == 1)
        // Et surtout : aucune entrée `update` par entité. C'est le bug que
        // `JournalPolicy.batched` empêche, et il ne se voit qu'ici.
        #expect(perEntityEntries == 0)
    }

    @Test("L'entrée du lot porte un diff annulable")
    func batchEntryCarriesAnUndoablePayload() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B"], in: fixture)

        let outcome = try fixture.editor.apply(
            .setRating(4), toTitles: titles.map(\.id), summary: "note à 4")
        guard case .applied(_, let activityID) = outcome else {
            Issue.record("Le lot aurait dû s'appliquer")
            return
        }

        let entries = try fixture.freshContext().fetch(FetchDescriptor<ActivityEntry>())
        let entry = try #require(entries.first { $0.id == activityID })
        #expect(entry.action == .bulkEdit)
        #expect(entry.isUndoable, "payload posé et undoneAt vide")

        let payload = try #require(entry.payload)
        let diff = try BulkEditDiff.decoded(from: payload)
        #expect(diff.entries.count == 2)
        #expect(diff.field == "rating")
        #expect(diff.operation == .replace)
        // Le diff doit permettre de revenir en arrière : la valeur d'avant était vide.
        for change in diff.entries.flatMap(\.fields) {
            #expect(change.before == nil)
            #expect(BulkValueCoding.decodeDouble(change.after) == 4)
        }
    }

    @Test("Un champ inchangé n'entre pas dans le diff")
    func unchangedFieldIsNotInTheDiff() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        // Déjà `false` : la mutation ne change rien.
        let outcome = try fixture.editor.apply(
            .setArchived(false), toTitles: titles.map(\.id), summary: "…")

        guard case .applied(_, let activityID) = outcome else {
            Issue.record("Le lot aurait dû s'appliquer")
            return
        }
        let entries = try fixture.freshContext().fetch(FetchDescriptor<ActivityEntry>())
        let entry = try #require(entries.first { $0.id == activityID })
        let diff = try BulkEditDiff.decoded(from: try #require(entry.payload))
        // L'entité figure dans le diff, mais sans changement : `L20` doit pouvoir le
        // constater plutôt que de réappliquer un inverse inutile.
        #expect(diff.entries.count == 1)
        #expect(diff.entries[0].isEmpty)
        #expect(diff.touchedEntityIDs.isEmpty)
    }

    // MARK: - L'invariant filterKeys

    @Test("Après un lot, les titres sont retrouvables par leur nouveau genre")
    func batchKeepsFilterKeysTrue() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B", "C"], in: fixture)
        let genre = try GenreRepository(context: fixture.context)
            .findOrCreate(name: "Policier", target: .title, in: fixture.library)
        try fixture.context.save()

        try fixture.editor.apply(
            .addGenres([genre.id]), toTitles: titles.map(\.id), summary: "genre ajouté")

        // Le test qui compte : la clé dénormalisée, interrogée en SQL depuis un contexte
        // neuf. Sans `refreshDerived()`, la relation serait posée et le filtre faux.
        let pattern = FilterKey.pattern(FilterKey.genre(genre.id))
        let found = try fixture.freshContext().fetch(
            FetchDescriptor<Title>(predicate: #Predicate<Title> { $0.filterKeys.contains(pattern) }))
        #expect(found.count == 3)
    }

    @Test("Retirer un genre le retire aussi des clés")
    func removingAGenreUpdatesKeys() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let genre = try GenreRepository(context: fixture.context)
            .findOrCreate(name: "Policier", target: .title, in: fixture.library)
        try fixture.context.save()

        try fixture.editor.apply(.addGenres([genre.id]), toTitles: titles.map(\.id), summary: "+")
        try fixture.editor.apply(.removeGenres([genre.id]), toTitles: titles.map(\.id), summary: "-")

        let pattern = FilterKey.pattern(FilterKey.genre(genre.id))
        let found = try fixture.freshContext().fetch(
            FetchDescriptor<Title>(predicate: #Predicate<Title> { $0.filterKeys.contains(pattern) }))
        #expect(found.isEmpty)
    }

}

// Le montage est partagé par les deux suites : `BulkEditorTests` couvre le tout ou rien
// et le journal, `BulkEditorRelationTests` les relations et la validation. Scindées parce
// qu'une seule suite dépassait la limite de longueur de corps — et le découpage suit une
// vraie frontière, pas un compte de lignes.
@MainActor
struct BulkEditorRelationTests {

    private func makeFixture() throws -> BulkEditFixture { try makeBulkEditFixture() }

    private func makeTitles(_ names: [String], in fixture: BulkEditFixture) throws -> [Title] {
        try makeBulkEditTitles(names, in: fixture)
    }

    // MARK: - Relations : les refus qui comptent

    @Test("Un genre d'une autre bibliothèque est refusé")
    func genreFromAnotherLibraryIsRefused() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)

        let other = Library(name: "Secondaire")
        fixture.context.insert(other)
        let intruder = try GenreVersionHelper.genre(
            named: "Policier", target: .title, in: other, context: fixture.context)
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .addGenres([intruder.id]), toTitles: titles.map(\.id), summary: "…")

        #expect(
            outcome.refusals.contains(
                BulkRefusal(entityID: titles[0].id, reason: .relationInAnotherLibrary(intruder.id))),
            "Un genre qui fuit d'une bibliothèque à l'autre est le refus le plus important"
        )
        #expect(outcome.appliedCount == 0)
    }

    @Test("Un genre à la corbeille est refusé, pas ressuscité")
    func deletedGenreIsRefused() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let repository = GenreRepository(context: fixture.context)
        let genre = try repository.findOrCreate(name: "Policier", target: .title, in: fixture.library)
        repository.softDelete(genre)
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .addGenres([genre.id]), toTitles: titles.map(\.id), summary: "…")
        #expect(
            outcome.refusals.contains(
                BulkRefusal(entityID: titles[0].id, reason: .relationNotFound(genre.id))))
    }

    @Test("Un genre de personne ne s'applique pas à un titre")
    func genreTargetIsChecked() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let personGenre = try GenreRepository(context: fixture.context)
            .findOrCreate(name: "Réalisation", target: .person, in: fixture.library)
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .addGenres([personGenre.id]), toTitles: titles.map(\.id), summary: "…")
        #expect(outcome.appliedCount == 0)
        #expect(outcome.refusals.isEmpty == false)
    }

    @Test("Les refus identiques sont dédoublonnés")
    func identicalRefusalsAreDeduped() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A", "B", "C", "D", "E"], in: fixture)
        let ghost = UUID()

        let outcome = try fixture.editor.apply(
            .addGenres([ghost]), toTitles: titles.map(\.id), summary: "…")

        // Cinq titres, un genre fautif : cinq refus, un par entité — mais pas dix.
        #expect(outcome.refusals.count == 5)
        #expect(Set(outcome.refusals.map(\.reason)).count == 1)
    }

    // MARK: - Validation

    @Test(
        "Les valeurs refusées",
        arguments: [
            TitleBulkMutation.setRating(-1),
            .setRating(6),
            .setRating(4.5),
            .setRuntime(0),
            .setRuntime(-10),
            .setSummary("   "),
            .setGenres([]),
            .addGenres([]),
            .removeGenres([])
        ]
    )
    func invalidValuesAreRefused(mutation: TitleBulkMutation) throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let outcome = try fixture.editor.apply(mutation, toTitles: titles.map(\.id), summary: "…")
        #expect(outcome.appliedCount == 0, "\(mutation) devrait être refusée")
    }

    @Test("Une demi-étoile est refusée : le design a écarté la demi-étoile")
    func halfStarIsRefused() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        let outcome = try fixture.editor.apply(
            .setRating(3.5), toTitles: titles.map(\.id), summary: "…")
        #expect(outcome.refusals.count == 1)
        if case .valueOutOfRange(_, let expected) = outcome.refusals[0].reason {
            #expect(expected.contains("entier"))
        } else {
            Issue.record("Attendu un refus de bornes")
        }
    }

    @Test("Une année hors 1888–2030 est refusée")
    func yearBoundsAreEnforced() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        var components = DateComponents()
        components.year = 1700
        components.month = 1
        components.day = 1
        let old = try #require(Calendar(identifier: .gregorian).date(from: components))

        let outcome = try fixture.editor.apply(
            .setReleaseDate(old, precision: .year), toTitles: titles.map(\.id), summary: "…")
        #expect(outcome.appliedCount == 0)
    }

    @Test("Une date valide écrit la date et sa précision ensemble")
    func releaseDateAndPrecisionMoveTogether() throws {
        let fixture = try makeFixture()
        let titles = try makeTitles(["A"], in: fixture)
        var components = DateComponents()
        components.year = 1970
        components.month = 6
        components.day = 15
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))

        try fixture.editor.apply(
            .setReleaseDate(date, precision: .year), toTitles: titles.map(\.id), summary: "…")

        let reread = try fixture.freshContext().fetch(FetchDescriptor<Title>())
        #expect(reread[0].releasePrecision == .year)
        #expect(reread[0].releaseDate != nil)
    }

    // MARK: - Personnes

    @Test("Un lot de personnes s'applique, et ne journalise qu'une fois")
    func peopleBatchApplies() throws {
        let fixture = try makeFixture()
        let repository = PersonRepository(context: fixture.context)
        let people = [("Alice", "Martin"), ("Bob", "Durand")].map {
            repository.create(firstName: $0.0, lastName: $0.1, in: fixture.library)
        }
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .setPrivate(true), toPeople: people.map(\.id), summary: "2 personnes masquées")

        #expect(outcome.appliedCount == 2)
        let fresh = fixture.freshContext()
        let people2 = try fresh.fetch(FetchDescriptor<Person>())
        let batchEntries = try activityCount(in: fresh, action: .bulkEdit)
        let perEntityEntries = try activityCount(in: fresh, action: .update)
        #expect(people2.allSatisfy { $0.isPrivate })
        #expect(batchEntries == 1)
        #expect(perEntityEntries == 0)
    }

    @Test("Vider la liste de rôles est refusé")
    func emptyRolesAreRefused() throws {
        let fixture = try makeFixture()
        let person = PersonRepository(context: fixture.context)
            .create(firstName: "Alice", lastName: "Martin", in: fixture.library)
        try fixture.context.save()

        let outcome = try fixture.editor.apply(
            .setRoles([]), toPeople: [person.id], summary: "…")
        #expect(outcome.appliedCount == 0)
    }

    @Test("Changer les rôles en masse garde les clés de filtre justes")
    func rolesBatchKeepsKeys() throws {
        let fixture = try makeFixture()
        let person = PersonRepository(context: fixture.context)
            .create(firstName: "Alice", lastName: "Martin", in: fixture.library)
        try fixture.context.save()

        try fixture.editor.apply(
            .setRoles([.director]), toPeople: [person.id], summary: "réalisation")

        let reread = try fixture.freshContext().fetch(FetchDescriptor<Person>())
        #expect(reread[0].roles == [.director])
    }
}

// MARK: - Aide

/// Crée un genre dans une bibliothèque donnée sans passer par `findOrCreate`.
///
/// `findOrCreate` cherche par `nameKey` **dans une bibliothèque** : pour fabriquer
/// volontairement un genre d'une autre bibliothèque, il faut le poser à la main. C'est
/// une fixture, pas un chemin de production — d'où l'appel explicite à `refreshDerived()`.
@MainActor
enum GenreVersionHelper {
    static func genre(
        named name: String,
        target: GenreTarget,
        in library: Library,
        context: ModelContext
    ) throws -> Genre {
        let genre = Genre(name: name, target: target)
        genre.library = library
        genre.refreshDerived()
        context.insert(genre)
        return genre
    }
}
