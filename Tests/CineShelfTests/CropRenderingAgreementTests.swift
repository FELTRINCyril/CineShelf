import CineShelfCore
import CoreGraphics
import Foundation
import SwiftUI
import Testing

// L'accord entre les **deux** implémentations de la même géométrie.
//
// `L4` a laissé le calcul écrit deux fois, et c'était assumé :
//
//   - `CropGeometry.sourceRect` raisonne en **pixels de l'image source** — c'est ce que
//     consomment `L6` (tuiles de mosaïque) et tout ce qui découpe une image ;
//   - `MediaThumbnail.cropped` raisonne en **points à l'écran** — il pose l'image à sa
//     taille « couvrir », la multiplie par le zoom, et la décale du jeu restant.
//
// Les deux décrivent la même chose vue de deux côtés, et une note à chaque endroit
// disait de les garder d'accord. **Une note n'empêche pas une divergence** : elle se
// verrait à l'écran, tard, sur un cas particulier, et personne ne saurait laquelle des
// deux est fausse.
//
// Ce fichier réimplémente le calcul de la vue — les quatre lignes de
// `MediaThumbnail.cropped`, recopiées à l'identique — et vérifie qu'il désigne le même
// morceau d'image que `sourceRect`, sur un balayage de positions, de zooms et de
// ratios. Si l'un des deux change sans l'autre, ça casse ici.
//
// La correspondance se lit ainsi : le décalage appliqué à l'image en points, ramené à
// l'échelle, **est** l'origine du rect source en pixels.

@MainActor
struct CropRenderingAgreementTests {

    /// Le calcul de `MediaThumbnail.cropped`, à l'identique.
    ///
    /// Recopié plutôt qu'appelé : le vrai vit dans une `View`, qu'aucune cible de test
    /// ne monte. C'est justement pourquoi il faut l'attacher à quelque chose.
    private func viewSide(
        crop: CropValues, sourceAspect: Double, box: CGSize
    ) -> (rendered: CGSize, offset: CGSize) {
        let zoom = CropGeometry.fillScale(crop)
        let cover = max(box.width / sourceAspect, box.height)
        let rendered = CGSize(width: cover * sourceAspect * zoom, height: cover * zoom)
        let slack = CGSize(
            width: max(0, rendered.width - box.width),
            height: max(0, rendered.height - box.height)
        )
        let focus = CropGeometry.unitPoint(crop)
        return (rendered, CGSize(width: -slack.width * focus.x, height: -slack.height * focus.y))
    }

    @Test("Les deux implémentations désignent le même morceau d'image")
    func bothImplementationsAgree() {
        let sources: [CGSize] = [
            CGSize(width: 1000, height: 1500),  // affiche 2:3
            CGSize(width: 1920, height: 1080),  // fond 16:9
            CGSize(width: 800, height: 800),  // carré
            CGSize(width: 300, height: 2000)  // très vertical
        ]
        let boxes: [CGSize] = [
            CGSize(width: 200, height: 300),  // carte portrait
            CGSize(width: 320, height: 180),  // carte paysage
            CGSize(width: 120, height: 120)  // vignette carrée
        ]

        for source in sources {
            let sourceAspect = source.width / source.height
            for box in boxes {
                for x in stride(from: 0.0, through: 100, by: 20) {
                    for y in stride(from: 0.0, through: 100, by: 20) {
                        for zoom in [100.0, 175, 300] {
                            let crop = CropValues(x: x, y: y, zoom: zoom)
                            let rect = CropGeometry.sourceRect(crop, source: source, frame: box)
                            let view = viewSide(crop: crop, sourceAspect: sourceAspect, box: box)

                            // L'échelle qu'applique la vue : la taille rendue rapportée
                            // aux pixels de la source.
                            let scale = view.rendered.width / source.width
                            let originFromView = CGPoint(
                                x: -view.offset.width / scale,
                                y: -view.offset.height / scale
                            )
                            let visibleFromView = CGSize(
                                width: box.width / scale,
                                height: box.height / scale
                            )

                            let what = "source \(source), cadre \(box), x \(x), y \(y), zoom \(zoom)"
                            #expect(
                                abs(originFromView.x - rect.origin.x) < 0.01,
                                "Origine X divergente — \(what)")
                            #expect(
                                abs(originFromView.y - rect.origin.y) < 0.01,
                                "Origine Y divergente — \(what)")
                            #expect(
                                abs(visibleFromView.width - rect.width) < 0.01,
                                "Largeur visible divergente — \(what)")
                            #expect(
                                abs(visibleFromView.height - rect.height) < 0.01,
                                "Hauteur visible divergente — \(what)")
                        }
                    }
                }
            }
        }
    }

    @Test("La vue ne laisse jamais de vide dans son cadre")
    func theViewNeverLeavesAGap() {
        // La propriété que `CropGeometry` garantit côté pixels, vérifiée côté points :
        // l'image rendue couvre toujours le cadre, dans les deux dimensions.
        for sourceAspect in [2.0 / 3.0, 16.0 / 9.0, 1.0, 0.15, 8.0] {
            for box in [CGSize(width: 200, height: 300), CGSize(width: 320, height: 180)] {
                for zoom in [50.0, 100, 250] {
                    let view = viewSide(
                        crop: CropValues(x: 50, y: 50, zoom: zoom),
                        sourceAspect: sourceAspect, box: box)

                    #expect(
                        view.rendered.width >= box.width - 0.01,
                        "Bande verticale — ratio \(sourceAspect), cadre \(box), zoom \(zoom)")
                    #expect(
                        view.rendered.height >= box.height - 0.01,
                        "Bande horizontale — ratio \(sourceAspect), cadre \(box), zoom \(zoom)")
                }
            }
        }
    }

    @Test("Un zoom stocké sous 100 est relevé des deux côtés")
    func lowZoomIsRaisedOnBothSides() {
        // Le relèvement vit dans `CropGeometry.applicableZoom`, et les deux chemins y
        // passent — la vue par `fillScale`, le rect par `sourceRect`. S'ils divergeaient
        // là-dessus, la vue laisserait des bandes que le calcul dit impossibles.
        let source = CGSize(width: 1000, height: 1500)
        let box = CGSize(width: 320, height: 180)

        let atFifty = CropGeometry.sourceRect(
            CropValues(x: 50, y: 50, zoom: 50), source: source, frame: box)
        let atHundred = CropGeometry.sourceRect(
            CropValues(x: 50, y: 50, zoom: 100), source: source, frame: box)
        #expect(atFifty == atHundred)

        let viewAtFifty = viewSide(
            crop: CropValues(x: 50, y: 50, zoom: 50),
            sourceAspect: source.width / source.height, box: box)
        let viewAtHundred = viewSide(
            crop: CropValues(x: 50, y: 50, zoom: 100),
            sourceAspect: source.width / source.height, box: box)
        #expect(viewAtFifty.rendered == viewAtHundred.rendered)
    }
}
