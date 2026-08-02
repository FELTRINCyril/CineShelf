import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

@Suite("Journal d'activité")
@MainActor
struct ActivityRecorderTests {
    @Test("Une entrée porte l'action, le type, l'identifiant et le résumé")
    func entryCarriesEverything() throws {
        let (context, library) = try makeTestLibrary()
        let title = Title(name: "Andreï Roublev")
        title.library = library
        context.insert(title)

        let entry = ActivityRecorder(context: context).record(.update, title)
        try context.save()

        #expect(entry.action == .update)
        #expect(entry.actionRaw == "update")
        #expect(entry.entityTypeRaw == "Title")
        #expect(entry.entityID == title.id)
        #expect(entry.summary == "Andreï Roublev")
    }

    @Test("Le type d'entité vient du nom du modèle")
    func entityTypeComesFromTheModelName() throws {
        let (context, library) = try makeTestLibrary()
        let recorder = ActivityRecorder(context: context)
        let person = Person(firstName: "Chantal", lastName: "Akerman")
        person.library = library
        let collection = TitleCollection(name: "Cinéma belge")
        collection.library = library
        context.insert(person)
        context.insert(collection)

        #expect(recorder.record(.create, person).entityTypeRaw == "Person")
        #expect(recorder.record(.create, collection).entityTypeRaw == "TitleCollection")
        #expect(recorder.record(.create, library).entityTypeRaw == "Library")
    }

    @Test("Le résumé d'une personne est son nom d'affichage")
    func personSummaryIsDisplayName() throws {
        let (context, library) = try makeTestLibrary()
        let person = Person(firstName: "Wong", lastName: "Kar-wai")
        person.library = library
        context.insert(person)

        #expect(ActivityRecorder(context: context).record(.create, person).summary == "Wong Kar-wai")
    }

    @Test("Une fusion ou un import se journalise sans entité")
    func mergeAndImportNeedNoEntity() throws {
        let (context, _) = try makeTestLibrary()
        let recorder = ActivityRecorder(context: context)
        let batchID = UUID()

        recorder.record(.merge, entityType: "Person", entityID: batchID, summary: "2 personnes fusionnées")
        recorder.record(.import, entityType: "Bundle", entityID: batchID, summary: "412 titres importés")
        try context.save()

        #expect(try activityCount(in: context, action: .merge) == 1)
        #expect(try activityCount(in: context, action: .import) == 1)
    }

    @Test("Une action inconnue n'est pas devinée")
    func unknownActionStaysNil() throws {
        let (context, _) = try makeTestLibrary()
        let entry = ActivityEntry()
        entry.actionRaw = "archive"
        context.insert(entry)
        try context.save()

        #expect(entry.action == nil)
    }

    @Test("Les entrées se lisent du plus récent au plus ancien")
    func entriesSortByDateDescending() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        repository.create(name: "Premier", in: library)
        repository.create(name: "Second", in: library)
        try context.save()

        let descriptor = FetchDescriptor<ActivityEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let summaries = try context.fetch(descriptor).map(\.summary)

        #expect(summaries.count == 2)
        #expect(summaries.contains("Premier"))
        #expect(summaries.contains("Second"))
    }
}
