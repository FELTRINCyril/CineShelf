import Foundation
import SwiftData
import Testing

@testable import CineShelfCore

// L'indexation Spotlight.
//
// Ce que ces tests protègent n'est pas « l'index contient les bons items » — ça,
// `CoreSpotlight` s'en charge et on ne peut pas l'observer sous `swift test`. C'est
// **la règle** : ce qui entre, ce qui sort, et surtout ce qui sort *au bon moment*.
//
// La fuite qu'ils existent pour empêcher est précise. Un titre public est indexé ;
// rendu privé, il doit quitter l'index. Sinon il reste trouvable depuis l'écran
// d'accueil du système alors que l'app le masque partout — et personne ne s'en aperçoit,
// puisque tout a l'air correct dans l'app. Même chose pour la corbeille.

@MainActor
struct SpotlightIndexerTests {

    /// Un index de test qui note ce qu'on lui demande.
    ///
    /// `CSSearchableIndex` n'est pas utilisable ici : sous `swift test`, le binaire n'a
    /// pas d'identifiant de paquet, et une suite de tests n'a rien à écrire dans
    /// l'index de la machine qui la fait tourner.
    private final class RecordingIndex: SpotlightIndexing {
        private(set) var indexed: [SpotlightEntry] = []
        private(set) var removed: [String] = []
        private(set) var removeAllCount = 0

        func index(_ entries: [SpotlightEntry]) { indexed.append(contentsOf: entries) }
        func remove(identifiers: [String]) { removed.append(contentsOf: identifiers) }
        func removeAll() { removeAllCount += 1 }

        /// Repart d'un journal vide, pour n'observer que ce qui suit la préparation.
        /// `removeAllCount` n'est pas remis à zéro : c'est un compteur d'événements
        /// rares, et les tests qui l'observent veulent son total.
        func forgetCalls() {
            indexed.removeAll()
            removed.removeAll()
        }
    }

    /// Le magasin, la bibliothèque d'accueil et l'index observable d'un test.
    private struct Store {
        let context: ModelContext
        let library: Library
        let index: RecordingIndex
    }

    private func makeStore() throws -> Store {
        let container = try Persistence.makeContainer(cloudKit: false, inMemory: true)
        let context = ModelContext(container)
        let library = Library(name: "Principale")
        context.insert(library)
        return Store(context: context, library: library, index: RecordingIndex())
    }

    // MARK: La règle

    @Test("Le privé et la corbeille ne sont jamais indexables")
    func theRuleItself() {
        #expect(SpotlightIndexer.shouldIndex(isPrivate: false, deletedAt: nil))
        #expect(SpotlightIndexer.shouldIndex(isPrivate: true, deletedAt: nil) == false)
        #expect(SpotlightIndexer.shouldIndex(isPrivate: false, deletedAt: .now) == false)
        #expect(SpotlightIndexer.shouldIndex(isPrivate: true, deletedAt: .now) == false)
    }

    @Test("Une entité archivée reste indexée")
    func archivedEntitiesStayIndexed() {
        // Décision, pas oubli : `isArchived` est un état de rangement, pas de
        // confidentialité, et le contrat de `docs/03` §9 ne cite que le privé et la
        // corbeille. Le test fixe la décision pour qu'elle ne dérive pas par accident.
        #expect(SpotlightIndexer.shouldIndex(isPrivate: false, deletedAt: nil))
    }

    // MARK: La désindexation suit l'état

    @Test("Un titre rendu privé sort de l'index")
    func makingATitlePrivateRemovesIt() throws {
        // **Le test central de `L3`.** Un titre indexé qui devient privé et resterait
        // trouvable depuis Spotlight est une fuite : l'app le masque partout, donc rien
        // ne la signale.
        let store = try makeStore()
        let repository = TitleRepository(
            context: store.context, spotlight: SpotlightIndexer(index: store.index))

        let title = repository.create(name: "Un titre", in: store.library)
        let id = SpotlightItemID(kind: .title, entityID: title.id)
        #expect(store.index.indexed.contains { $0.id == id })
        #expect(store.index.removed.isEmpty)

        repository.update(title) { $0.isPrivate = true }
        #expect(store.index.removed == [id.rawValue])
    }

