import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L20 · Défaire un lot
//
// **Ces tests viennent d'une sonde hors dépôt**, pas de mon imagination : un paquet SwiftPM
// jetable qui rejouait quinze scénarios en **imprimant** au lieu d'assener. C'est ce qui a
// trouvé la divergence de fenêtre — `isUndoable` répondait « non » au-delà de trente jours
// pendant qu'`undo` défaisait quand même. Un test écrit d'avance ne l'aurait pas cherchée :
// j'avais écrit les deux, donc je les croyais d'accord.
//
// Chaque défaut trouvé par la sonde est devenu un test ci-dessous. C'est le test qui reste.

@Suite("Annulation d'un lot")
@MainActor
struct BulkEditUndoTests {

    /// Des titres **quelconques** : des notes qui ne sont ni 0 ni 5, des durées qui ne sont pas
    /// des multiples de dix, et une précision de date à l'**année** — le cran qui se dégrade en
    /// silence si la date revient sans lui.
    /// **Un type nommé plutôt qu'un tuple à trois** : `large_tuple` a raison, `fixture.0` ne
    /// dit pas lequel des trois est le contexte.
    private struct Fixture {
        let context: ModelContext
        let library: Library
        let titles: [Title]
    }

    private func titles(_ count: Int) throws -> Fixture {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        let made = (0..<count).map { index -> Title in
            let title = repository.create(name: "Titre \(index)", in: library)
            title.rating = Double(3 + index % 5)
            title.runtimeMinutes = 90 + index * 7
            title.releaseDate = Calendar.current.date(
                from: DateComponents(year: 2_011 + index, month: 5, day: 17))
            title.releasePrecision = .year
            title.refreshDerived()
            return title
        }
        try context.save()
        return Fixture(context: context, library: library, titles: made)
    }

    private func applied(
        _ mutation: TitleBulkMutation, _ context: ModelContext, _ ids: [UUID]
    ) throws -> UUID {
        let outcome = try BulkEditor(isolatedContext: context)
            .apply(mutation, toTitles: ids, summary: "Lot de sonde")
        guard case .applied(_, let activityID) = outcome else {
            Issue.record("Le lot a été refusé : \(outcome)")
            return UUID()
        }
        return activityID
    }

    // MARK: L'aller-retour

    @Test("Un lot de notes se défait exactement")
    func ratingsComeBack() throws {
        let fixture = try titles(5)
        let context = fixture.context
        let made = fixture.titles
        let before = made.map(\.rating)

        let activityID = try applied(.setRating(1), context, made.map(\.id))
        #expect(made.allSatisfy { $0.rating == 1 })

        let outcome = try BulkEditUndoer(context: context).undo(activityID: activityID)
        #expect(outcome == .undone(count: 5))
        #expect(made.map(\.rating) == before)
    }

