import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// Les dérivés textuels persistés doivent être **reproductibles d'un appareil à l'autre**.
//
// `sortName`, `searchText` et `nameKey` sont synchronisés par CloudKit. S'ils sont calculés
// avec `locale: .current`, deux appareils sous des locales différentes écrivent des valeurs
// différentes pour la même entité — et rien ne le signale.
//
// **Le cas n'est pas exotique.** Le turc et l'azéri ont un `i` sans point, donc *tout* mot
// contenant un `I` majuscule diverge : « Interstellar » se replie en « ınterstellar », et
// « ITALIA » en « ıtalıa ». La moitié des titres écrits en capitales sont concernés.
//
// Les tests ci-dessous vérifient chaque site de repliage du dépôt. La forme est toujours la
// même : produire la valeur, et la comparer à ce que la locale turque aurait donné. Si les
// deux coïncident, c'est que le repliage n'est pas invariant.

/// Les mots sur lesquels le français et le turc divergent. Source : mesure du 2026-08-04,
/// `folding(options: [.diacriticInsensitive, .caseInsensitive], locale:)`.
private let divergingWords = ["Interstellar", "ITALIA", "Indépendant", "İstanbul"]

/// Ce que la locale turque aurait produit — la valeur à ne jamais obtenir.
private func turkishFolding(_ text: String) -> String {
    text.folding(
        options: [.diacriticInsensitive, .caseInsensitive],
        locale: Locale(identifier: "tr_TR")
    )
}

struct TextFoldingTests {

    @Test("La locale de repliage est invariante, et ce n'est pas celle de l'appareil")
    func localeIsInvariant() {
        #expect(TextFolding.locale.identifier == "en_US_POSIX")
        #expect(TextFolding.locale != Locale.current || Locale.current.identifier == "en_US_POSIX")
    }

    @Test("Le repliage ne dépend pas de la locale", arguments: divergingWords)
    func foldingIsLocaleIndependent(word: String) {
        // Contrôle positif : la valeur attendue est celle des locales latines.
        #expect(
            word.foldedForMatching
                == word.folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: Locale(identifier: "fr_FR")))

        // Contrôle négatif, et c'est lui qui prouve quelque chose : si le repliage suivait
        // la locale de l'appareil, un appareil turc obtiendrait cette autre valeur.
        #expect(
            word.foldedForMatching != turkishFolding(word),
            "Ces mots sont choisis parce que le turc les replie autrement"
        )
    }

    @Test("Les accents et la casse partent quand même")
    func diacriticsAndCaseAreStillRemoved() {
        #expect("Éléphant".foldedForMatching == "elephant")
        #expect("ÇA".foldedForMatching == "ca")
        #expect("Où".foldedForMatching == "ou")
    }

    @Test("Le repliage est idempotent")
    func foldingIsIdempotent() {
        // Une valeur déjà repliée doit rester identique : sinon un `refreshDerived()`
        // appelé deux fois produirait deux valeurs.
        for word in divergingWords {
            let once = word.foldedForMatching
            #expect(once.foldedForMatching == once, "\(word)")
        }
    }
}

// MARK: - Un test par site persisté

@MainActor
struct PersistedFoldingTests {

    @Test("Genre.nameKey est invariant — le site qui mord vraiment")
    func genreNameKeyIsInvariant() throws {
        // `nameKey` sert au dédoublonnage : c'est notre remplacement de
        // `@Attribute(.unique)`, que CloudKit interdit. Deux appareils qui ne s'accordent
        // pas sur la clé créent un doublon **sans rien signaler**.
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let genre = try repository.findOrCreate(name: "Indépendant", target: .title, in: library)
        try context.save()

        #expect(genre.nameKey == "independant")
        #expect(genre.nameKey != turkishFolding("Indépendant"))

        // Et le dédoublonnage doit tenir : la même saisie ne crée pas un second genre.
        let again = try repository.findOrCreate(name: "INDÉPENDANT", target: .title, in: library)
        try context.save()
        #expect(again.id == genre.id, "Le dédoublonnage doit reconnaître la même clé")
    }

