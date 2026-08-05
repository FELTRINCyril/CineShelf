#if DEBUG

    import CineShelfCore
    import DesignSystem
    import Foundation
    import MediaKit
    import SwiftData

    // MARK: - V3 · Des images de galerie, et de quoi exercer ce qui n'était jamais emprunté
    //
    // **Avant cette tâche, la galerie de démonstration était vide.** `DemoCatalog` ne posait
    // que des jaquettes (`slot: .primary`) et un backdrop sur un titre sur quatre : aucune
    // pièce jointe `.gallery`, aucune image sur une personne ou une collection, **aucun
    // orphelin**, et une seule proportion — 2:3, la même pour toutes.
    //
    // Autrement dit : l'écran de galerie aurait été **vide**, la maçonnerie n'aurait rien eu à
    // répartir, et trois des quatre branches du filtre par source n'auraient jamais été
    // empruntées. C'est le motif que `CLAUDE.md` nomme — « tout échantillon exerce le chemin
    // réel, jamais le cas nul » — et il aurait rendu la porte d'acceptation de `V3` aveugle
    // exactement comme `imageURL: nil` avait rendu celle de `I2` aveugle pendant quatre
    // sessions.
    //
    // **Les proportions sont choisies pour casser l'algorithme, pas pour être jolies.** La
    // maçonnerie additionne des hauteurs de colonne : ce sont donc les ratios extrêmes qui la
    // mettent à l'épreuve, et un jeu « franchement varié » entre 2:3 et 16:9 ne prouverait
    // rien. D'où le 21:9, le 9:21 — 5,4 fois plus haut à largeur égale — et le carré.
    //
    // **Ces images passent par `MediaIngestor`**, à la différence des jaquettes qui remplissent
    // leurs champs à la main. C'est le chemin réel de l'import, donc les dimensions et le
    // `blurHash` sont ceux que l'app produirait — et c'est la première fois que les données de
    // démonstration portent un `blurHash` du tout. Les jaquettes, elles, n'en ont toujours pas
    // (écart inscrit) : leur placeholder est un aplat, jamais le dégradé du bloc `9b`.

    extension DemoCatalog {

        /// Une proportion de galerie, et pourquoi elle est là.
        struct GallerySample {
            let width: Int
            let height: Int
            /// Ce que l'échantillon exerce. Sert de légende, donc visible à l'écran.
            let label: String
        }

        /// Les sept proportions, dont trois dégénérées au sens de la maçonnerie.
        ///
        /// Le §6 du handoff annonce une galerie où « les ratios se mélangent réellement (2:3,
        /// carré, 16:9) » ; le relevé de la planche 4 note comme écart que ses propres
        /// échantillons sont **tous** des affiches 2:3, donc que « le comportement de la
        /// maçonnerie avec des ratios mixtes n'est pas démontré ». Il l'est ici.
        static let gallerySamples: [GallerySample] = [
            GallerySample(width: 1_260, height: 540, label: "Panoramique 21:9"),
            GallerySample(width: 540, height: 1_260, label: "Bandeau vertical 9:21"),
            GallerySample(width: 800, height: 800, label: "Carré"),
            GallerySample(width: 600, height: 900, label: "Affiche 2:3"),
            GallerySample(width: 960, height: 540, label: "Photo de plateau 16:9"),
            GallerySample(width: 600, height: 800, label: "Jaquette 3:4"),
            GallerySample(width: 900, height: 600, label: "Scan 3:2")
        ]

        /// Combien de médias sans propriétaire. Ils n'existent que pour la source « orphelin ».
        static let orphanCount = 12

        /// Le préfixe de somme de contrôle qui rend un média de démonstration reconnaissable.
        ///
        /// **C'est ce qui rend un orphelin supprimable.** `clear` retrouve les jaquettes par le
        /// genre marqueur, en descendant titre → pièce jointe → média. Un orphelin n'a par
        /// définition aucun chemin de ce genre : sans marque sur le média lui-même, « Vider les
        /// données de démonstration » l'aurait laissé en place, et la galerie aurait gardé
        /// douze images que plus rien ne rattache à quoi que ce soit.
        static let orphanChecksumPrefix = "demo-orphan-"

        // MARK: Génération

        /// Les images de galerie d'un titre : de zéro à quatre.
        ///
        /// **Zéro est un cas volontaire**, pas un trou : la fiche doit montrer ce qu'elle fait
        /// d'un titre sans galerie, et l'état vide de sa section n'a pas d'autre occasion
        /// d'apparaître. Mais c'est le cas **minoritaire** — c'est tout le sujet de la règle.
        static func attachGallery(
            to title: Title, in context: ModelContext, using generator: inout SeededGenerator
        ) {
            let count = generator.next(upTo: 5)
            for order in 0..<count {
                attach(
                    sampleAt: generator.next(upTo: gallerySamples.count),
                    order: order,
                    in: context,
                    using: &generator
                ) { $0.title = title }
            }
        }

        /// Une image sur une personne sur trois.
        ///
        /// **Ce ne sont pas des portraits**, et la distinction compte : le §11 du handoff dit
        /// « portraits de personnes : aucun », et `PersonTile` doit continuer de rendre son
        /// cercle vide. Ce sont des images de **galerie** rattachées à une personne — une photo
        /// de tournage, une couverture de magazine — c'est-à-dire ce que la source « personne »
        /// du filtre désigne. Sans elles, cette branche n'aurait aucun média à trouver.
        static func attachGallery(
            to people: [Person], in context: ModelContext, using generator: inout SeededGenerator
        ) {
            for person in people where generator.next(upTo: 3) == 0 {
                attach(
                    sampleAt: generator.next(upTo: gallerySamples.count),
                    order: 0,
                    in: context,
                    using: &generator
                ) { $0.person = person }
            }
        }

        /// Deux images par collection : de quoi voir la source « collection » filtrer.
        static func attachGallery(
            to collections: [TitleCollection],
            in context: ModelContext,
            using generator: inout SeededGenerator
        ) {
            for collection in collections {
                for order in 0..<2 {
                    attach(
                        sampleAt: generator.next(upTo: gallerySamples.count),
                        order: order,
                        in: context,
                        using: &generator
                    ) { $0.collection = collection }
                }
            }
        }

        /// Les médias sans propriétaire : importés puis détachés, ou restés d'une suppression.
        ///
        /// **Le dernier n'a pas de dimensions, et c'est exprès.** `MediaAsset.pixelWidth` et
        /// `pixelHeight` valent 0 par défaut — le schéma fermé l'exige — donc un média importé
        /// avant que ses dimensions soient lues arrive dans la galerie en 0/0, c'est-à-dire une
        /// proportion `nan`. C'est le repli de `MasonryColumns` qui le rattrape, et sans un
        /// échantillon qui l'emprunte, ce repli serait du code que rien n'exerce.
        static func makeOrphans(in context: ModelContext, using generator: inout SeededGenerator) {
            for index in 0..<orphanCount {
                let sample = gallerySamples[index % gallerySamples.count]
                guard
                    let asset = makeAsset(
                        sample: sample, seed: generator.next(upTo: 360), in: context)
                else { continue }

                asset.checksum = "\(orphanChecksumPrefix)\(index)"
                if index == orphanCount - 1 {
                    asset.pixelWidth = 0
                    asset.pixelHeight = 0
                }
            }
        }

        // MARK: Fabriques

        /// Crée le média **et** sa pièce jointe, le propriétaire étant posé par l'appelant.
        ///
        /// `assignOwner` plutôt que trois surcharges : l'invariante `hasExactlyOneOwner` exige
        /// qu'exactement un des trois soit renseigné, et une clôture rend impossible d'en
        /// oublier un ou d'en poser deux — l'appelant écrit la seule ligne qui varie.
        private static func attach(
            sampleAt index: Int,
            order: Int,
            in context: ModelContext,
            using generator: inout SeededGenerator,
            assignOwner: (MediaAttachment) -> Void
        ) {
            let sample = gallerySamples[index]
            guard
                let asset = makeAsset(sample: sample, seed: generator.next(upTo: 360), in: context)
            else { return }

            let attachment = MediaAttachment(slot: .gallery, orderIndex: order)
            attachment.asset = asset
            assignOwner(attachment)
            context.insert(attachment)
        }

        /// Un média dessiné puis **ingéré**, donc avec ses vraies dimensions et son `blurHash`.
        private static func makeAsset(
            sample: GallerySample, seed: Int, in context: ModelContext
        ) -> MediaAsset? {
            guard
                let png = SampleArtwork.png(
                    for: sample.label, seed: seed,
                    size: (width: sample.width, height: sample.height)),
                let ingested = try? MediaIngestor().ingest(data: png)
            else { return nil }

            let asset = MediaAsset()
            asset.data = ingested.data
            asset.mimeType = ingested.mimeType
            asset.pixelWidth = ingested.pixelWidth
            asset.pixelHeight = ingested.pixelHeight
            asset.byteSize = ingested.byteSize
            asset.blurHash = ingested.blurHash
            asset.checksum = ingested.checksum
            context.insert(asset)
            return asset
        }

        // MARK: Suppression

        /// Les médias de démonstration qu'aucun titre ne mène à supprimer.
        ///
        /// Deux populations : les orphelins, reconnus à leur somme de contrôle, et les images
        /// rattachées à une personne ou à une collection. Pour ces dernières, la suppression de
        /// l'entité **cascade la pièce jointe mais pas le média** — la règle de cascade va du
        /// média vers ses pièces jointes, pas l'inverse. Sans ce balayage, chaque « Vider »
        /// laisserait derrière lui autant de médias devenus orphelins pour de bon.
        static func clearGalleryAssets(
            of people: [Person], collections: [TitleCollection], in context: ModelContext
        ) throws {
            let attached =
                people.flatMap { $0.attachments ?? [] }
                + collections.flatMap { $0.attachments ?? [] }

            for attachment in attached {
                if let asset = attachment.asset { context.delete(asset) }
                context.delete(attachment)
            }

            for asset in try context.fetch(FetchDescriptor<MediaAsset>())
            where asset.checksum.hasPrefix(orphanChecksumPrefix) {
                context.delete(asset)
            }
        }
    }

#endif