    /// **Le rappel explicite de la fiche, et le bug du prompt 11.**
    ///
    /// Une date remise sans sa précision se relit comme une date au jour près : le titre
    /// afficherait « 17 mai 2011 » là où l'utilisateur n'avait saisi que « 2011 ». `L10`
    /// journalise les deux champs, et l'annulation doit les restaurer **dans la même écriture**.
    @Test("La date et sa précision reviennent ensemble")
    func dateAndPrecisionComeBackTogether() throws {
        let fixture = try titles(3)
        let context = fixture.context
        let made = fixture.titles
        let beforeDates = made.map(\.releaseDate)
        let beforePrecision = made.map(\.releasePrecisionRaw)
        #expect(beforePrecision.allSatisfy { $0 == DatePrecision.year.rawValue })

        // Une date quelconque : le 6 août, ni un 1er ni un 31.
        let exact = try #require(
            Calendar.current.date(from: DateComponents(year: 2_024, month: 8, day: 6)))
        let activityID = try applied(.setReleaseDate(exact, precision: .day), context, made.map(\.id))
        #expect(made.allSatisfy { $0.releasePrecision == .day })

        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 3))
        #expect(made.map(\.releaseDate) == beforeDates)
        #expect(made.map(\.releasePrecisionRaw) == beforePrecision)
    }

    @Test("Un lot sur des personnes se défait aussi")
    func peopleComeBack() throws {
        let (context, library) = try makeTestLibrary()
        let repository = PersonRepository(context: context)
        let made = (0..<3).map { index -> Person in
            let person = repository.create(
                firstName: "Prénom\(index)", lastName: "Nom\(index)", roles: [.actor], in: library)
            person.bio = "Une biographie d'origine, assez longue pour être distincte."
            person.refreshDerived()
            return person
        }
        try context.save()
        let before = made.map { $0.roleValues.sorted() }

        let outcome = try BulkEditor(isolatedContext: context)
            .apply(.setRoles([.director, .writer]), toPeople: made.map(\.id), summary: "Rôles")
        guard case .applied(_, let activityID) = outcome else {
            Issue.record("Le lot a été refusé")
            return
        }
        #expect(made.allSatisfy { $0.roles == [.director, .writer] })

        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 3))
        #expect(made.map { $0.roleValues.sorted() } == before)
    }

    // MARK: Les relations

    @Test("Un remplacement de genres se défait dans les deux sens")
    func replacedGenresComeBack() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let made = fixture.titles
        let library = fixture.library
        let genres = GenreRepository(context: context)
        let drame = try genres.findOrCreate(name: "Drame", in: library)
        let polar = try genres.findOrCreate(name: "Polar", in: library)
        let western = try genres.findOrCreate(name: "Western", in: library)
        try context.save()

        // **Deux genres avant, un seul après** : le diff porte donc des `attached` *et* des
        // `detached`. Un cas à un seul genre n'exercerait qu'une moitié de l'inversion.
        _ = try applied(.setGenres([drame.id, polar.id]), context, made.map(\.id))
        let activityID = try applied(.setGenres([western.id]), context, made.map(\.id))
        #expect(made.allSatisfy { ($0.genres ?? []).map(\.id) == [western.id] })

        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 2))
        for title in made {
            #expect(Set((title.genres ?? []).map(\.id)) == [drame.id, polar.id])
        }
    }

    @Test("Un vidage de genres se défait")
    func clearedGenresComeBack() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let made = fixture.titles
        let library = fixture.library
        let drame = try GenreRepository(context: context).findOrCreate(name: "Drame", in: library)
        try context.save()

        _ = try applied(.setGenres([drame.id]), context, made.map(\.id))
        let activityID = try applied(.clearGenres, context, made.map(\.id))
        #expect(made.allSatisfy { ($0.genres ?? []).isEmpty })

        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 2))
        #expect(made.allSatisfy { ($0.genres ?? []).map(\.id) == [drame.id] })
    }

    /// **L'annulation défait ce que le lot a fait, et rien d'autre.**
    ///
    /// Un genre ajouté *après* le lot par quelqu'un d'autre doit survivre : refuser ici serait
    /// excessif — le lot n'a jamais touché ce genre-là — et l'effacer serait la destruction que
    /// « refuser plutôt qu'écraser » existe pour empêcher.
    @Test("Un genre ajouté après le lot survit à l'annulation")
    func laterGenreSurvives() throws {
        let fixture = try titles(3)
        let context = fixture.context
        let made = fixture.titles
        let library = fixture.library
        let genres = GenreRepository(context: context)
        let drame = try genres.findOrCreate(name: "Drame", in: library)
        let polar = try genres.findOrCreate(name: "Polar", in: library)
        try context.save()

        let activityID = try applied(.addGenres([drame.id]), context, made.map(\.id))
        // Sur celui du **milieu**, pas le premier : sur une borne, plusieurs implémentations
        // d'inversion coïncideraient.
        TitleRepository(context: context).setGenres(
            (made[1].genres ?? []) + [polar], on: made[1], journal: .batched)
        try context.save()

        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 3))
        #expect((made[0].genres ?? []).isEmpty)
        #expect((made[1].genres ?? []).map(\.id) == [polar.id])
        #expect((made[2].genres ?? []).isEmpty)
    }

    // MARK: Les refus — « refuser plutôt qu'écraser »

    @Test("Une entité modifiée depuis le lot fait refuser tout le lot")
    func changedEntityRefusesTheWholeBatch() throws {
        let fixture = try titles(4)
        let context = fixture.context
        let made = fixture.titles
        let activityID = try applied(.setRating(2), context, made.map(\.id))

        // Celui du **milieu**, et une note qui n'est ni la valeur d'avant ni celle d'après.
        TitleRepository(context: context).update(made[2], journal: .batched) { $0.rating = 9 }
        try context.save()

        let outcome = try BulkEditUndoer(context: context).undo(activityID: activityID)
        guard case .refused(let refusals) = outcome else {
            Issue.record("Attendu un refus, obtenu \(outcome)")
            return
        }
        #expect(refusals.count == 1)
        #expect(refusals.first?.entityID == made[2].id)
        #expect(
            refusals.first?.reason
                == .fieldChangedSince(field: "rating", expected: "2", found: "9"))
        // **Tout ou rien** : les trois autres n'ont pas bougé non plus.
        #expect(made.allSatisfy { $0.rating == 9 || $0.rating == 2 })
        #expect(made.filter { $0.rating == 2 }.count == 3)
    }

    @Test("Une entité à la corbeille ou disparue fait refuser")
    func trashedOrMissingRefuses() throws {
        let fixture = try titles(3)
        let context = fixture.context
        let made = fixture.titles
        let activityID = try applied(.setRating(2), context, made.map(\.id))

        TitleRepository(context: context).softDelete(made[0])
        context.delete(made[1])
        try context.save()

        let outcome = try BulkEditUndoer(context: context).undo(activityID: activityID)
        guard case .refused(let refusals) = outcome else {
            Issue.record("Attendu un refus, obtenu \(outcome)")
            return
        }
        let reasons = Set(refusals.map(\.reason))
        #expect(reasons.contains(.entityInTrash))
        #expect(reasons.contains(.entityNotFound))
    }

    @Test("Un lot ne se défait pas deux fois")
    func undoIsNotRepeatable() throws {
        let fixture = try titles(3)
        let context = fixture.context
        let made = fixture.titles
        let before = made.map(\.rating)
        let activityID = try applied(.setRating(2), context, made.map(\.id))
        let undoer = BulkEditUndoer(context: context)

        #expect(try undoer.undo(activityID: activityID) == .undone(count: 3))
        let second = try undoer.undo(activityID: activityID)
        #expect(second == .refused([.init(entityID: activityID, reason: .alreadyUndone)]))
        // Le second passage n'a rien réécrit : les valeurs sont toujours celles d'avant.
        #expect(made.map(\.rating) == before)
    }

    /// **Le défaut que la sonde a trouvé, et il n'aurait pas été cherché autrement.**
    ///
    /// `isUndoable` et `undo` répondaient différemment sur un lot hors fenêtre : l'un « non »,
    /// l'autre le défaisait. La fenêtre ne peut pas dépendre du seul passage de la purge de
    /// `L16` — qui peut ne pas avoir tourné depuis des mois sur un appareil rarement ouvert.
    @Test("Un lot hors fenêtre est refusé, et les deux réponses s'accordent")
    func expiredBatchIsRefused() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let made = fixture.titles
        let activityID = try applied(.setRating(2), context, made.map(\.id))
        let undoer = BulkEditUndoer(context: context)

        // 45 jours : franchement au-delà des 30, et pas exactement sur la borne — sur la borne,
        // « ≤ » et « < » donnent la même réponse.
        let late = Date().addingTimeInterval(45 * 24 * 60 * 60)
        let entry = try #require(
            try context.fetch(FetchDescriptor<ActivityEntry>()).first { $0.id == activityID })

        #expect(undoer.isUndoable(entry, now: late) == false)
        #expect(
            try undoer.undo(activityID: activityID, now: late)
                == .refused([.init(entityID: activityID, reason: .expired)]))
        #expect(made.allSatisfy { $0.rating == 2 }, "rien ne doit avoir été défait")
    }

    @Test("Une entrée inconnue, sans diff, ou d'une version inconnue est refusée")
    func malformedEntriesAreRefused() throws {
        let context = try titles(1).context
        let undoer = BulkEditUndoer(context: context)

        let unknown = UUID()
        #expect(
            try undoer.undo(activityID: unknown)
                == .refused([.init(entityID: unknown, reason: .entryNotFound)]))

        let plain = ActivityEntry.make(
            action: .update, entityType: .title, entityID: UUID(), summary: "Ordinaire")
        context.insert(plain)
        try context.save()
        #expect(
            try undoer.undo(activityID: plain.id)
                == .refused([.init(entityID: plain.id, reason: .notUndoable)]))

        // **Une version future, pas la version 0** : zéro est la valeur qu'un décodage raté
        // produirait, donc elle ne départage pas « format inconnu » de « champ absent ».
        let future = ActivityEntry.make(
            action: .bulkEdit, entityType: .title, entityID: UUID(), summary: "Futur")
        future.payload = try BulkEditDiff(
            version: 7, summary: "s", field: "rating", operation: .replace, entries: []
        ).encoded()
        context.insert(future)
        try context.save()
        #expect(
            try undoer.undo(activityID: future.id)
                == .refused([.init(entityID: future.id, reason: .unsupportedVersion(7))]))
    }

    // MARK: Le journal

    @Test("L'annulation est journalisée, et n'est pas elle-même annulable")
    func undoIsJournalled() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let made = fixture.titles
        let activityID = try applied(.setRating(2), context, made.map(\.id))
        _ = try BulkEditUndoer(context: context).undo(activityID: activityID)

        let items = try ActivityFeed.items(in: context)
        let undo = try #require(items.first { $0.action == .undo })
        #expect(undo.summary.hasPrefix("Annulé"))
        // **Sans diff** : refaire une annulation serait réappliquer le lot, ce qui est un
        // nouveau lot. Un `payload` ici rendrait `isUndoable` vrai sur une entrée qu'aucun code
        // ne sait défaire.
        #expect(undo.isUndoable == false)

        // Le lot d'origine reste dans le fil, marqué non annulable.
        let batch = try #require(items.first { $0.action == .bulkEdit })
        #expect(batch.isUndoable == false)
    }

    // MARK: La purge

    @Test("La purge efface les diffs expirés, garde la trace, et se rejoue")
    func purgeIsRepeatable() throws {
        let fixture = try titles(2)
        let context = fixture.context
        let made = fixture.titles
        let activityID = try applied(.setRating(2), context, made.map(\.id))
        let undoer = BulkEditUndoer(context: context)
        let journalCount = try context.fetch(FetchDescriptor<ActivityEntry>()).count

        // Dans la fenêtre : rien à purger.
        #expect(try undoer.purgeExpiredPayloads() == 0)

        let late = Date().addingTimeInterval(45 * 24 * 60 * 60)
        #expect(try undoer.purgeExpiredPayloads(now: late) == 1)
        // **Rejouable** — la fiche l'exige explicitement.
        #expect(try undoer.purgeExpiredPayloads(now: late) == 0)

        // La piste d'audit survit : « qui a modifié ces titres » reste une question valide
        // longtemps après que l'annulation soit devenue impossible.
        #expect(try context.fetch(FetchDescriptor<ActivityEntry>()).count == journalCount)
        #expect(
            try undoer.undo(activityID: activityID, now: late)
                == .refused([.init(entityID: activityID, reason: .expired)]))
    }

    @Test("Un lot sans effet se défait sans rien écrire")
    func noOpBatchUndoesToNothing() throws {
        let fixture = try titles(3)
        let context = fixture.context
        let made = fixture.titles
        // La note est déjà celle que le lot va poser : le diff porte des entrées, mais toutes
        // sans changement réel.
        TitleRepository(context: context).update(made[0], journal: .batched) { $0.rating = 4 }
        for title in made {
            TitleRepository(context: context).update(title, journal: .batched) { $0.rating = 4 }
        }
        try context.save()

        let activityID = try applied(.setRating(4), context, made.map(\.id))
        // **Zéro, pas trois** : compter les entités « touchées » sans changement ferait annoncer
        // un travail qui n'a pas eu lieu.
        #expect(try BulkEditUndoer(context: context).undo(activityID: activityID) == .undone(count: 0))
        #expect(made.allSatisfy { $0.rating == 4 })
    }
}
