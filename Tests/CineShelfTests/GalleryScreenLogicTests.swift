import CineShelfCore
import DesignSystem
import Foundation
import SwiftData
import Testing

// MARK: - V3 · Ce que l'écran de galerie décide, hors de l'écran
//
// **Ce fichier ne teste aucune vue.** Il teste les deux types que `V3` a sortis de la vue
// précisément pour qu'ils soient testables : `GalleryOrder` (quels médias, dans quel ordre) et
// `GalleryFormat` (ce qu'on affiche d'un média). La règle du projet — l'arithmétique ne vit
// jamais dans une `View` — a ici son bénéfice habituel : aucune de ces assertions n'a besoin
// d'un rendu, donc aucune ne risque le contrôle d'isolation qui tue le processus de test.

@MainActor
struct GalleryOrderTests {

    private func makeAssets(_ count: Int) -> [MediaAsset] {
        (0..<count).map { index in
            let asset = MediaAsset()
            asset.pixelWidth = 600 + index
            asset.pixelHeight = 900
            return asset
        }
    }

    @Test("Sans restriction, tout passe et l'ordre est conservé")
    func noRestrictionKeepsEverything() {
        let assets = makeAssets(6)
        let ordered = GalleryOrder.arrange(assets, restrictedTo: nil, filter: GalleryFilter())
        #expect(ordered.map(\.id) == assets.map(\.id))
    }

    @Test("La restriction ne garde que les identifiants demandés")
    func restrictionFilters() {
        let assets = makeAssets(6)
        let kept = Set(assets.prefix(2).map(\.id))
        let ordered = GalleryOrder.arrange(assets, restrictedTo: kept, filter: GalleryFilter())
        #expect(Set(ordered.map(\.id)) == kept)
    }

    @Test("Le mélange est stable à graine égale, et différent d'une graine à l'autre")
    func shuffleIsSeeded() {
        // Source : `docs/PROMPTS.md`, fiche `L1 bis` — « mélange à graine stable (le même ordre
        // tant qu'on ne rafraîchit pas) ». C'est la propriété qui fait de la galerie un écran
        // utilisable : un ordre retiré d'un `random` à chaque évaluation de vue déplacerait les
        // images pendant qu'on les regarde.
        let assets = makeAssets(40)
        let seeded = GalleryFilter(shuffleSeed: 12_345)
        let first = GalleryOrder.arrange(assets, restrictedTo: nil, filter: seeded)
        let again = GalleryOrder.arrange(assets, restrictedTo: nil, filter: seeded)
        #expect(first.map(\.id) == again.map(\.id))

        let other = GalleryOrder.arrange(
            assets, restrictedTo: nil, filter: GalleryFilter(shuffleSeed: 999))
        #expect(other.map(\.id) != first.map(\.id))
        // Un mélange qui perd ou duplique un élément serait pire qu'un ordre figé.
        #expect(Set(first.map(\.id)) == Set(assets.map(\.id)))
    }

    @Test("Sans graine, l'ordre reste celui de la requête")
    func noSeedNoShuffle() {
        let assets = makeAssets(20)
        let ordered = GalleryOrder.arrange(assets, restrictedTo: nil, filter: GalleryFilter())
        #expect(ordered.map(\.id) == assets.map(\.id))
    }

    @Test("La restriction s'applique avant le mélange")
    func restrictionComesBeforeShuffle() {
        // L'ordre des deux opérations est observable, et c'est pour ça qu'il est fixé : mélanger
        // d'abord puis filtrer donnerait, à graine égale, un ordre relatif différent selon le
        // filtre — donc un « même mélange » qui n'en serait pas un. Ici, les trois médias
        // retenus gardent entre eux l'ordre qu'ils ont quand on les mélange seuls.
        let assets = makeAssets(12)
        let kept = Set(assets.prefix(3).map(\.id))
        let filter = GalleryFilter(shuffleSeed: 7)

        let restrictedThenShuffled = GalleryOrder.arrange(
            assets, restrictedTo: kept, filter: filter)
        let shuffledAlone = GalleryOrder.arrange(
            Array(assets.prefix(3)), restrictedTo: nil, filter: filter)
        #expect(restrictedThenShuffled.map(\.id) == shuffledAlone.map(\.id))
    }
}

