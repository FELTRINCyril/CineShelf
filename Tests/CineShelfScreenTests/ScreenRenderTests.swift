import CoreGraphics
import SwiftData
import SwiftUI
import Testing

@testable import CineShelf
@testable import CineShelfCore
@testable import DesignSystem

// MARK: - La porte de non-vacuité des écrans
//
// **Ce fichier existe parce que la règle « une tâche `V` se termine par un rendu assené » a
// buté sur un mur architectural à `V4`/`V5b`, pas sur un oubli.** `CineShelfTests` n'a aucune
// app hôte — elle compile des fichiers de `App/` un par un, pour ne jamais lancer l'interface
// —, donc instancier une vue y échoue **au lien** : « nominal type descriptor for
// CineShelf.PeopleView not found ». La sonde avait été écrite puis retirée.
//
// La cible `CineShelfScreenTests` a un `TEST_HOST`. C'est la seule, et elle ne sert qu'à ça.
//
// **Ce que ces tests ne prouvent pas** : que c'est beau. Ce qu'ils prouvent, et qui n'est
// jamais acquis : que ces écrans dessinent quelque chose, et que deux états censés se
// distinguer se distinguent pour de vrai.
//
// **Pourquoi ça vaut la peine.** Deux fois déjà un modèle de présentation a perdu son image en
// silence — `MediaFill` chargé par `AsyncImage` pendant quatre sessions, puis
// `PosterCardModel(_ person:)` sans `imageURL`. Les deux fois, rien ne l'a vu, parce qu'un
// écran vide et un écran cassé rendent le même pixel. Les paires ci-dessous posent la question
// manquante.
//
// **Ce que cette porte ne couvre PAS, et il faut le dire pour qu'on ne s'y fie pas** : le
// *chargement* des images. `ImageRenderer` rend de façon synchrone, donc un `.task` n'a pas
// tourné — sans attente, « chargée », « en cours » et « en échec » rendent tous le
// placeholder. Le décor n'attache d'ailleurs aucun média, donc les affiches de la grille sont
// des aplats attendus. **Ce chemin-là est couvert ailleurs**, par `ContentRenderTests` du
// paquet `DesignSystem`, qui injecte un chargeur et laisse tourner la boucle
// (`renderStats(_:settling:)`). Ici on assène la composition et le peuplement ; là-bas, le
// chargement. Croire que cette suite couvre les deux serait exactement l'erreur qui a laissé
// passer `MediaFill`.

// MARK: - La sonde

/// Ce qu'on retient d'un rendu. **Le compte de couleurs distinctes, pas une empreinte** : deux
/// aplats de couleurs différentes ont deux empreintes différentes, donc une empreinte ne sait
/// pas distinguer « a dessiné » de « n'a rien dessiné ». C'est ce qui a laissé passer
/// `MediaFill`.
struct ScreenStats {
    let distinctColours: Int
    /// Un aplat : une seule couleur sur tout l'échantillon.
    var isUniform: Bool { distinctColours <= 1 }
}

func screenStats(of image: CGImage, steps: Int = 48) -> ScreenStats? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }
    guard
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = context.data else { return nil }
    let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var colours: Set<UInt32> = []
    for row in 0..<steps {
        for column in 0..<steps {
            let posX = min(width - 1, column * width / steps)
            let posY = min(height - 1, row * height / steps)
            let offset = (posY * width + posX) * 4
            colours.insert(
                UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8
                    | UInt32(bytes[offset + 2]))
        }
    }
    return ScreenStats(distinctColours: colours.count)
}

/// Rend une vue et rend ses statistiques.
///
/// **1 280 × 760**, le format des prototypes de la planche 3 : sonder un écran à une largeur
/// qu'aucune planche ne montre reviendrait à juger une mise en page qui n'existe pas.
@MainActor
func render(_ content: some View, width: CGFloat = 1_280, height: CGFloat = 760) -> ScreenStats? {
    let renderer = ImageRenderer(
        content:
            content
            .frame(width: width, height: height)
            .environment(\.colorScheme, .dark)
            // **`rendersFlat` est ce qui rend les fiches sondables du tout.** `ImageRenderer`
            // ne met pas en page un `ScrollView` — mesuré : un aplat d'une seule couleur, sans
            // contournement possible au niveau de l'enveloppe. `ScreenScroll` s'aplatit sur ce
            // drapeau, que seule cette sonde pose.
            .environment(\.rendersFlat, true))
    renderer.scale = 1
    guard let image = renderer.cgImage else { return nil }
    return screenStats(of: image)
}

