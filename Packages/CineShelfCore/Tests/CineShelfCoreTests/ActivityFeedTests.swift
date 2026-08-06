import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L18 · Le premier lecteur d'`ActivityEntry`
//
// **`ActivityRecorder` écrit depuis le prompt 6 et rien n'a jamais relu.** Ces tests sont donc
// aussi la première vérification que ce qui est écrit est lisible — et le premier passe par le
// **magasin**, comme la règle du projet l'exige pour tout ce qui touche à un prédicat.

@MainActor
struct ActivityFeedTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @discardableResult
    private func record(
        _ action: ActivityAction,
        _ type: ActivityEntityType,
        _ summary: String,
        at date: Date,
        in context: ModelContext
    ) -> ActivityEntry {
        let entry = ActivityEntry()
        entry.actionRaw = action.rawValue
        entry.entityTypeRaw = type.rawValue
        entry.summary = summary
        entry.createdAt = date
        context.insert(entry)
        return entry
    }

    private let reference = Date(timeIntervalSince1970: 1_754_000_000)

    // MARK: Décroissante et fenêtrée

    @Test("Le fil se lit du plus récent, et ne charge que sa fenêtre")
    func feedIsDescendingAndWindowed() throws {
        let context = try makeContext()
        for index in 0..<250 {
            record(
                .create, .title, "Titre \(index)",
                at: reference.addingTimeInterval(Double(index) * 60), in: context)
        }
        try context.save()

        let page = try ActivityFeed.items(limit: 100, in: context)
        #expect(page.count == 100, "La fenêtre n'est pas posée sur le fetch")
        #expect(page.first?.summary == "Titre 249", "Le fil ne commence pas par le plus récent")
        // Décroissante de bout en bout, pas seulement en tête.
        #expect(zip(page, page.dropFirst()).allSatisfy { $0.date >= $1.date })
    }

    @Test("La pagination par date ne saute aucune entrée quand le fil s'écrit pendant la lecture")
    func cursorPaginationSurvivesConcurrentWrites() throws {
        // **C'est la raison du curseur de date plutôt que d'un `offset`.** Un décalage se
        // décale dès qu'une entrée s'écrit entre deux pages, et le fil saute alors une ligne.
        // Sur un journal qui s'écrit en continu, ce n'est pas un cas rare : c'est le cas.
        let context = try makeContext()
        for index in 0..<10 {
            record(
                .create, .title, "Ancien \(index)",
                at: reference.addingTimeInterval(Double(index) * 60), in: context)
        }
        try context.save()

        let first = try ActivityFeed.items(limit: 5, in: context)
        #expect(first.map(\.summary) == (5..<10).reversed().map { "Ancien \($0)" })

        // Une écriture s'intercale, plus récente que tout : avec un offset, la page suivante
        // commencerait un cran trop loin.
        record(.create, .title, "Neuf", at: reference.addingTimeInterval(10_000), in: context)
        try context.save()

        let cursor = try #require(first.last?.date)
        let second = try ActivityFeed.items(limit: 5, before: cursor, in: context)
        #expect(second.map(\.summary) == (0..<5).reversed().map { "Ancien \($0)" })
    }

    // MARK: Groupée par jour

    @Test("Les entrées se groupent par jour, du plus récent au plus ancien")
    func daysAreGroupedAndOrdered() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let midnight = calendar.startOfDay(for: reference)

        // Deux entrées aujourd'hui, une hier, une avant-hier.
        record(.create, .title, "Matin", at: midnight.addingTimeInterval(3_600), in: context)
        record(.update, .title, "Soir", at: midnight.addingTimeInterval(3_600 * 20), in: context)
        record(.create, .person, "Hier", at: midnight.addingTimeInterval(-3_600), in: context)
        record(.delete, .title, "Avant-hier", at: midnight.addingTimeInterval(-86_400 * 2), in: context)
        try context.save()

        let days = try ActivityFeed.days(in: context)
        #expect(days.count == 3)
        #expect(days[0].entries.count == 2)
        #expect(days[0].entries.map(\.summary) == ["Soir", "Matin"])
        #expect(days.map(\.id) == days.map(\.id).sorted(by: >))
    }

    // MARK: Les filtres

    @Test("Un filtre vide vaut « tous », et un filtre actif ne garde que le sien")
    func filterEmptyMeansEverything() throws {
        let context = try makeContext()
        record(.create, .title, "Titre", at: reference, in: context)
        record(.delete, .person, "Personne", at: reference.addingTimeInterval(-60), in: context)
        record(.import, .batch, "Import", at: reference.addingTimeInterval(-120), in: context)
        try context.save()

        // Même règle que `TitleFilter` et `GalleryFilter` : vide est un filtre inactif, pas un
        // filtre qui ne rend rien.
        #expect(try ActivityFeed.items(in: context).count == 3)
        #expect(!ActivityFilter().isActive)

        let onlyDeletes = ActivityFilter(actions: [.delete])
        #expect(try ActivityFeed.items(matching: onlyDeletes, in: context).map(\.summary) == ["Personne"])

        let onlyTitles = ActivityFilter(entityTypes: [.title])
        #expect(try ActivityFeed.items(matching: onlyTitles, in: context).map(\.summary) == ["Titre"])

        // Les deux ensemble se combinent en « et », pas en « ou ».
        let both = ActivityFilter(actions: [.delete], entityTypes: [.title])
        #expect(try ActivityFeed.items(matching: both, in: context).isEmpty)
    }

    // MARK: Ce qui a disparu reste lisible

    @Test("Une entrée dont la cible n'existe plus reste lisible")
    func orphanedEntryStaysReadable() throws {
        // **C'est la contrainte qui commande la forme du type.** `summary` est figé à
        // l'écriture ; résoudre l'entité à la lecture rendrait illisible tout ce qui concerne
        // un titre supprimé — c'est-à-dire précisément ce qu'on vient consulter après une
        // suppression.
        let context = try makeContext()
        let title = Title(name: "Le Conformiste")
        context.insert(title)
        try context.save()

        let entry = record(.delete, .title, title.name, at: reference, in: context)
        entry.entityID = title.id
        try context.save()

        context.delete(title)
        try context.save()

        let items = try ActivityFeed.items(in: context)
        #expect(items.count == 1)
        #expect(items[0].summary == "Le Conformiste")
        #expect(items[0].entityID == title.id)
        #expect(items[0].actionLabel == "Mis à la corbeille")
    }

    @Test("Une action inconnue dit « opération » plutôt qu'un repli plausible")
    func unknownActionIsHonest() throws {
        let context = try makeContext()
        let entry = ActivityEntry()
        // Ce que produirait une version future, relue par celle-ci.
        entry.actionRaw = "quarantine"
        entry.entityTypeRaw = "hologram"
        entry.summary = "Quelque chose"
        entry.createdAt = reference
        context.insert(entry)
        try context.save()

        let item = try #require(try ActivityFeed.items(in: context).first)
        #expect(item.action == nil)
        #expect(item.actionLabel == "Opération")
        #expect(item.entityLabel == "Entrée")
        // Et un filtre actif ne la retient pas : on ne devine pas ce qu'elle serait.
        #expect(try ActivityFeed.items(matching: ActivityFilter(actions: [.create]), in: context).isEmpty)
    }

    @Test("Un fil vide rend zéro jour, pas un jour vide")
    func emptyFeedHasNoDays() throws {
        let context = try makeContext()
        #expect(try ActivityFeed.days(in: context).isEmpty)
        #expect(ActivityFeed.group([]).isEmpty)
    }
}
