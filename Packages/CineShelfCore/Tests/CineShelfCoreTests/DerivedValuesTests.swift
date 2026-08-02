import Foundation
import Testing

@testable import CineShelfCore

@Suite("Valeurs dérivées")
struct DerivedValuesTests {
    @Test("Le sortName d'un titre est replié : sans accents ni casse")
    func titleSortNameIsFolded() {
        let title = Title(name: "  Amélie Poulain ")
        #expect(title.sortName == "amelie poulain")
    }

    @Test("Le searchText d'un titre reprend le titre original et le synopsis, repliés")
    func titleSearchTextGathersEveryField() {
        let title = Title(name: "Été")
        title.originalName = "Summer"
        title.summary = "Un Récit d'ÉTÉ"
        title.refreshDerived()

        #expect(title.searchText == "ete summer un recit d'ete")
    }

    @Test("Un champ nul est ignoré par le searchText")
    func titleSearchTextSkipsNilFields() {
        let title = Title(name: "Dune")
        #expect(title.searchText == "dune")
    }

    @Test("refreshDerived met à jour updatedAt")
    func refreshDerivedTouchesUpdatedAt() {
        let title = Title(name: "Alien")
        let before = title.updatedAt
        title.name = "Aliens"
        title.refreshDerived()

        #expect(title.updatedAt > before)
    }

    @Test("Le sortName d'une personne est « nom prénom », replié")
    func personSortNameStartsWithLastName() {
        let person = Person(firstName: "Agnès", lastName: "Varda")

        #expect(person.displayName == "Agnès Varda")
        #expect(person.sortName == "varda agnes")
        #expect(person.searchText == "agnes varda")
    }

    @Test("Une personne sans nom de famille n'a ni espace de tête ni espace de queue")
    func personNamesAreTrimmed() {
        let person = Person(firstName: "Zendaya")

        #expect(person.displayName == "Zendaya")
        #expect(person.sortName == "zendaya")
    }

    @Test("Une personne est actrice par défaut")
    func personDefaultsToActorRole() {
        let person = Person(firstName: "Toshiro", lastName: "Mifune")

        #expect(person.isActor)
        #expect(person.isSocial == false)
        #expect(person.roles == [.actor])
    }

    @Test("Les rôles sont persistés triés, en rawValue")
    func personRolesRoundTrip() {
        let person = Person(firstName: "Greta", lastName: "Gerwig")
        person.roles = [.director, .actor, .writer]

        #expect(person.roleValues == ["actor", "director", "writer"])
        #expect(person.roles == [.actor, .director, .writer])
    }

    @Test("L'âge se calcule à la date de décès quand elle existe")
    func personAgeStopsAtDeathDate() {
        let calendar = Calendar.current
        let person = Person(firstName: "Jeanne", lastName: "Moreau")
        person.birthDate = calendar.date(from: DateComponents(year: 1928, month: 1, day: 23))
        person.deathDate = calendar.date(from: DateComponents(year: 2017, month: 7, day: 31))

        #expect(person.age == 89)
    }

    @Test("Le sortName et le searchText d'une collection sont repliés")
    func collectionDerivedValues() {
        let collection = TitleCollection(name: "Épopées")
        collection.summary = "Grands Récits"
        collection.refreshDerived()

        #expect(collection.sortName == "epopees")
        #expect(collection.searchText == "epopees grands recits")
    }

    @Test("Le searchText d'un signet reprend le nom, les notes et l'URL")
    func savedLinkDerivedValues() {
        let link = SavedLink(urlString: "https://Café.example")
        link.name = "Café"
        link.notes = "À LIRE"
        link.refreshDerived()

        #expect(link.searchText == "cafe a lire https://cafe.example")
    }

    @Test("La clé de dédoublonnage d'un genre ignore accents, casse et espaces")
    func genreKeyIsFolded() {
        #expect(Genre.key(for: " Épouvante ") == "epouvante")
        #expect(Genre.key(for: "EPOUVANTE") == Genre.key(for: "épouvante"))

        let genre = Genre(name: " Épouvante ")
        #expect(genre.nameKey == "epouvante")

        genre.name = "Horreur"
        genre.refreshDerived()
        #expect(genre.nameKey == "horreur")
    }

    @Test("Une énumération inconnue retombe sur la valeur par défaut")
    func unknownRawValueFallsBack() {
        let title = Title(name: "Test")
        title.kindRaw = "valeur-inconnue"
        #expect(title.kind == .movie)

        title.kind = .series
        #expect(title.kindRaw == "series")
    }

    @Test("L'année de sortie se déduit de la date")
    func releaseYearComesFromDate() {
        let title = Title(name: "Blade Runner")
        #expect(title.releaseYear == nil)

        title.releaseDate = Calendar.current.date(from: DateComponents(year: 1982, month: 6, day: 25))
        #expect(title.releaseYear == 1982)
        #expect(title.releasePrecision == .day)
    }
}