// MARK: - Le décor
//
// **Chaque échantillon exerce le chemin réel, jamais le cas nul.** Chaque personne a des
// crédits, chaque rayon a des titres, chaque genre a des associations : un décor à zéro partout
// rendrait l'état vide sur les deux branches de chaque paire, et la porte serait aveugle sur
// ce qu'elle prétend séparer.

@MainActor
struct Stage {
    let container: ModelContainer
    let context: ModelContext
    let navigation = NavigationModel()
    let session: ProfileSession
    let library: Library

    init() throws {
        container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: Persistence.schema, isStoredInMemoryOnly: true))
        context = ModelContext(container)
        // Un domaine de préférences jetable : sans lui, deux décors partageraient le réglage
        // « ouvrir directement le dernier profil » et le cran d'affichage mémorisé.
        // `?? .standard` plutôt qu'un `!` : `init(suiteName:)` ne rend `nil` que sur un nom
        // réservé, ce qu'un UUID n'est jamais — mais la règle `no_force_unwrapping` vaut aussi
        // dans les tests, et un repli explicite coûte une ligne.
        session = ProfileSession(defaults: UserDefaults(suiteName: "screen.\(UUID())") ?? .standard)

        library = Library(name: "Sonde", isDefault: true)
        context.insert(library)
        let profile = Profile(name: "Sonde", isDefault: true)
        profile.library = library
        context.insert(profile)
        try context.save()
        session.open(profile)
    }

    /// **Des nombres quelconques** — sept personnes, trois rayons, cinq genres, neuf titres :
    /// ni zéro, ni un, ni une puissance de deux, pour qu'un décalage d'indice se voie.
    func populate() throws {
        let genreRepository = GenreRepository(context: context)
        let genres = try ["Drame", "Polar", "Science-fiction", "Western", "Comédie"]
            .map { try genreRepository.findOrCreate(name: $0, in: library) }

        let people = (0..<7).map { index -> Person in
            let person = PersonRepository(context: context)
                .create(firstName: "Prénom\(index)", lastName: "Nom\(index)", in: library)
            person.birthDate = Calendar.current.date(
                from: DateComponents(year: 1_954 + index * 3, month: 5, day: 17))
            person.bio = "Une biographie assez longue pour occuper deux lignes de la fiche."
            person.refreshDerived()
            return person
        }

        let collections = (0..<3).map { index in
            CollectionRepository(context: context).create(name: "Rayon \(index)", in: library)
        }

        for index in 0..<9 {
            let title = TitleRepository(context: context).create(name: "Titre \(index)", in: library)
            title.releaseDate = Calendar.current.date(
                from: DateComponents(year: 2_009 + index, month: 3, day: 12))
            title.rating = Double(index % 10)
            title.collection = collections[index % collections.count]
            title.genres = [genres[index % genres.count]]
            // **Deux crédits par titre** : « souvent avec » exige deux titres partagés, donc un
            // seul crédit par titre ne remplirait jamais ce rail — et le test passerait au vert
            // en couvrant une section vide.
            for offset in 0..<2 {
                let credit = Credit(role: .cast, orderIndex: offset)
                credit.title = title
                credit.person = people[(index + offset) % people.count]
                context.insert(credit)
            }
            title.refreshDerived()
        }

        genreRepository.setPinned(genres[1], true)
        genreRepository.setPinned(genres[3], true)
        try context.save()
    }

    func host(_ content: some View) -> some View {
        content
            .environment(navigation)
            .environment(session)
            .modelContainer(container)
    }
}

// MARK: - Les paires

@MainActor
@Suite("Rendu des écrans")
struct ScreenRenderTests {