@MainActor
struct GalleryFormatTests {

    @Test("La proportion vient des pixels, et un média sans dimensions prend le repli")
    func aspectComesFromPixels() {
        let asset = MediaAsset()
        asset.pixelWidth = 1_260
        asset.pixelHeight = 540
        #expect(abs(GalleryFormat.aspect(of: asset) - 21.0 / 9) < 0.0001)

        // Le cas réel, et il n'est pas exotique : `pixelWidth` et `pixelHeight` valent **0 par
        // défaut** — toute propriété du schéma fermé a une valeur par défaut —, donc un média
        // importé avant que ses dimensions soient lues arrive ici en 0/0. Sans repli, la
        // division rend `nan` et la tuile n'a plus de hauteur : elle disparaît.
        let unknown = MediaAsset()
        #expect(GalleryFormat.aspect(of: unknown) == MasonryColumns.fallbackAspect)
    }

    @Test("Un média sans pièce jointe est un orphelin")
    func noAttachmentMeansOrphan() {
        // C'est la seule lecture de `attachments` qui soit sûre : en Swift, sur un objet déjà
        // chargé. La même expression dans un `#Predicate` **tue le processus** au premier
        // `fetch` (KVC aggregate) — c'est la mesure de `L1 bis`, et c'est pour ça que la source
        // « orphelin » se calcule par différence d'ensembles et non par prédicat.
        #expect(GalleryFormat.source(of: MediaAsset()) == .orphan)
        #expect(GalleryFormat.owner(of: MediaAsset()) == nil)
        #expect(GalleryFormat.caption(of: MediaAsset()) == "Sans rattachement")
    }

    @Test("La source se déduit du propriétaire de la pièce jointe")
    func sourceFollowsTheOwner() {
        let asset = MediaAsset()
        let attachment = MediaAttachment(slot: .gallery)
        let title = Title(name: "Oppenheimer")
        attachment.asset = asset
        attachment.title = title
        asset.attachments = [attachment]

        #expect(GalleryFormat.source(of: asset) == .title)
        #expect(GalleryFormat.owner(of: asset) == "Oppenheimer")
        #expect(GalleryFormat.caption(of: asset) == "Oppenheimer · galerie")

        asset.pixelWidth = 2_000
        asset.pixelHeight = 3_000
        // La ligne du bloc `6c` : « Oppenheimer · affiche · 2000 × 3000 ».
        attachment.slot = .primary
        #expect(GalleryFormat.caption(of: asset) == "Oppenheimer · affiche · 2000 × 3000")
    }

    @Test("Les compteurs sont ceux des blocs 6c et 6d")
    func countersMatchTheBlocks() {
        // Source : planche 4, bloc `6c` (« 12 / 47 ») et bloc `6d` (« Image 14 sur 47 »). Les
        // deux comptent **à partir de 1** alors que l'index est à partir de 0 : c'est la seule
        // chose que ces deux fonctions font, et c'est exactement le genre de décalage qu'on
        // n'attrape jamais à l'œil sur une capture.
        #expect(GalleryFormat.counter(11, of: 47) == "12 / 47")
        #expect(GalleryFormat.position(13, of: 47) == "Image 14 sur 47")
    }

    @Test("Le résumé de sélection compte les images et leur poids")
    func selectionSummaryCountsBoth() {
        let assets = (0..<6).map { _ in
            let asset = MediaAsset()
            asset.byteSize = 3_066_666
            return asset
        }
        let summary = GalleryFormat.selectionSummary(assets)
        #expect(summary.hasPrefix("6 images · "))
        // Le singulier, parce que « 1 images » est le défaut qu'on lit dans toutes les apps.
        #expect(GalleryFormat.selectionSummary([MediaAsset()]) == "1 image")
        // Poids inconnu : la mention disparaît plutôt que d'afficher « 0 ko ».
        #expect(GalleryFormat.selectionSummary([MediaAsset(), MediaAsset()]) == "2 images")
    }
}
