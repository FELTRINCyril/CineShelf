import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// MARK: - L18 · Ce que `V5a` ne pouvait pas tester
//
// `HomeSelection` vivait dans une vue depuis `V5a`, donc sans un seul test — alors que
// « stable dans la journée » est **exactement** ce qui se teste : une fonction du temps, dont
// on peut fournir le temps. Le `day` est un paramètre pour cette raison, et c'est la première
// chose que ce fichier exerce.

@MainActor
struct HomeSelectionTests {

    private func makeFixture() throws -> (context: ModelContext, library: Library) {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let library = Library()
        context.insert(library)
        return (context, library)
    }

    @discardableResult
    private func makeTitle(
        _ name: String,
        in context: ModelContext,
        library: Library,
        rating: Double? = nil,
        summary: String? = nil,
        backdrop: Bool = false,
        archived: Bool = false,
        isPrivate: Bool = false,
        deleted: Bool = false
    ) -> Title {
        let title = Title(name: name)
        title.library = library
        title.rating = rating
        title.summary = summary
        title.isArchived = archived
        title.isPrivate = isPrivate
        if deleted { title.deletedAt = .now }
        context.insert(title)

        if backdrop {
            let asset = MediaAsset()
            context.insert(asset)
            let attachment = MediaAttachment(slot: .backdrop)
            attachment.asset = asset
            attachment.title = title
            context.insert(attachment)
        }
        title.refreshDerived()
        return title
    }