    /// Le contrôle négatif. **Sans lui, toutes les assertions de non-uniformité seraient sans
    /// valeur** : elles passeraient tout aussi bien si `isUniform` était toujours faux.
    @Test("La sonde distingue un aplat d'un contenu")
    func probeSeparatesFlatFromDrawn() throws {
        let flat = try #require(render(Color.bgCanvas, width: 400, height: 300))
        #expect(flat.isUniform, "un aplat doit être vu comme uniforme")

        let drawn = try #require(
            render(Text("CineShelf").font(Typo.title1(.large)), width: 400, height: 300))
        #expect(!drawn.isUniform, "du texte doit sortir du cas uniforme")
    }

    @Test("L'écran Personnes dessine, et pas la même chose vide et peuplé")
    func peopleScreenDraws() throws {
        let empty = try Stage()
        let emptyStats = try #require(render(empty.host(PeopleView())))

        let filled = try Stage()
        try filled.populate()
        let filledStats = try #require(render(filled.host(PeopleView())))

        print(
            "Personnes — vide : \(emptyStats.distinctColours) couleurs · "
                + "peuplé : \(filledStats.distinctColours)")
        #expect(!emptyStats.isUniform, "l'état vide porte son message, donc il n'est pas uni")
        #expect(!filledStats.isUniform)
        // **La paire est le test.** Un environnement mal monté rendrait l'état vide dans les
        // deux cas, et les deux assertions ci-dessus passeraient quand même.
        #expect(
            filledStats.distinctColours != emptyStats.distinctColours,
            "sept personnes doivent changer le rendu")
    }

    @Test("L'écran Collections dessine ses rayons et sa section de genres")
    func collectionsScreenDraws() throws {
        let empty = try Stage()
        let emptyStats = try #require(render(empty.host(CollectionsView())))

        let filled = try Stage()
        try filled.populate()
        let filledStats = try #require(render(filled.host(CollectionsView())))

        print(
            "Collections — vide : \(emptyStats.distinctColours) couleurs · "
                + "peuplé : \(filledStats.distinctColours)")
        #expect(!filledStats.isUniform)
        #expect(
            filledStats.distinctColours != emptyStats.distinctColours,
            "trois rayons et cinq genres doivent changer le rendu")
    }

    @Test("La fiche personne dessine, et l'absence de personne rend autre chose")
    func personDetailDraws() throws {
        let stage = try Stage()
        try stage.populate()
        let person = try #require(try stage.context.fetch(FetchDescriptor<Person>()).first)

        let found = try #require(render(stage.host(PersonDetailView(personID: person.id))))
        // **Un identifiant qui n'existe pas** : l'écran doit dire « cette personne n'existe
        // plus », pas rendre une page blanche. Les deux se ressemblent à l'œil.
        let missing = try #require(render(stage.host(PersonDetailView(personID: UUID()))))

        print(
            "Fiche personne — trouvée : \(found.distinctColours) couleurs · "
                + "absente : \(missing.distinctColours)")
        #expect(!found.isUniform)
        #expect(!missing.isUniform, "l'écran « n'existe plus » porte un message")
        #expect(found.distinctColours != missing.distinctColours)
    }

    @Test("La fiche collection dessine son rayon et ses titres")
    func collectionDetailDraws() throws {
        let stage = try Stage()
        try stage.populate()
        let collection = try #require(
            try stage.context.fetch(FetchDescriptor<TitleCollection>()).first)

        let found = try #require(
            render(stage.host(CollectionDetailView(collectionID: collection.id))))
        let missing = try #require(render(stage.host(CollectionDetailView(collectionID: UUID()))))

        print(
            "Fiche collection — trouvée : \(found.distinctColours) couleurs · "
                + "absente : \(missing.distinctColours)")
        #expect(!found.isUniform)
        #expect(found.distinctColours != missing.distinctColours)
    }

    @Test("Le fil dessine ses journées, et le journal vide rend autre chose")
    func activityFeedDraws() throws {
        let empty = try Stage()
        let emptyStats = try #require(render(empty.host(ActivityFeedView())))

        let filled = try Stage()
        // Peupler **écrit** le journal : chaque `create` de repository enregistre une entrée.
        // C'est le chemin réel, pas des `ActivityEntry` fabriqués à la main.
        try filled.populate()
        let filledStats = try #require(render(filled.host(ActivityFeedView())))

        print(
            "Fil — vide : \(emptyStats.distinctColours) couleurs · "
                + "peuplé : \(filledStats.distinctColours)")
        #expect(!filledStats.isUniform)
        #expect(
            filledStats.distinctColours != emptyStats.distinctColours,
            "le journal des créations doit remplir le fil")
    }

    @Test("L'écran Signets dessine son état vide")
    func savedLinksScreenDraws() throws {
        let stage = try Stage()
        let stats = try #require(render(stage.host(SavedLinksView())))
        print("Signets — vide : \(stats.distinctColours) couleurs")
        // **Pas de paire ici, et c'est dit** : peupler demanderait d'écrire un signet dont
        // l'aperçu part en réseau, ce qu'aucun test de ce dépôt ne fait. L'assertion est donc
        // plus faible — l'écran dessine son état vide, ce qui prouve que son environnement se
        // monte.
        #expect(!stats.isUniform)
    }

    @Test("La grille des titres dessine, et le hero de l'accueil aussi")
    func existingScreensDraw() throws {
        // **Les deux écrans de `V0 bis` et `V5a`, sondés rétroactivement.** Ils ont été livrés
        // sans porte de rendu, et c'est justement sur eux que `MediaFill` est passé inaperçu.
        let stage = try Stage()
        try stage.populate()

        let titles = try #require(render(stage.host(TitlesView())))
        let home = try #require(render(stage.host(HomeView())))
        print("Titres : \(titles.distinctColours) couleurs · Accueil : \(home.distinctColours)")
        #expect(!titles.isUniform)
        #expect(!home.isUniform)
    }
}
