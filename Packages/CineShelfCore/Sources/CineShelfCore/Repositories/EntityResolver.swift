import Foundation
import SwiftData

// MARK: - Retrouver une entité par son nom, ou la créer
//
// **Ce type existe parce que l'import ne peut pas passer par les repositories.** Ils sont
// `@MainActor` — à cause de `SpotlightIndexer`, et pour de bonnes raisons — alors que
// `ImportActor` est un acteur avec son propre contexte. Recopier la règle de dédoublonnage
// dans l'acteur aurait produit deux règles, et la matinée du 2026-08-04 a montré ce que ça
// coûte : `CatalogBounds` a dû être extrait parce que l'édition en masse et l'import
// n'étaient pas d'accord sur les bornes d'une note.
//
// Ici c'est l'inverse du réflexe habituel : ce fichier n'est **pas** isolé, et ce sont les
// repositories `@MainActor` qui l'appellent. Une seule règle, deux appelants.
//
// **Ce qu'il ne fait pas**, et qui reste la raison d'être des repositories : ni journal, ni
// indexation Spotlight. Les deux dépendent du contexte d'appel — un import journalise **une**
// entrée pour le lot, et indexe en une passe après commit.

/// Retrouve ou crée les entités désignées par leur nom dans un fichier importé.
///
/// **Non isolé, et volontairement pas un `actor`.** Il travaille sur le `ModelContext` que
/// l'appelant lui donne, donc il hérite de l'isolation de celui-ci : appelé depuis
/// `@MainActor` il est sur le fil principal, appelé depuis `ImportActor` il est sur l'acteur.
/// C'est ce qui permet aux deux de partager la règle sans qu'aucun ne traverse une frontière.
///
/// Il n'est pas `Sendable` : il porte un `ModelContext` et un cache d'entités, qui
/// appartiennent tous deux au contexte qui les a lus.
public struct EntityResolver: ~Copyable {

    let context: ModelContext
    /// La bibliothèque d'accueil. Toute résolution y est bornée.
    let library: Library

    /// Le cache de lot : clé repliée → entité déjà résolue **dans cet import**.
    ///
    /// **C'est le dédoublonnage intra-lot, et sans lui l'import crée les doublons qu'il
    /// cherche à éviter.** Deux lignes citant « Villeneuve » sont résolues avant le moindre
    /// `save()` : le second `fetch` ne verrait donc pas la personne créée par la première, et
    /// `findOrCreate` en créerait une deuxième. Le cas est nommé dans `CLAUDE.md` — le
    /// comportement **avant** sauvegarde est ici le sujet, et le chemin SQL est couvert par
    /// les tests qui sauvegardent entre deux résolutions.
    private var cache = Cache()

    /// Les identifiants des entités que **ce** résolveur a créées.
    ///
    /// Deux usages, et le second est le plus important : l'appelant `@MainActor` s'en sert
    /// pour ne journaliser qu'une vraie création, et l'import s'en sert pour composer le
    /// `payload` qui rendra le lot annulable. Sans cette liste, « annuler tout l'import » ne
    /// saurait pas quoi retirer — et retirer un genre qui existait avant l'import effacerait
    /// les associations d'autres titres.
    public private(set) var createdIDs: Set<UUID> = []

    /// Un cache par type d'entité. Les clés se ressemblent — un nom replié — donc les mêler
    /// ferait qu'un genre « Action » et une collection « Action » se prendraient l'un pour
    /// l'autre.
    private struct Cache {
        var people: [String: Person] = [:]
        var collections: [String: TitleCollection] = [:]
        var genres: [String: Genre] = [:]
    }

    public init(context: ModelContext, library: Library) {
        self.context = context
        self.library = library
    }

    // MARK: Personnes

    /// La personne de ce nom dans la bibliothèque, sinon une personne neuve.
    ///
    /// **La clé de dédoublonnage est `sortName`**, et ce n'est pas un choix par défaut : le
    /// schéma est fermé depuis le 2026-08-03, donc `Person` n'aura pas de `nameKey` comme
    /// `Genre`. `sortName` est déjà exactement ce qu'il faut — « nom prénom » replié en locale
    /// invariante par `refreshDerived()` — donc il **est** la clé, sans champ neuf ni
    /// migration. Voir `docs/02` §3 pour le repliage.
    ///
    /// Le nom est coupé au dernier espace : « Denis Villeneuve » donne prénom « Denis » et nom
    /// « Villeneuve ». Un nom unique — « Madonna », un pseudonyme — va entièrement dans
    /// `lastName`, ce qui est aussi ce que `Person` suppose (`firstName` a `""` pour défaut).
    public mutating func person(named name: String) -> Person? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let (first, last) = Self.splitName(trimmed)
        let key = Person.sortKey(firstName: first, lastName: last)
        if let cached = cache.people[key] { return cached }

        if let existing = try? fetchOne(PersonQuery.living(sortName: key, inLibrary: library.id)) {
            cache.people[key] = existing
            return existing
        }

