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

        static func populate(in context: ModelContext, library: Library) throws {
            var generator = SeededGenerator(seed: 20_260_803)

            let marker = try GenreRepository(context: context)
                .findOrCreate(name: markerGenreName, target: .title, in: library)

            let genres = try Self.genres.map {
                try GenreRepository(context: context).findOrCreate(name: $0, target: .title, in: library)
            }
            let people = makePeople(in: context, library: library, using: &generator)
            let collections = makeCollections(in: context, library: library)

            for index in 0..<titleCount {
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

        /// Retire tout ce que `populate` a créé, et **rien d'autre**.
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
                    // La personne est supprimée seulement si elle porte le
                    // marqueur de démonstration.
                    if let person = credit.person, isDemo(person) { context.delete(person) }
                    context.delete(credit)
                }
                if let collection = title.collection, isDemo(collection) {
                    context.delete(collection)
                }
                context.delete(title)
            }

            context.delete(marker)
            try context.save()
        }

        static func isPopulated(in context: ModelContext, library: Library) -> Bool {
            (try? markerGenre(in: context, libraryID: library.id)) != nil
        }

        /// Le genre marqueur de **cette** bibliothèque. Chercher par nom seul
        /// suffisait à emporter les titres d'un genre homonyme créé à la main.
        private static func markerGenre(in context: ModelContext, libraryID: UUID) throws -> Genre? {
            let name = markerGenreName
            let descriptor = FetchDescriptor<Genre>(predicate: #Predicate<Genre> { $0.name == name })
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

            title.refreshDerived()
            context.insert(title)

            attachPoster(to: title, in: context, using: &generator)
            attachCredits(to: title, people: people, in: context, using: &generator)
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
            "des origines", "au loin", "перевод", "fragile"
        ].filter { $0.allSatisfy { $0.isLetter || $0.isWhitespace || $0 == "'" } }
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

    // MARK: - Jaquettes dessinées

    // `no_literal_color` interdit les couleurs littérales hors du design system.
    // La règle vise le **style de l'interface** ; ici on synthétise les pixels
    // d'un fichier PNG, ce qui n'est pas la même chose : ces valeurs ne teintent
    // aucune vue, elles remplissent un bitmap de données de démonstration. Aller
    // les chercher dans le design system reviendrait à faire dépendre le
    // générateur d'un jeu de couleurs sémantique, qui n'a rien à dire ici.
    // swiftlint:disable no_literal_color

    /// Des jaquettes générées : dégradé déterministe et initiales du titre.
    enum PosterArtwork {

        static let size = (width: 600, height: 900)

        static func png(for title: String, seed: Int) -> Data? {
            let width = size.width
            let height = size.height

            guard
                let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return nil }

            drawGradient(in: context, size: CGSize(width: width, height: height), hue: seed)
            drawInitials(of: title, in: context, size: CGSize(width: width, height: height))

            guard let image = context.makeImage() else { return nil }
            return encodePNG(image)
        }

        private static func drawGradient(in context: CGContext, size: CGSize, hue: Int) {
            let base = CGFloat(hue % 360) / 360
            let colors =
                [
                    CGColor(red: base, green: 0.35, blue: 0.55, alpha: 1),
                    CGColor(red: base * 0.4, green: 0.12, blue: 0.28, alpha: 1)
                ] as CFArray

            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 1]
                )
            else { return }

            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        /// Les initiales, en aplat clair. Pas de police custom : le générateur
        /// tourne avant tout enregistrement de police.
        private static func drawInitials(of title: String, in context: CGContext, size: CGSize) {
            let initials =
                title
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)
                .map(String.init)
                .joined()
                .uppercased()

            guard !initials.isEmpty else { return }

            let side = size.width * 0.42
            let rect = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
            context.fillEllipse(in: rect)

            // Deux barres pour évoquer les initiales sans dépendre du texte :
            // CoreText demanderait une police, et l'échelle varie selon la
            // plateforme. Le repère visuel suffit pour juger une grille.
            let barHeight = side * 0.12
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
            context.fill(
                CGRect(
                    x: rect.minX + side * 0.2,
                    y: rect.midY + barHeight * 0.4,
                    width: side * 0.6 * CGFloat(initials.count) / 2,
                    height: barHeight
                ))
            context.fill(
                CGRect(
                    x: rect.minX + side * 0.2,
                    y: rect.midY - barHeight * 1.6,
                    width: side * 0.35,
                    height: barHeight
                ))
        }

        private static func encodePNG(_ image: CGImage) -> Data? {
            let data = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(
                    data, UTType.png.identifier as CFString, 1, nil)
            else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data
        }
    }

    // swiftlint:enable no_literal_color

    // MARK: - Aléa reproductible

    /// Générateur déterministe : deux exécutions donnent le même catalogue.
    ///
    /// C'est ce qui rend les mesures de performance comparables d'une session à
    /// l'autre, et les captures d'écran stables.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) { state = seed == 0 ? 0x4d59_5df4_d0f3_3173 : seed }

        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }

        mutating func next(upTo bound: Int) -> Int {
            bound <= 0 ? 0 : Int(next() % UInt64(bound))
        }
    }

#endif