    /// Un instant **quelconque** du jour `offset`, volontairement pas minuit.
    ///
    /// **C'est ce choix qui a trouvé le défaut.** `1_754_000_000` tombe à 22 h 13 UTC : avec
    /// l'index d'époque que j'avais écrit, « huit heures plus tard » changeait de jour et le
    /// hero changeait avec. Un instant rond aurait fait passer le test et laissé le bug.
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_754_000_000 + Double(offset) * 86_400)
    }

    // MARK: Stable dans la journée

    @Test("Le hero ne change pas dans la journée, et change le lendemain")
    func heroIsStableWithinTheDay() throws {
        // Source : fiche `V5a` — « le hero exige la règle de choix de `L18` : stable dans la
        // journée ». C'est la propriété que `V5a` affirmait sans pouvoir la vérifier.
        let (context, library) = try makeFixture()
        for index in 0..<9 {
            makeTitle("Titre \(index)", in: context, library: library, rating: Double(index % 5))
        }
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        func hero(at date: Date) -> UUID? {
            HomeSelection(titles: titles, day: date).heroID
        }

        // Trois instants du **même jour local**, pris depuis son minuit pour que l'assertion
        // porte sur ce qu'elle prétend. Le calcul de minuit est celui du calendrier courant,
        // comme dans le code : un test qui recalculerait autrement testerait autre chose.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let midnight = calendar.startOfDay(for: day(0))
        #expect(hero(at: midnight) == hero(at: midnight.addingTimeInterval(3_600 * 8)))
        #expect(hero(at: midnight) == hero(at: midnight.addingTimeInterval(86_399)))

        // Et il finit par changer. **Sur plusieurs jours et non sur le lendemain seul** : avec
        // sept candidats, deux jours consécutifs donnent forcément deux titres différents —
        // mais l'assertion « demain diffère » serait fausse le jour où le vivier tombe à un.
        let week = (0..<7).map { hero(at: day($0)) }
        #expect(Set(week.compactMap { $0 }).count > 1, "Le hero ne tourne jamais")
    }

    @Test("Un vivier d'un seul titre ne fait pas tourner le hero, et ne plante pas")
    func singleCandidateIsStable() throws {
        let (context, library) = try makeFixture()
        makeTitle("Unique", in: context, library: library)
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        let heroes = (0..<5).map { HomeSelection(titles: titles, day: day($0)).heroID }
        #expect(Set(heroes.compactMap { $0 }).count == 1)
    }

    @Test("Une date d'avant 1970 ne fait pas sortir l'index des bornes")
    func negativeEpochIsClamped() {
        // `%` de Swift garde le signe du dividende : sans la correction, l'indexation
        // planterait. Le cas n'est pas théorique — une horloge mal réglée suffit.
        for count in 1...5 {
            let index = HomeSelection.dayIndex(Date(timeIntervalSince1970: -1_000_000), modulo: count)
            #expect((0..<count).contains(index))
        }
        #expect(HomeSelection.dayIndex(Date(), modulo: 0) == 0)
    }

    // MARK: Les trois contraintes de visibilité

    @Test("Le hero n'est jamais archivé, supprimé, ni privé quand le profil les masque")
    func heroRespectsVisibility() throws {
        let (context, library) = try makeFixture()
        makeTitle("Archivé", in: context, library: library, archived: true)
        makeTitle("Supprimé", in: context, library: library, deleted: true)
        makeTitle("Privé", in: context, library: library, isPrivate: true)
        let visible = makeTitle("Visible", in: context, library: library)
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        let selection = HomeSelection(titles: titles, hidingPrivate: true, day: day(0))
        #expect(selection.heroID == visible.id)

        // Et sans masquage, le privé redevient éligible : c'est le **profil** qui décide de
        // l'affichage, jamais l'entité.
        let permissive = (0..<14).map {
            HomeSelection(titles: titles, hidingPrivate: false, day: day($0)).heroID
        }
        #expect(permissive.contains { $0 != visible.id })
    }

    @Test("Sans aucun titre visible, il n'y a pas de hero plutôt qu'un titre caché")
    func noVisibleTitleMeansNoHero() throws {
        let (context, library) = try makeFixture()
        makeTitle("Archivé", in: context, library: library, archived: true)
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        #expect(HomeSelection(titles: titles, day: day(0)).heroID == nil)
    }

    // MARK: Le choix éditorial

    @Test("Une image large passe devant un synopsis, qui passe devant une note")
    func editorialScoreIsOrdered() throws {
        let (context, library) = try makeFixture()
        let withBackdrop = makeTitle("Large", in: context, library: library, rating: 0, backdrop: true)
        let withSummary = makeTitle("Résumé", in: context, library: library, rating: 0, summary: "Un film.")
        let wellRated = makeTitle("Noté", in: context, library: library, rating: 10)
        try context.save()

        // Le hero est ce que l'écran affiche : une image large sur toute la hauteur. Un titre
        // qui en a une passe donc devant, même sans note — et un mieux noté ne le double pas.
        #expect(HomeSelection.editorialScore(withBackdrop) > HomeSelection.editorialScore(withSummary))
        #expect(HomeSelection.editorialScore(withSummary) > HomeSelection.editorialScore(wellRated))
    }

    @Test("La rotation reste dans les meilleurs candidats")
    func rotationStaysAmongTheBest() throws {
        let (context, library) = try makeFixture()
        // Sept titres avec image large, sept sans : sur deux semaines, aucun des seconds ne
        // doit apparaître — c'est toute la différence entre une sélection et une rotation.
        for index in 0..<7 {
            makeTitle("Large \(index)", in: context, library: library, backdrop: true)
        }
        for index in 0..<7 {
            makeTitle("Nu \(index)", in: context, library: library)
        }
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())
        let bare = Set(titles.filter { $0.name.hasPrefix("Nu") }.map(\.id))

        let fortnight = (0..<14).compactMap { HomeSelection(titles: titles, day: day($0)).heroID }
        #expect(fortnight.count == 14)
        #expect(fortnight.allSatisfy { !bare.contains($0) })
    }

    // MARK: Les rayons

    @Test("Un rayon de genre sous le seuil n'est pas rendu")
    func thinGenreRailIsDropped() throws {
        let (context, library) = try makeFixture()
        let drame = Genre(name: "Drame", target: .title)
        drame.library = library
        drame.isPinned = true
        context.insert(drame)

        // Deux titres : sous le seuil de trois.
        for index in 0..<2 {
            let title = makeTitle("Drame \(index)", in: context, library: library)
            title.genres = [drame]
            title.refreshDerived()
        }
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        var selection = HomeSelection(titles: titles, pinnedGenres: [drame], day: day(0))
        #expect(!selection.rails.contains { $0.id == "genre-\(drame.id)" })

        // Le troisième le fait apparaître.
        let third = makeTitle("Drame 2", in: context, library: library)
        third.genres = [drame]
        third.refreshDerived()
        try context.save()
        selection = HomeSelection(
            titles: try context.fetch(FetchDescriptor<Title>()), pinnedGenres: [drame], day: day(0))
        #expect(selection.rails.contains { $0.id == "genre-\(drame.id)" })
    }

    @Test("Les collections manuelles passent avant les rayons de genre")
    func collectionsComeFirst() throws {
        let (context, library) = try makeFixture()
        let collection = TitleCollection(name: "Cycle italien")
        collection.library = library
        context.insert(collection)
        let genre = Genre(name: "Drame", target: .title)
        genre.library = library
        context.insert(genre)

        for index in 0..<4 {
            let title = makeTitle("Titre \(index)", in: context, library: library)
            title.collection = collection
            title.genres = [genre]
            title.refreshDerived()
        }
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        let selection = HomeSelection(
            titles: titles, pinnedGenres: [genre], collections: [collection], day: day(0))
        let ids = selection.rails.map(\.id)
        let collectionIndex = try #require(ids.firstIndex(of: "collection-\(collection.id)"))
        let genreIndex = try #require(ids.firstIndex(of: "genre-\(genre.id)"))
        // Ce que l'utilisateur a rangé lui-même passe devant ce qu'on déduit pour lui.
        #expect(collectionIndex < genreIndex)
    }

    // MARK: « Prochain à voir »

    @Test("Le prochain à voir est le mieux noté de la watchlist, et ne tourne pas")
    func nextToWatchIsTheBestRated() throws {
        let (context, library) = try makeFixture()
        let profile = Profile(name: "Noé")
        context.insert(profile)

        let good = makeTitle("Bon", in: context, library: library, rating: 9)
        let poor = makeTitle("Moyen", in: context, library: library, rating: 4)
        makeTitle("Hors liste", in: context, library: library, rating: 10)

        for title in [good, poor] {
            let flag = TitleFlag()
            flag.profile = profile
            flag.title = title
            flag.isInWatchlist = true
            context.insert(flag)
        }
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        #expect(HomeSelection.nextToWatch(among: titles, profileID: profile.id)?.id == good.id)
        // **Aucune rotation** : c'est une recommandation qu'on suit, pas un hero. Elle ne
        // change pas parce qu'on a rouvert l'app le lendemain.
        #expect(HomeSelection.nextToWatch(among: titles, profileID: profile.id)?.id == good.id)
    }

    @Test("Sans profil, aucun flag ne compte — et surtout pas tous")
    func noProfileMeansNoFlags() throws {
        let (context, library) = try makeFixture()
        let profile = Profile(name: "Noé")
        context.insert(profile)
        let title = makeTitle("Bon", in: context, library: library, rating: 9)
        let flag = TitleFlag()
        flag.profile = profile
        flag.title = title
        flag.isInWatchlist = true
        context.insert(flag)
        try context.save()
        let titles = try context.fetch(FetchDescriptor<Title>())

        // Le piège serait de rendre toute la bibliothèque quand il n'y a pas de profil : un
        // flag est une donnée **par profil**, donc sans profil la bonne réponse est « rien ».
        #expect(HomeSelection.nextToWatch(among: titles, profileID: nil) == nil)
        #expect(HomeSelection.titles(titles, flaggedFor: nil) { $0.isInWatchlist }.isEmpty)
    }
}
