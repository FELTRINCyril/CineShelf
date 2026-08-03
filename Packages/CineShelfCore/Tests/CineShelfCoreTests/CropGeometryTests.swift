import CoreGraphics
import Foundation
import Testing

@testable import CineShelfCore

// Les mathématiques du recadrage.
//
// La question qui commandait cette tâche : **un seul `MediaCrop` par contexte suffit-il
// à servir 2:3 et 16:9**, ou faut-il stocker séparément ? La matrice du design impose
// les deux ratios pour les mêmes contextes, et l'éditeur en montre un aperçu simultané.
//
// La réponse est oui, et elle se démontre plutôt qu'elle ne se lit : avec une position
// exprimée en pourcentage du jeu restant et un zoom relatif à l'échelle « couvrir »
// recalculée pour le cadre visé, le rect visible est **toujours** contenu dans la
// source, quel que soit le ratio. Les tests de la section « Un recadrage pour tous les
// ratios » sont cette démonstration.

struct CropGeometryTests {

    /// Une affiche 2:3 en 1000×1500, et un fond 16:9 en 1920×1080.
    private let poster = CGSize(width: 1000, height: 1500)
    private let backdrop = CGSize(width: 1920, height: 1080)

    /// Les deux cadres de la matrice `layout × size`.
    private let portraitFrame = CGSize(width: 200, height: 300)
    private let landscapeFrame = CGSize(width: 320, height: 180)

    private func isInside(_ rect: CGRect, _ source: CGSize) -> Bool {
        rect.minX >= -0.001 && rect.minY >= -0.001
            && rect.maxX <= source.width + 0.001
            && rect.maxY <= source.height + 0.001
    }

    // MARK: Un recadrage pour tous les ratios

    @Test("Le rect visible ne déborde jamais de la source, quel que soit le ratio")
    func oneCropServesEveryAspectRatio() {
        // La démonstration, sur les deux ratios de la matrice et deux sources de
        // formes opposées, pour toutes les positions et tous les zooms applicables.
        let sources = [poster, backdrop, CGSize(width: 400, height: 400)]
        let frames = [
            portraitFrame, landscapeFrame,
            CGSize(width: 100, height: 100), CGSize(width: 1000, height: 120)
        ]

        for source in sources {
            for frame in frames {
                for x in stride(from: 0.0, through: 100, by: 25) {
                    for y in stride(from: 0.0, through: 100, by: 25) {
                        for zoom in [100.0, 150, 250, 400] {
                            let rect = CropGeometry.sourceRect(
                                CropValues(x: x, y: y, zoom: zoom), source: source, frame: frame)
                            let context =
                                "source \(source), cadre \(frame), x \(x), y \(y), zoom \(zoom)"
                            #expect(isInside(rect, source), "Débordement : \(context) → \(rect)")
                            #expect(rect.width > 0 && rect.height > 0)
                        }
                    }
                }
            }
        }
    }

    @Test("Le rect visible a toujours le ratio du cadre")
    func visibleRectMatchesFrameAspect() {
        // C'est ce qui garantit l'absence de bandes : le rect découpé dans la source a
        // exactement la forme du cadre, donc il le remplit sans déformation.
        for frame in [portraitFrame, landscapeFrame] {
            let rect = CropGeometry.sourceRect(
                CropValues(x: 30, y: 70, zoom: 140), source: poster, frame: frame)
            let frameAspect = frame.width / frame.height
            let rectAspect = rect.width / rect.height
            #expect(abs(rectAspect - frameAspect) < 0.001, "Cadre \(frame) → rect \(rect)")
        }
    }

    @Test("Le même recadrage donne deux cadrages cohérents en 2:3 et en 16:9")
    func theSameCropAnchorsConsistently() {
        // Le cas concret de l'éditeur : un aperçu simultané des deux ratios, à partir
        // d'une seule valeur stockée. Centré reste centré, collé à gauche reste collé à
        // gauche — c'est ce qui rend l'aperçu simultané lisible.
        let centered = CropValues(x: 50, y: 50, zoom: 100)
        for frame in [portraitFrame, landscapeFrame] {
            let rect = CropGeometry.sourceRect(centered, source: backdrop, frame: frame)
            #expect(abs(rect.midX - backdrop.width / 2) < 0.001, "Centré en X, cadre \(frame)")
            #expect(abs(rect.midY - backdrop.height / 2) < 0.001, "Centré en Y, cadre \(frame)")
        }

        let leftEdge = CropValues(x: 0, y: 0, zoom: 100)
        for frame in [portraitFrame, landscapeFrame] {
            let rect = CropGeometry.sourceRect(leftEdge, source: backdrop, frame: frame)
            #expect(abs(rect.minX) < 0.001, "Collé à gauche, cadre \(frame)")
            #expect(abs(rect.minY) < 0.001, "Collé en haut, cadre \(frame)")
        }
    }

