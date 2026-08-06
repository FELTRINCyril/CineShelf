import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les quatre agrégations de `L18`.
//
// Ce qu'elles assènent tient en une phrase : **un chiffre incomplet doit s'annoncer
// incomplet**. Les trois décisions qui en découlent — les sans-date omis, les sans-note omis,
// les séries hors du total de durée — sont testées avec leur contrepartie visible, sans quoi
// « omis » et « oublié » se ressembleraient.

@MainActor
struct LibraryStatisticsTests {

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

    private func makeTitle(
        _ name: String,
        in context: ModelContext,
        library: Library,
        year: Int? = nil,
        rating: Double? = nil,
        runtime: Int? = nil,
        kind: TitleKind = .movie
    ) -> Title {
        let title = Title(name: name, kind: kind)
        title.library = library
        title.rating = rating
        title.runtimeMinutes = runtime
        if let year {
            var components = DateComponents()
            components.year = year
            components.month = 6
            components.day = 15
            title.releaseDate = Calendar(identifier: .gregorian).date(from: components)
        }
        context.insert(title)
        title.refreshDerived()
        return title
    }

    @Test("La répartition par genre compte chaque genre d'un titre")
    func genresCountEveryAssociation() throws {
        let (context, library) = try makeFixture()
        let drame = Genre(name: "Drame", target: .title)
        let policier = Genre(name: "Policier", target: .title)
        for genre in [drame, policier] {
            genre.library = library
            context.insert(genre)
        }

        let both = makeTitle("Deux genres", in: context, library: library)
        both.genres = [drame, policier]
        let one = makeTitle("Un genre", in: context, library: library)
        one.genres = [drame]
        for title in [both, one] { title.refreshDerived() }
        try context.save()

        let slices = LibraryStatistics.byGenre([both, one])
        #expect(slices.map(\.label) == ["Drame", "Policier"])
        #expect(slices.map(\.count) == [2, 1])
        // La somme dépasse le nombre de titres, et c'est correct pour la question posée.
        #expect(slices.reduce(0) { $0 + $1.count } == 3)
    }

    @Test("Les décennies sont chronologiques, et les titres sans date sont omis")
    func decadesAreChronologicalAndSkipUndated() throws {
        let (context, library) = try makeFixture()
        let titles = [
            makeTitle("Ancien", in: context, library: library, year: 1974),
            makeTitle("Récent", in: context, library: library, year: 2021),
            makeTitle("Autre récent", in: context, library: library, year: 2023),
            makeTitle("Sans date", in: context, library: library)
        ]
        try context.save()

        let slices = LibraryStatistics.byDecade(titles)
        // Chronologique et non par volume : on lit une frise, pas un classement.
        #expect(slices.map(\.label) == ["1970s", "2020s"])
        #expect(slices.map(\.count) == [1, 2])
        // « 0 » se lirait comme une décennie réelle sur un axe : le sans-date est omis.
        #expect(!slices.contains { $0.id == "0" })
        #expect(slices.reduce(0) { $0 + $1.count } == 3)
    }

    @Test("Les notes se rangent en cinq crans, et les sans-note sont omis")
    func ratingsAreFiveStars() throws {
        let (context, library) = try makeFixture()
        let titles = [
            makeTitle("Excellent", in: context, library: library, rating: 10),
            makeTitle("Bon", in: context, library: library, rating: 7),
            makeTitle("Faible", in: context, library: library, rating: 1),
            makeTitle("Pas noté", in: context, library: library)
        ]
        try context.save()

        let slices = LibraryStatistics.byRating(titles)
        #expect(slices.map(\.label) == ["1 ★", "4 ★", "5 ★"])
        // « Pas noté » n'est pas une note basse : le compter en 0 ferait mentir la série.
        #expect(slices.reduce(0) { $0 + $1.count } == 3)
    }

    @Test("La durée totale exclut les séries, et le dit")
    func runtimeExcludesSeriesAndSaysSo() throws {
        let (context, library) = try makeFixture()
        let titles = [
            makeTitle("Film long", in: context, library: library, runtime: 180),
            makeTitle("Film court", in: context, library: library, runtime: 90),
            makeTitle("Film sans durée", in: context, library: library),
            makeTitle("Série", in: context, library: library, runtime: 45, kind: .series)
        ]
        try context.save()

        // Une série porte `episodeCount` mais aucune durée d'épisode : l'estimer produirait un
        // chiffre plausible et faux.
        #expect(LibraryStatistics.totalRuntime(titles) == 270)

        // Et ce que le total ne couvre pas est comptable, pour que l'écran puisse le dire.
        let excluded = LibraryStatistics.runtimeExclusions(titles)
        #expect(excluded.series == 1)
        #expect(excluded.withoutRuntime == 1)
    }

    @Test("Une bibliothèque vide rend des séries vides, jamais des zéros inventés")
    func emptyLibraryYieldsEmptySeries() {
        #expect(LibraryStatistics.byGenre([]).isEmpty)
        #expect(LibraryStatistics.byDecade([]).isEmpty)
        #expect(LibraryStatistics.byRating([]).isEmpty)
        #expect(LibraryStatistics.totalRuntime([]) == 0)
    }
}