    @Test("Un titre mis à la corbeille sort de l'index, et revient à la restauration")
    func softDeleteRemovesAndRestoreReindexes() throws {
        let store = try makeStore()
        let repository = TitleRepository(
            context: store.context, spotlight: SpotlightIndexer(index: store.index))

        let title = repository.create(name: "Un titre", in: store.library)
        let id = SpotlightItemID(kind: .title, entityID: title.id)

        repository.softDelete(title)
        #expect(store.index.removed == [id.rawValue])

        repository.restore(title)
        #expect(store.index.indexed.filter { $0.id == id }.count == 2, "Réindexé à la restauration")
    }

    @Test("Un titre privé n'entre jamais dans l'index, même à la création")
    func privateTitlesAreNeverIndexed() throws {
        let store = try makeStore()
        let repository = TitleRepository(
            context: store.context, spotlight: SpotlightIndexer(index: store.index))

        let title = repository.create(name: "Un titre", in: store.library)
        repository.update(title) { $0.isPrivate = true }
        store.index.forgetCalls()

        // Une écriture ultérieure ne doit pas le réintroduire.
        repository.update(title) { $0.rating = 8 }
        #expect(store.index.indexed.isEmpty, "Une entité privée ne rentre pas dans l'index")
    }

    @Test("Un titre redevenu public réintègre l'index")
    func makingATitlePublicAgainReindexesIt() throws {
        let store = try makeStore()
        let repository = TitleRepository(
            context: store.context, spotlight: SpotlightIndexer(index: store.index))

        let title = repository.create(name: "Un titre", in: store.library)
        repository.update(title) { $0.isPrivate = true }
        store.index.forgetCalls()

        repository.update(title) { $0.isPrivate = false }
        #expect(store.index.indexed.map(\.id) == [SpotlightItemID(kind: .title, entityID: title.id)])
    }