        let person = Person(firstName: first, lastName: last)
        person.library = library
        person.refreshDerived()
        context.insert(person)
        createdIDs.insert(person.id)
        cache.people[key] = person
        return person
    }

    /// Coupe un nom complet en prénom et nom.
    ///
    /// Au **dernier** espace et non au premier : « Jean Pierre Melville » a « Jean Pierre »
    /// pour prénom et « Melville » pour nom, ce qui est le cas fréquent. L'inverse mettrait
    /// « Pierre Melville » en nom de famille.
    static func splitName(_ name: String) -> (first: String, last: String) {
        guard let index = name.lastIndex(of: " ") else { return ("", name) }
        return (
            String(name[name.startIndex..<index]).trimmingCharacters(in: .whitespaces),
            String(name[name.index(after: index)...]).trimmingCharacters(in: .whitespaces)
        )
    }

    // MARK: Collections

    /// La collection de ce nom dans la bibliothèque, sinon une collection neuve.
    ///
    /// Clé : `sortName`, replié par `refreshDerived()`. Même motif que pour les personnes.
    public mutating func collection(named name: String) -> TitleCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = trimmed.foldedForMatching.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cache.collections[key] { return cached }

        let query = CollectionQuery.living(sortName: key, inLibrary: library.id)
        if let existing = try? fetchOne(query) {
            cache.collections[key] = existing
            return existing
        }

        let collection = TitleCollection(name: trimmed)
        collection.library = library
        collection.refreshDerived()
        context.insert(collection)
        createdIDs.insert(collection.id)
        cache.collections[key] = collection
        return collection
    }

    // MARK: Genres

    /// Le genre de ce nom, cible et bibliothèque, sinon un genre neuf.
    ///
    /// La règle vient de `GenreRepository.findOrCreate`, qui délègue désormais ici. Le filtre
    /// `deletedAt == nil` est porté par `GenreQuery.living` : sans lui, un genre mis à la
    /// corbeille ressusciterait avec toutes ses anciennes associations.
    public mutating func genre(named name: String, target: GenreTarget) -> Genre? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = Genre.key(for: trimmed)
        let cacheKey = "\(target.rawValue)\u{1F}\(key)"
        if let cached = cache.genres[cacheKey] { return cached }

        let query = GenreQuery.living(key: key, target: target, inLibrary: library.id)
        if let existing = try? fetchOne(query) {
            cache.genres[cacheKey] = existing
            return existing
        }

        let genre = Genre(name: trimmed, target: target)
        genre.library = library
        genre.refreshDerived()
        context.insert(genre)
        createdIDs.insert(genre.id)
        cache.genres[cacheKey] = genre
        return genre
    }

    // MARK: Titres — la recherche de doublon, qui ne crée rien

    /// Le titre qui fait doublon avec ce nom et cette année, s'il existe.
    ///
    /// **Clé : nom replié et année, dans la bibliothèque.** Décision du 2026-08-04, contre
    /// deux autres options. La réalisation en est exclue bien que la planche la cite : elle
    /// dépendrait d'une personne qu'il faut résoudre **avant** de savoir s'il y a doublon,
    /// donc de l'ordre des écritures, et une faute de frappe sur un nom de réalisateur créerait
    /// un doublon au lieu de l'éviter.
    ///
    /// Un titre **sans année** ne fait doublon qu'avec un autre titre sans année : deux
    /// « Dune » dont l'un est daté et l'autre non sont deux éditions différentes, et les
    /// confondre écrirait dans la mauvaise fiche. `sortName` est replié en locale invariante,
    /// donc la comparaison est reproductible d'un appareil à l'autre.
    ///
    /// Ne crée rien, contrairement aux autres méthodes : la création d'un titre appartient à
    /// `ImportWriter`, qui doit décider quoi faire du doublon avant d'écrire.
    public func existingTitle(named name: String, year: Int?) -> Title? {
        let key = name.foldedForMatching.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return try? fetchOne(
            TitleQuery.living(sortName: key, year: year, inLibrary: library.id))
    }

    // MARK: Le fetch commun

    /// Le premier résultat d'un prédicat, ou `nil`.
    ///
    /// `fetchLimit = 1` : ces recherches sont faites une fois par ligne importée, soit 1 284
    /// fois sur le fichier de l'addendum. Sans limite, SQLite matérialise tous les
    /// homonymes.
    private func fetchOne<Model: PersistentModel>(_ predicate: Predicate<Model>) throws -> Model? {
        var descriptor = FetchDescriptor<Model>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

extension Person {
    /// La clé de dédoublonnage d'une personne, telle que `refreshDerived()` la compose.
    ///
    /// Écrite ici plutôt que recopiée dans le résolveur : c'est `refreshDerived()` qui décide
    /// de la forme de `sortName`, et une clé calculée autrement ne retrouverait rien. Le test
    /// `personSortKeyMatchesRefreshDerived` compare les deux — sans lui, changer l'un des deux
    /// casserait le dédoublonnage **en silence**, la recherche ne trouvant simplement jamais
    /// de doublon.
    public static func sortKey(firstName: String, lastName: String) -> String {
        "\(lastName) \(firstName)"
            .foldedForMatching
            .trimmingCharacters(in: .whitespaces)
    }
}
