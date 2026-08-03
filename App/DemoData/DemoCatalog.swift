#if DEBUG

    import CineShelfCore
    import CoreGraphics
    import Foundation
    import ImageIO
    import SwiftData
    import UniformTypeIdentifiers

    // Un catalogue d'exemple, en DEBUG uniquement.
    //
    // Sans données, une grille vide ne prouve rien : ni la mise en page, ni le
    // tri, ni les filtres, ni le budget de défilement. Ce générateur produit de
    // quoi juger — et de quoi mesurer.
    //
    // Les jaquettes sont **dessinées par le code** (dégradé + initiales) plutôt
    // qu'embarquées : aucun octet d'image dans le dépôt, aucune question de
    // droits, et un rendu déterministe d'une exécution à l'autre.
    //
    // ---------------------------------------------------------------------
    // Pourquoi ce fichier ne passe pas par les repositories — décision, pas
    // oubli. Ne pas « corriger ».
    //
    // `docs/04` §3 impose que les créations passent par un repository. La règle
    // vise les actions de l'utilisateur : elle garantit que rien ne contourne
    // `refreshDerived()`, et elle inscrit chaque geste au fil d'activité. Ici
    // ce second effet est indésirable — générer une fixture produirait plus de
    // trois cents `ActivityEntry` fictives, et le fil d'activité du prompt 16
    // afficherait une bibliothèque construite par un fantôme.
    //
    // Ce qui reste non négociable, c'est le **premier** effet : `refreshDerived()`
    // est appelé sur chaque entité qui en a un, après que tous ses champs source
    // sont posés. Contourner les repositories ne doit pas contourner l'invariant.
    // `DemoCatalogTests` échoue si un `sortName` ou un `searchText` reste vide.
    // ---------------------------------------------------------------------

    /// Génère et supprime un catalogue de démonstration.
    @MainActor
    enum DemoCatalog {

        static let titleCount = 120
        static let personCount = 30
        static let collectionCount = 6

        /// Marqueur des données de démonstration, pour pouvoir les retirer sans
        /// toucher aux vraies. Rangé dans `Title.summary` serait sale : on passe
        /// par un genre dédié, qui est aussi ce qui permet de tout retrouver.
        static let markerGenreName = "Démonstration"

        // MARK: Génération

        /// - Parameters:
        ///   - context: le magasin où écrire.
        ///   - library: la bibliothèque d'accueil.
        ///   - count: le nombre de titres. Paramétrable pour les tests, qui
        ///     n'ont pas besoin de dessiner cent vingt jaquettes pour vérifier
        ///     un invariant.
        /// - Throws: ce que remontent `GenreRepository.findOrCreate` et
        ///   `ModelContext.save()`.
        static func populate(in context: ModelContext, library: Library, count: Int = titleCount) throws {
            var generator = SeededGenerator(seed: 20_260_803)

            let marker = try GenreRepository(context: context)
                .findOrCreate(name: markerGenreName, target: .title, in: library)

            let genres = try Self.genres.map {
                try GenreRepository(context: context).findOrCreate(name: $0, target: .title, in: library)
            }
            let people = makePeople(in: context, library: library, using: &generator)
            let collections = makeCollections(in: context, library: library)

            for index in 0..<count {
                makeTitle(
                    index: index,
                    in: context,
                    fixtures: Fixtures(
                        library: library,
                        marker: marker,
                        genres: genres,
                        people: people,
                        collections: collections
                    ),
                    using: &generator
                )
            }

            try context.save()
        }

        /// Retire les titres de démonstration et tout ce qui n'appartient qu'à
        /// eux, sans jamais toucher aux données réelles.
        ///
        /// **Les dix genres thématiques ne sont pas supprimés**, et c'est
        /// volontaire : ils viennent de `findOrCreate`, qui réutilise un genre
        /// homonyme existant. Rien ne distingue « genre créé par la démo » de
        /// « genre réel réutilisé », donc les supprimer détruirait
        /// potentiellement une donnée de l'utilisateur. Seul le marqueur, dont
        /// le nom est réservé, est retiré.
        ///
        /// La première version supprimait « toutes les personnes sans crédit »
        /// et « toutes les collections vides » du magasin entier : une personne
        /// réelle saisie sans filmographie, une collection encore vide, et elles
        /// disparaissaient. On ne se fie donc plus à une heuristique mais à un
        /// marquage explicite, posé à la génération.
        static func clear(in context: ModelContext, library: Library) throws {
            let libraryID = library.id
            let marker = try markerGenre(in: context, libraryID: libraryID)
            guard let marker else { return }

            for title in marker.titles ?? [] where title.library?.id == libraryID {
                for attachment in title.attachments ?? [] {
                    if let asset = attachment.asset { context.delete(asset) }
                    context.delete(attachment)
                }
                for credit in title.credits ?? [] {
                    context.delete(credit)
                }
                context.delete(title)
            }

            // Les personnes et les collections ne sont **pas** atteintes par les
            // titres : `populate` en crée un stock fixe, et un tirage aléatoire
            // peut n'en distribuer qu'une partie. Les balayer depuis les titres
            // laissait donc derrière lui toutes celles qui n'avaient reçu ni
            // crédit ni titre. On les cherche par leur marqueur, qui est le seul
            // critère fiable.
            for person in try context.fetch(FetchDescriptor<Person>())
            where person.library?.id == libraryID && isDemo(person) {
                context.delete(person)
            }
            for collection in try context.fetch(FetchDescriptor<TitleCollection>())
            where collection.library?.id == libraryID && isDemo(collection) {
                context.delete(collection)
            }

            context.delete(marker)
            try context.save()
        }

        static func isPopulated(in context: ModelContext, library: Library) -> Bool {
            (try? markerGenre(in: context, libraryID: library.id)) != nil
        }

        /// Le genre marqueur de **cette** bibliothèque.
        ///
        /// Recherche sur `nameKey` et non sur `name` : c'est la clé que
        /// `GenreRepository.findOrCreate` utilise, et elle est repliée sans
        /// accents ni casse. Chercher sur `name` laissait passer le cas où la
        /// bibliothèque contient déjà « demonstration » — `findOrCreate` le
        /// renvoyait comme marqueur, mais `markerGenre` ne le retrouvait plus :
        /// le bouton « Vider » devenait un no-op silencieux et les titres de
        /// démonstration n'étaient plus supprimables.
        private static func markerGenre(in context: ModelContext, libraryID: UUID) throws -> Genre? {
            let key = Genre.key(for: markerGenreName)
            let descriptor = FetchDescriptor<Genre>(
                predicate: #Predicate<Genre> { $0.nameKey == key && $0.deletedAt == nil })
            return try context.fetch(descriptor).first { $0.library?.id == libraryID }
        }

        /// Le marquage des personnes et des collections.
        ///
        /// Dans un champ de texte libre qu'elles possèdent déjà — `bio` et
        /// `summary` — plutôt que dans un champ technique ajouté au modèle pour
        /// l'occasion. Le marqueur est visible, et c'est bien : une donnée de
        /// démonstration doit se reconnaître à l'œil.
        static let marker = "[démo]"

        private static func isDemo(_ person: Person) -> Bool {
            person.bio?.hasPrefix(marker) ?? false
        }

        private static func isDemo(_ collection: TitleCollection) -> Bool {
            collection.summary?.hasPrefix(marker) ?? false
        }

        // MARK: Fabriques

        /// Ce que la fabrique d'un titre a besoin de connaître. Un type plutôt
        /// que huit paramètres à la file.
        private struct Fixtures {
            let library: Library
            let marker: Genre
            let genres: [Genre]
            let people: [Person]
            let collections: [TitleCollection]
        }

        private static func makeTitle(
            index: Int,
            in context: ModelContext,
            fixtures: Fixtures,
            using generator: inout SeededGenerator
        ) {
            let library = fixtures.library
            let marker = fixtures.marker
            let genres = fixtures.genres
            let people = fixtures.people
            let collections = fixtures.collections

            let name = titleName(index: index, using: &generator)
            let kind: TitleKind = generator.next(upTo: 10) < 2 ? .series : .movie

            let title = Title(name: name, kind: kind)
            title.library = library
            title.summary = summary(using: &generator)
            title.rating = Double(generator.next(upTo: 61) + 30) / 10
            title.isArchived = generator.next(upTo: 20) == 0
            title.isPrivate = generator.next(upTo: 25) == 0

            let year = 1960 + generator.next(upTo: 66)
            var components = DateComponents()
            components.year = year
            components.month = 1 + generator.next(upTo: 12)
            components.day = 1 + generator.next(upTo: 28)
            title.releaseDate = Calendar(identifier: .gregorian).date(from: components)

            if kind == .series {
                title.seasonCount = 1 + generator.next(upTo: 8)
                title.episodeCount = title.seasonCount.map { $0 * (6 + generator.next(upTo: 12)) }
            } else {
                // Réparti sur les trois tranches, pour que les filtres de durée
                // aient de quoi mordre.
                title.runtimeMinutes = 70 + generator.next(upTo: 95)
            }

            title.genres = [marker] + genres.shuffled(using: &generator).prefix(1 + generator.next(upTo: 3))

            if generator.next(upTo: 3) > 0, let collection = collections.randomElement(using: &generator) {
                title.collection = collection
            }

            context.insert(title)

            attachPoster(to: title, in: context, using: &generator)
            attachCredits(to: title, people: people, in: context, using: &generator)

            // En dernier, une fois les relations posées : `refreshDerived()`
            // écrit aussi `updatedAt`, qui serait sinon antérieur à la jaquette
            // et au casting du titre.
            title.refreshDerived()
        }

        private static func attachPoster(
            to title: Title, in context: ModelContext, using generator: inout SeededGenerator
        ) {
            guard let data = PosterArtwork.png(for: title.name, seed: generator.next(upTo: 360)) else {
                return
            }

            let asset = MediaAsset()
            asset.kindRaw = MediaKind.image.rawValue
            asset.data = data
            asset.mimeType = "image/png"
            asset.pixelWidth = PosterArtwork.size.width
            asset.pixelHeight = PosterArtwork.size.height
            asset.byteSize = data.count
            asset.checksum = "demo-\(title.id.uuidString)"
            context.insert(asset)

            let attachment = MediaAttachment()
            attachment.slotRaw = MediaSlot.primary.rawValue
            attachment.orderIndex = 0
            attachment.asset = asset
            attachment.title = title
            context.insert(attachment)
        }

        private static func attachCredits(
            to title: Title,
            people: [Person],
            in context: ModelContext,
            using generator: inout SeededGenerator
        ) {
            let cast = people.shuffled(using: &generator).prefix(2 + generator.next(upTo: 5))

            for (index, person) in cast.enumerated() {
                let credit = Credit()
                credit.roleRaw = index == 0 ? CreditRole.director.rawValue : CreditRole.cast.rawValue
                credit.orderIndex = index
                credit.characterName = index == 0 ? nil : characterNames.randomElement(using: &generator)
                credit.person = person
                credit.title = title
                context.insert(credit)
            }
        }

        private static func makePeople(
            in context: ModelContext, library: Library, using generator: inout SeededGenerator
        ) -> [Person] {
            (0..<personCount).map { index in
                let person = Person(
                    firstName: firstNames[index % firstNames.count],
                    lastName: lastNames[(index * 7) % lastNames.count]
                )
                person.library = library
                person.bio = "\(marker) Personne de démonstration."

                // Réparti sur les trois tranches d'âge, pour la même raison que les
                // durées le sont sur les trois tranches de `RuntimeBand` : un filtre
                // sans donnée à mordre ne se teste pas à l'œil. Un sur sept est
                // décédé, ce qui est le seul cas où `ageAtDeath` sert.
                let age = 22 + generator.next(upTo: 55)
                person.birthDate = Calendar(identifier: .gregorian)
                    .date(byAdding: .year, value: -age, to: .now)
                if generator.next(upTo: 7) == 0 {
                    person.deathDate = Calendar(identifier: .gregorian)
                        .date(byAdding: .year, value: -generator.next(upTo: 12), to: .now)
                }

                person.refreshDerived()
                context.insert(person)
                return person
            }
        }

        private static func makeCollections(
            in context: ModelContext, library: Library
        ) -> [TitleCollection] {
            collectionNames.prefix(collectionCount).map { name in
                let collection = TitleCollection(name: name)
                collection.library = library
                collection.summary = "\(marker) Collection de démonstration."
                collection.refreshDerived()
                context.insert(collection)
                return collection
            }
        }

        // MARK: Vocabulaire

        private static func titleName(index: Int, using generator: inout SeededGenerator) -> String {
            let pattern = generator.next(upTo: 4)
            let noun = nouns[generator.next(upTo: nouns.count)]
            let adjective = adjectives[generator.next(upTo: adjectives.count)]
            let place = places[generator.next(upTo: places.count)]

            return switch pattern {
            case 0: "\(noun) \(adjective)"
            case 1: "Le \(noun) de \(place)"
            case 2: "\(place), \(1960 + generator.next(upTo: 60))"
            default: "\(noun) et \(nouns[generator.next(upTo: nouns.count)].lowercased())"
            }
        }

        private static func summary(using generator: inout SeededGenerator) -> String {
            summaries[generator.next(upTo: summaries.count)]
        }

        private static let nouns = [
            "La Nuit", "Le Silence", "L'Étranger", "La Frontière", "Le Voyage", "L'Aube",
            "Le Rivage", "La Chambre", "Le Chemin", "La Lumière", "Le Cercle", "L'Été",
            "La Traversée", "Le Signal", "La Vallée", "L'Ombre", "Le Passage", "La Dérive"
        ]
        private static let adjectives = [
            "immobile", "sans fin", "oublié", "d'hiver", "en suspens", "invisible",
            "des origines", "au loin", "fragile", "en creux"
        ]
        private static let places = [
            "Trieste", "Naples", "Lisbonne", "Oslo", "Tanger", "Kyoto", "Valparaiso",
            "Reykjavik", "Séville", "Bucarest"
        ]
        private static let genres = [
            "Drame", "Comédie", "Policier", "Science-fiction", "Documentaire",
            "Animation", "Thriller", "Romance", "Aventure", "Historique"
        ]
        private static let collectionNames = [
            "Cycle italien", "Nouvelle Vague", "Films de montagne", "Trilogie du silence",
            "Vus en salle", "Grands formats"
        ]
        private static let firstNames = [
            "Ana", "Marek", "Louise", "Tomás", "Ingrid", "Yuki", "Samir", "Elena",
            "Jonas", "Clara", "Rafael", "Nina", "Omar", "Lise", "Petra"
        ]
        private static let lastNames = [
            "Novak", "Berger", "Costa", "Lindqvist", "Marchetti", "Haddad", "Weiss",
            "Duarte", "Kovacs", "Renard", "Sato", "Almeida", "Vidal"
        ]
        private static let characterNames = [
            "le gardien", "la géologue", "l'archiviste", "Mira", "le passeur",
            "la voisine", "Andreas", "la traductrice"
        ]
        private static let summaries = [
            "Une disparition rouvre une enquête que tout le monde croyait close.",
            "Deux inconnus partagent un trajet de nuit et n'en sortent pas indemnes.",
            "Un village décide de ne plus répondre aux questions.",
            "L'été où tout aurait pu basculer, raconté trente ans plus tard.",
            "Une cartographe relève une côte qui n'existe sur aucune carte."
        ]
    }

#endif