    @Test("Title.sortName et Title.searchText sont invariants")
    func titleDerivedValuesAreInvariant() throws {
        let (context, library) = try makeTestLibrary()
        let title = TitleRepository(context: context).create(name: "Interstellar", in: library)
        try context.save()

        #expect(title.sortName == "interstellar")
        #expect(title.sortName != turkishFolding("Interstellar"))
        #expect(title.searchText.contains("interstellar"))
        #expect(title.searchText.contains(turkishFolding("Interstellar")) == false)
    }

    @Test("Person.sortName et Person.searchText sont invariants")
    func personDerivedValuesAreInvariant() throws {
        let (context, library) = try makeTestLibrary()
        let person = PersonRepository(context: context)
            .create(firstName: "Isabelle", lastName: "ITALIA", in: library)
        try context.save()

        #expect(person.sortName == "italia isabelle")
        #expect(person.sortName != turkishFolding("ITALIA Isabelle"))
        #expect(person.searchText.contains("isabelle"))
    }

    @Test("TitleCollection.sortName et searchText sont invariants")
    func collectionDerivedValuesAreInvariant() throws {
        let (context, library) = try makeTestLibrary()
        let collection = CollectionRepository(context: context)
            .create(name: "Intégrale", in: library)
        try context.save()

        #expect(collection.sortName == "integrale")
        #expect(collection.sortName != turkishFolding("Intégrale"))
        #expect(collection.searchText.contains("integrale"))
    }

    @Test("SavedLink.searchText est invariant")
    func savedLinkSearchTextIsInvariant() throws {
        let (context, library) = try makeTestLibrary()
        let link = SavedLink(urlString: "https://www.imdb.com")
        link.name = "IMDb"
        link.library = library
        link.refreshDerived()
        context.insert(link)
        try context.save()

        #expect(link.searchText.contains("imdb"))
        #expect(link.searchText.contains(turkishFolding("IMDb")) == false)
    }
}

// MARK: - Les deux côtés de la comparaison
//
// Le point le plus subtil de cet audit : une locale invariante à l'écriture ne suffit pas.
// Le terme cherché est replié **au moment de la requête**, et si les deux côtés n'utilisent
// pas la même règle, la comparaison est fausse — quelle que soit la locale choisie. Un
// `CONTAINS` qui ne matche pas ne lève aucune erreur.

@MainActor
struct FoldingBothSidesTests {

    @Test("Un titre à I majuscule se retrouve par la recherche")
    func titleWithCapitalIIsSearchable() throws {
        let (context, library) = try makeTestLibrary()
        let repository = TitleRepository(context: context)
        _ = repository.create(name: "Interstellar", in: library)
        _ = repository.create(name: "ITALIA", in: library)
        // `save()` avant le `fetch` : sur du pending, SwiftData évalue le prédicat en
        // Swift et la traduction SQL n'est pas exercée. Règle de `CLAUDE.md`.
        try context.save()

        // La recherche replie le terme ; l'écriture a replié le nom. Les deux doivent
        // employer la même règle, sinon rien ne matche.
        for term in ["interstellar", "INTERSTELLAR", "Interstellar"] {
            var filter = TitleFilter()
            filter.searchText = term
            let found = try context.fetch(
                FetchDescriptor<Title>(
                    predicate: filter.predicate(hidingPrivate: false, libraryID: nil)))
            #expect(found.count == 1, "terme « \(term) »")
        }
    }

    @Test("Un genre saisi en capitales retrouve celui en minuscules")
    func genreLookupIsCaseAndLocaleStable() throws {
        let (context, library) = try makeTestLibrary()
        let repository = GenreRepository(context: context)
        let first = try repository.findOrCreate(name: "Indépendant", target: .title, in: library)
        try context.save()

        // Le chemin SQL, depuis un contexte neuf : c'est celui que l'app emprunte.
        let fresh = ModelContext(try makeTestContainer())
        _ = fresh
        let again = try repository.findOrCreate(name: "indépendant", target: .title, in: library)
        try context.save()
        #expect(again.id == first.id)

        let all = try context.fetch(FetchDescriptor<Genre>())
        #expect(all.count == 1, "Un doublon signifierait que les deux côtés divergent")
    }
}