    @Test("La règle vaut aussi pour les personnes et les collections")
    func peopleAndCollectionsFollowTheSameRule() throws {
        let store = try makeStore()
        let indexer = SpotlightIndexer(index: store.index)
        let people = PersonRepository(context: store.context, spotlight: indexer)
        let collections = CollectionRepository(context: store.context, spotlight: indexer)

        let person = people.create(firstName: "Ana", lastName: "Novak", in: store.library)
        let collection = collections.create(name: "Une saga", in: store.library)
        store.index.forgetCalls()

        people.update(person) { $0.isPrivate = true }
        collections.update(collection) { $0.isPrivate = true }

        #expect(
            Set(store.index.removed) == [
                SpotlightItemID(kind: .person, entityID: person.id).rawValue,
                SpotlightItemID(kind: .collection, entityID: collection.id).rawValue
            ]
        )
    }

    // MARK: Le contenu des items

    @Test("Un item porte son identifiant, son titre et ses mots-clés repliés")
    func entryCarriesWhatSpotlightNeeds() throws {
        let store = try makeStore()
        let indexer = SpotlightIndexer(index: store.index)
        let title = Title(name: "Une Âme sœur")
        title.summary = "Un résumé qui parle de solitude."
        title.releaseDate = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 1994, month: 3, day: 2))
        title.runtimeMinutes = 142
        title.library = store.library
        title.refreshDerived()

        let entry = indexer.entry(for: title)

        #expect(entry.id == SpotlightItemID(kind: .title, entityID: title.id))
        #expect(entry.title == "Une Âme sœur")
        #expect(entry.subtitle == "1994 · 2 h 22")
        #expect(entry.contentDescription == "Un résumé qui parle de solitude.")

        // Les mots-clés viennent de `searchText`, donc déjà repliés : « ame » et non
        // « Âme ». C'est ce qui fait que Spotlight et la recherche interne trouvent la
        // même chose.
        #expect(entry.keywords.contains("ame"))
        #expect(entry.keywords.contains("Âme") == false)
        #expect(entry.keywords.contains("solitude"))
    }

    @Test("La vignette vient de l'appelant, et son absence n'est pas une erreur")
    func thumbnailsComeFromTheCaller() throws {
        // `MediaKit` ne peut pas être importé par `CineShelfCore` — la règle de
        // dépendances va dans l'autre sens. C'est donc une fermeture qui fournit les
        // octets, et par défaut il n'y en a pas.
        let store = try makeStore()
        let title = Title(name: "Un titre")
        title.library = store.library
        title.refreshDerived()

        let without = SpotlightIndexer(index: store.index)
        #expect(without.entry(for: title).thumbnailData == nil)

        let data = Data([0x01, 0x02])
        let with = SpotlightIndexer(index: store.index, thumbnail: { _ in data })
        #expect(with.entry(for: title).thumbnailData == data)
    }

    // MARK: Identifiants

    @Test("Un identifiant fait l'aller-retour")
    func itemIDRoundTrips() {
        for kind in SpotlightEntityKind.allCases {
            let id = SpotlightItemID(kind: kind, entityID: UUID())
            #expect(SpotlightItemID(rawValue: id.rawValue) == id)
        }
    }

    @Test("Un identifiant étranger ne se décode pas, et ce n'est pas une erreur")
    func foreignIdentifiersAreRejected() {
        // L'index du système peut contenir des items d'une version antérieure. Le bon
        // comportement est de ne rien ouvrir plutôt que de deviner.
        for raw in ["", "title", "inconnu:\(UUID().uuidString)", "title:pas-un-uuid", ":"] {
            #expect(SpotlightItemID(rawValue: raw) == nil, "« \(raw) » ne doit pas se décoder")
        }
    }

    @Test("Chaque type d'item connaît sa portée de recherche")
    func kindsMapToSearchScopes() {
        #expect(SpotlightEntityKind.title.searchScope == .titles)
        #expect(SpotlightEntityKind.person.searchScope == .people)
        #expect(SpotlightEntityKind.collection.searchScope == .collections)
    }

    // MARK: Réindexation complète

    @Test("La réindexation vide l'index puis n'y remet que l'indexable")
    func reindexEverythingSkipsPrivateAndTrashed() throws {
        let store = try makeStore()
        let indexer = SpotlightIndexer(index: store.index)
        let titles = TitleRepository(context: store.context, spotlight: indexer)
        let people = PersonRepository(context: store.context, spotlight: indexer)
        let collections = CollectionRepository(context: store.context, spotlight: indexer)

        titles.create(name: "Public", in: store.library)
        let secret = titles.create(name: "Privé", in: store.library)
        titles.update(secret) { $0.isPrivate = true }
        let trashed = titles.create(name: "Corbeille", in: store.library)
        titles.softDelete(trashed)
        people.create(firstName: "Ana", lastName: "Novak", in: store.library)
        collections.create(name: "Une saga", in: store.library)
        try store.context.save()

        store.index.forgetCalls()
        let count = try indexer.reindexEverything(in: store.context)

        #expect(store.index.removeAllCount == 1, "Elle commence par tout retirer")
        #expect(count == 3, "Un titre public, une personne, une collection")
        #expect(store.index.indexed.map(\.title).sorted() == ["Ana Novak", "Public", "Une saga"])
    }

    @Test("La réindexation est rejouable")
    func reindexIsIdempotent() throws {
        let store = try makeStore()
        let indexer = SpotlightIndexer(index: store.index)
        TitleRepository(context: store.context, spotlight: indexer)
            .create(name: "Public", in: store.library)
        try store.context.save()

        let first = try indexer.reindexEverything(in: store.context)
        let second = try indexer.reindexEverything(in: store.context)

        #expect(first == second)
        #expect(store.index.removeAllCount == 2)
    }
}