    @Test("Une source plus étroite que le cadre est quand même remplie")
    func narrowSourceStillFillsTheFrame() {
        // Le cas limite cité par la fiche : une affiche très verticale dans un cadre
        // très horizontal. L'échelle « couvrir » est alors dictée par la largeur, et la
        // hauteur visible ne représente qu'une fraction de la source.
        let verySlim = CGSize(width: 300, height: 2000)
        let veryWide = CGSize(width: 1000, height: 120)

        let rect = CropGeometry.sourceRect(.neutral, source: verySlim, frame: veryWide)
        #expect(isInside(rect, verySlim))
        #expect(abs(rect.width - verySlim.width) < 0.001, "Toute la largeur est utilisée")
        #expect(rect.height < verySlim.height, "Une tranche seulement, en hauteur")
    }

    // MARK: Zoom

    @Test("Un zoom inférieur à 100 est relevé à l'application, pas dans la donnée")
    func lowZoomIsRaisedOnlyWhenApplied() {
        // La v1 laissait descendre à 50, ce qui laisserait du vide. On relève à
        // l'affichage sans réécrire la valeur stockée : réécrire la donnée de
        // l'utilisateur au premier affichage serait pire que le défaut qu'on corrige.
        #expect(CropGeometry.applicableZoom(50) == 100)
        #expect(CropGeometry.clampedZoom(50) == 50, "La valeur stockable reste telle quelle")

        let rect = CropGeometry.sourceRect(
            CropValues(x: 50, y: 50, zoom: 50), source: poster, frame: portraitFrame)
        #expect(isInside(rect, poster), "Même à zoom 50, aucun vide")
    }

    @Test("Zoomer réduit la fenêtre visible")
    func zoomingShrinksTheWindow() {
        let wide = CropGeometry.sourceRect(
            CropValues(x: 50, y: 50, zoom: 100), source: poster, frame: portraitFrame)
        let tight = CropGeometry.sourceRect(
            CropValues(x: 50, y: 50, zoom: 200), source: poster, frame: portraitFrame)

        #expect(tight.width < wide.width)
        #expect(abs(tight.width * 2 - wide.width) < 0.001, "Zoom 200 % = moitié de la largeur")
    }

    @Test("Le zoom est borné des deux côtés")
    func zoomIsBounded() {
        #expect(CropGeometry.clampedZoom(10) == 50)
        #expect(CropGeometry.clampedZoom(10_000) == 400)
    }

    // MARK: Le geste, dans les deux sens

    @Test("Tirer vers la droite découvre la partie gauche de l'image")
    func draggingRightRevealsTheLeft() {
        // Le signe, qui est la seule chose qu'on peut vraiment se tromper ici : le
        // doigt tire l'image vers la droite, donc la fenêtre visible recule vers la
        // gauche, donc `x` diminue.
        let start = CropValues(x: 50, y: 50, zoom: 200)
        let moved = CropGeometry.crop(
            after: CGSize(width: 20, height: 0), magnifying: 1,
            from: start, source: poster, frame: portraitFrame)

        #expect(moved.x < start.x)
        #expect(moved.y == start.y)
        #expect(moved.zoom == start.zoom)
    }

    @Test("Un geste ne peut pas sortir des bornes")
    func gesturesCannotEscapeTheBounds() {
        // La correction est dans la logique et non dans la vue : un déplacement énorme
        // s'arrête au bord, il ne produit pas une valeur invalide qu'une vue devrait
        // rattraper.
        let start = CropValues(x: 50, y: 50, zoom: 200)

        let farLeft = CropGeometry.crop(
            after: CGSize(width: 100_000, height: 100_000), magnifying: 1,
            from: start, source: poster, frame: portraitFrame)
        #expect(farLeft.x == 0)
        #expect(farLeft.y == 0)

        let farRight = CropGeometry.crop(
            after: CGSize(width: -100_000, height: -100_000), magnifying: 1,
            from: start, source: poster, frame: portraitFrame)
        #expect(farRight.x == 100)
        #expect(farRight.y == 100)
    }

