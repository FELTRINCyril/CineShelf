import CineShelfCore
import DesignSystem
import Foundation
import SwiftData
import Testing

// MARK: - V3 · Les échantillons exercent-ils vraiment ce qu'on croit ?
//
// **C'est la porte que `catalogue-images` a apprise à ses dépens.** Une galerie dont les
// échantillons n'ont ni ratios mêlés, ni orphelin, ni image sur une personne, valide un écran
// qui ne rend rien de ce qu'il prétend rendre — et elle passe au vert. Ce fichier assène donc
// sur les **données**, pas sur la vue : les quatre sources existent, les proportions
// dégénérées sont présentes, et « Vider » ne laisse rien derrière lui.
//
// Il porte aussi la **mesure** de la branche « orphelin », qui a un écart inscrit : elle
// charge tous les identifiants de médias et n'est indexée par rien. Ces fixtures sont la
// première occasion de l'exercer pour de vrai.

@MainActor
struct GalleryFixtureTests {

    private func makeFixture() throws -> (context: ModelContext, library: Library) {
        let container = try ModelContainer(
            for: Persistence.schema,
            migrationPlan: CineShelfMigrationPlan.self,
            configurations: ModelConfiguration(schema: Persistence.schema, isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let library = Library()
        context.insert(library)
        return (context, library)
    }

    /// Douze titres : l'invariant ne dépend pas du nombre, et chaque média fait dessiner puis
    /// encoder une image.
    private let count = 12

    @Test("Les quatre sources de la galerie ont de quoi filtrer")
    func everySourceHasMedia() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        // **Le fetch passe par le magasin**, comme la règle du projet l'exige pour tout ce qui
        // touche à un prédicat : `GalleryQuery` en pose trois, et un test sur des objets encore
        // en attente n'exercerait pas leur traduction SQL.
        for source in MediaSource.allCases {
            let ids = try GalleryQuery.assetIDs(
                matching: GalleryFilter(sources: [source]), in: context)
            #expect(!ids.isEmpty, "aucun média pour la source « \(source.rawValue) »")
        }
    }

    @Test("Les proportions dégénérées sont réellement présentes")
    func degenerateAspectsArePresent() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        let assets = try context.fetch(FetchDescriptor<MediaAsset>())
        let aspects = assets.map { GalleryFormat.aspect(of: $0) }

        // 21:9 et 9:21, les deux extrêmes que la maçonnerie doit encaisser. Sans elles, la
        // répartition en colonnes n'est jamais mise à l'épreuve : entre 2:3 et 16:9, n'importe
        // quel algorithme paraît correct.
        #expect(aspects.contains { $0 > 2.2 }, "aucun panoramique 21:9")
        #expect(aspects.contains { $0 < 0.5 }, "aucun bandeau vertical 9:21")
        #expect(aspects.contains { abs($0 - 1) < 0.01 }, "aucun carré")

        // Et le média **sans dimensions lues**, qui emprunte le repli. C'est le cas que le
        // schéma rend inévitable — `pixelWidth` vaut 0 par défaut — donc celui qu'un jeu
        // d'échantillons « propre » aurait oublié.
        #expect(
            assets.contains { $0.pixelHeight == 0 },
            "aucun média sans dimensions : le repli de MasonryColumns n'est exercé par rien")
    }

    @Test("Les images de galerie portent un blurHash")
    func galleryAssetsCarryABlurHash() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)

        // Les images de galerie passent par `MediaIngestor`, donc par le chemin réel de
        // l'import : elles ont un `blurHash`. **Les jaquettes n'en ont toujours pas** — elles
        // remplissent leurs champs à la main depuis le prompt 11 — donc l'assertion porte sur
        // les médias de galerie seulement, et l'écart est inscrit pour les autres.
        let gallery = try context.fetch(FetchDescriptor<MediaAttachment>())
            .filter { $0.slot == .gallery }
            .compactMap(\.asset)
        #expect(!gallery.isEmpty)
        #expect(gallery.allSatisfy { !($0.blurHash ?? "").isEmpty })
    }

    @Test("Vider les données de démonstration ne laisse aucun média derrière")
    func clearLeavesNoAsset() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: count)
        #expect(try !context.fetch(FetchDescriptor<MediaAsset>()).isEmpty)

        try DemoCatalog.clear(in: context, library: library)

        // **C'est l'orphelin qui rend ce test nécessaire.** `clear` retrouve les jaquettes en
        // descendant genre marqueur → titre → pièce jointe → média ; un orphelin n'a aucun
        // chemin de ce genre, et les images d'une personne ou d'une collection ne perdent que
        // leur pièce jointe par cascade, jamais leur média. Sans le balayage explicite, chaque
        // « Vider » laissait des médias que plus rien ne rattachait.
        #expect(try context.fetch(FetchDescriptor<MediaAsset>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MediaAttachment>()).isEmpty)
    }

    // MARK: La mesure de la branche « orphelin »

    @Test("Mesure — le coût de la source « orphelin »")
    func orphanBranchIsMeasured() throws {
        let (context, library) = try makeFixture()
        try DemoCatalog.populate(in: context, library: library, count: 60)

        let assets = try context.fetch(FetchDescriptor<MediaAsset>()).count
        let attachments = try context.fetch(FetchDescriptor<MediaAttachment>()).count

        let owned = try measure {
            try GalleryQuery.assetIDs(matching: GalleryFilter(sources: [.title]), in: context)
        }
        let orphans = try measure {
            try GalleryQuery.assetIDs(matching: GalleryFilter(sources: [.orphan]), in: context)
        }

        // **Aucun seuil.** L'écart inscrit dit que la branche est linéaire et non indexée, et
        // c'est un fait de conception, pas une régression à surveiller : la soustraction doit
        // porter sur *toutes* les pièces jointes, sinon décocher « titre » ferait passer ses
        // médias pour des orphelins. Ce qu'on assène est donc la **justesse**, et ce qu'on
        // rapporte est le coût — sur un runner GitHub virtualisé, un plafond de durée ne
        // mesurerait que la machine.
        #expect(orphans.value.count == DemoCatalog.orphanCount)
        #expect(owned.value.isDisjoint(with: orphans.value))

        print(
            """
            [V3] source « orphelin » sur \(assets) médias et \(attachments) pièces jointes : \
            \(orphans.value.count) orphelins en \(orphans.milliseconds) ms, \
            contre \(owned.value.count) médias de titres en \(owned.milliseconds) ms \
            (la branche « orphelin » fait deux fetch complets, l'autre un seul filtré)
            """)
    }

    private func measure<T>(_ work: () throws -> T) throws -> (value: T, milliseconds: String) {
        let start = ContinuousClock.now
        let value = try work()
        let elapsed = ContinuousClock.now - start
        return (value, String(format: "%.1f", Double(elapsed.components.attoseconds) / 1e15))
    }
}