    @Test("Un aller-retour de geste revient au point de départ")
    func gesturesRoundTrip() {
        // La conversion « dans les deux sens » de la fiche : ce qu'un geste produit doit
        // pouvoir être défait par le geste inverse, sans dérive.
        let start = CropValues(x: 40, y: 60, zoom: 180)
        let there = CropGeometry.crop(
            after: CGSize(width: 25, height: -15), magnifying: 1,
            from: start, source: poster, frame: portraitFrame)
        let back = CropGeometry.crop(
            after: CGSize(width: -25, height: 15), magnifying: 1,
            from: there, source: poster, frame: portraitFrame)

        #expect(abs(back.x - start.x) < 0.001)
        #expect(abs(back.y - start.y) < 0.001)
    }

    @Test("Un pincement combiné à un déplacement applique le zoom d'abord")
    func magnificationAppliesBeforeTranslation() {
        // L'ordre est observable : à zoom plus fort, un même déplacement en points
        // couvre moins de pixels source, donc décale moins en pourcentage.
        let start = CropValues(x: 50, y: 50, zoom: 100)
        let zoomedThenMoved = CropGeometry.crop(
            after: CGSize(width: 20, height: 0), magnifying: 3,
            from: start, source: poster, frame: portraitFrame)
        let movedAtSameZoom = CropGeometry.crop(
            after: CGSize(width: 20, height: 0), magnifying: 1,
            from: CropValues(x: 50, y: 50, zoom: 300), source: poster, frame: portraitFrame)

        #expect(abs(zoomedThenMoved.x - movedAtSameZoom.x) < 0.001)
    }

    @Test("Une dimension sans jeu ignore le déplacement au lieu de produire un NaN")
    func noSlackMeansNoMovement() {
        // Une source exactement au ratio du cadre n'a aucun jeu : diviser par ce jeu
        // donnerait un `NaN` qui se propagerait jusqu'à la mise en page, où il est
        // beaucoup plus difficile à diagnostiquer qu'ici.
        let square = CGSize(width: 500, height: 500)
        let squareFrame = CGSize(width: 100, height: 100)
        let moved = CropGeometry.crop(
            after: CGSize(width: 50, height: 50), magnifying: 1,
            from: .neutral, source: square, frame: squareFrame)

        #expect(moved.x == 50)
        #expect(moved.y == 50)
        #expect(moved.x.isNaN == false)
    }

    // MARK: Dimensions absentes

    @Test("Une source sans dimensions ne fait pas exploser le calcul")
    func missingDimensionsAreHandled() {
        // `MediaAsset.pixelWidth` et `pixelHeight` valent 0 par défaut, et un média
        // importé de travers peut les garder. Rendre `.zero` laisse l'appelant décider ;
        // propager un `infinity` casserait la mise en page loin d'ici.
        #expect(CropGeometry.sourceRect(.neutral, source: .zero, frame: portraitFrame) == .zero)
        #expect(CropGeometry.sourceRect(.neutral, source: poster, frame: .zero) == .zero)
        #expect(CropGeometry.coverScale(source: .zero, frame: portraitFrame) == 0)
    }

    // MARK: Consommation par une vue

    @Test("La position unitaire correspond aux pourcentages")
    func unitPointMatchesPercentages() {
        #expect(CropGeometry.unitPoint(.neutral) == CGPoint(x: 0.5, y: 0.5))
        #expect(CropGeometry.unitPoint(CropValues(x: 0, y: 100, zoom: 100)) == CGPoint(x: 0, y: 1))
        // Une valeur hors bornes est ramenée avant conversion.
        #expect(CropGeometry.unitPoint(CropValues(x: -20, y: 300, zoom: 100)) == CGPoint(x: 0, y: 1))
    }

    @Test("L'échelle de remplissage ne descend jamais sous 1")
    func fillScaleNeverShrinks() {
        #expect(CropGeometry.fillScale(.neutral) == 1)
        #expect(CropGeometry.fillScale(CropValues(x: 50, y: 50, zoom: 50)) == 1)
        #expect(CropGeometry.fillScale(CropValues(x: 50, y: 50, zoom: 250)) == 2.5)
    }
}
