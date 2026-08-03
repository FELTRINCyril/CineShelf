import CoreGraphics
import Foundation

/// Toute l'arithmétique du recadrage : du geste vers `MediaCrop`, et de `MediaCrop`
/// vers ce que l'affichage doit montrer.
///
/// ## La sémantique de `(x, y, zoom)`, posée ici parce qu'elle ne l'était nulle part
///
/// `docs/02` §2.4 dit que les 21 colonnes de la v1 deviennent `(asset, context, x, y,
/// zoom)` et donne les bornes — 0–100 pour la position, 50–400 pour le zoom — mais
/// **aucune référence ne dit ce que ces nombres signifient**. Sans définition, deux
/// lectures plausibles donnent des images différentes, et `L13` importerait de travers
/// sans que rien ne le signale. La voici, arrêtée :
///
/// - **`zoom` est un facteur appliqué à l'échelle « couvrir »**, celle-ci étant
///   recalculée **pour le cadre visé**. `zoom = 100` veut donc dire « juste ce qu'il
///   faut pour remplir ce cadre-ci », quel que soit son ratio.
/// - **`x` et `y` sont des pourcentages du jeu restant**, pas des coordonnées d'un
///   point de l'image. `x = 0` colle le bord gauche, `x = 100` le bord droit,
///   `x = 50` centre — pour n'importe quel ratio.
///
/// C'est la sémantique de `object-position` en CSS sur une image en `object-fit:
/// cover`, ce que la version web faisait presque certainement : ses colonnes étaient
/// des pourcentages avec 50 pour défaut.
///
/// ## Ce que cette sémantique garantit, et qui répond à la question du stockage
///
/// **Un seul `MediaCrop` par contexte suffit à servir 2:3 et 16:9.** Ce n'est pas une
/// commodité, c'est une propriété du calcul : le rect visible est toujours entièrement
/// contenu dans l'image source, pour n'importe quel ratio cible.
///
/// La démonstration tient en une ligne. L'échelle « couvrir » vaut
/// `max(fw/sw, fh/sh)` ; la largeur visible en pixels source vaut donc
/// `fw / couvrir ≤ fw / (fw/sw) = sw`, et de même en hauteur. Le rect visible ne
/// déborde jamais, le jeu restant n'est jamais négatif, et une position exprimée en
/// pourcentage de ce jeu est **toujours valide par construction**.
///
/// Autrement dit : il n'y a rien à stocker en plus pour le second ratio, et il n'y
/// aurait rien à corriger si un troisième apparaissait. `CropGeometryTests` le vérifie
/// sur les deux ratios de la matrice et sur des cas extrêmes.
///
/// ## La seule valeur stockable qui ne soit pas applicable telle quelle
///
/// `zoom < 100` laisserait du vide dans le cadre. La borne de stockage descend pourtant
/// à 50, parce que c'est la plage du curseur de la v1. L'application **relève donc à
/// 100** : `docs/PROMPTS.md` pose qu'un hero ne doit jamais laisser de bandes noires,
/// et la règle vaut pour tous les cadres. La valeur stockée n'est pas modifiée pour
/// autant — on ne réécrit pas la donnée de l'utilisateur au premier affichage.
///
/// `L13` doit compter les recadrages importés dont le zoom est inférieur à 100 : c'est
/// le seul endroit où la v1 et le natif peuvent diverger visiblement, et ça se voit
/// dans un rapport, pas à l'œil sur 5 000 titres.
public enum CropGeometry {

    /// Le zoom minimal applicable : en deçà, le cadre ne serait pas rempli.
    public static let minimumApplicableZoom: Double = 100
    /// Les bornes de stockage, reprises de la v1.
    public static let storableZoom: ClosedRange<Double> = 50...400

    /// L'échelle qui fait tout juste couvrir le cadre.
    ///
    /// - Returns: `0` si l'une des dimensions est nulle — un média sans dimensions
    ///   connues n'a pas de géométrie, et rendre `0` laisse l'appelant décider plutôt
    ///   que de propager un `NaN` ou un `infinity` dans une mise en page.
    public static func coverScale(source: CGSize, frame: CGSize) -> Double {
        guard source.width > 0, source.height > 0, frame.width > 0, frame.height > 0 else {
            return 0
        }
        return max(frame.width / source.width, frame.height / source.height)
    }

    /// Le rect de l'image source à afficher dans ce cadre.
    ///
    /// C'est ce que la vue consomme, et ce que `L6` réutilisera pour ses tuiles de
    /// mosaïque : une tuile est un cadre comme un autre.
    ///
    /// > **Le même calcul existe une seconde fois**, en points cette fois, dans
    /// > `MediaThumbnail.cropped`. Les deux décrivent la même géométrie vue de deux
    /// > côtés, et leur accord est **vérifié** par
    /// > `CropRenderingAgreementTests.bothImplementationsAgree`, qui balaie positions,
    /// > zooms et ratios. Modifier l'un sans l'autre casse ce test — c'est le but : une
    /// > divergence se verrait sinon à l'écran, tard, et sans dire laquelle est fausse.
    ///
    /// - Returns: `.zero` si la source ou le cadre n'a pas de dimensions exploitables.
    public static func sourceRect(_ crop: CropValues, source: CGSize, frame: CGSize) -> CGRect {
        let cover = coverScale(source: source, frame: frame)
        guard cover > 0 else { return .zero }

        let scale = cover * applicableZoom(crop.zoom) / 100
        let visible = CGSize(width: frame.width / scale, height: frame.height / scale)

        // Le jeu restant ne peut pas être négatif — c'est la propriété démontrée
        // plus haut. `max(0, …)` protège du seul cas qui l'entamerait : une erreur
        // d'arrondi en virgule flottante sur une source qui matche exactement le cadre.
        let slack = CGSize(
            width: max(0, source.width - visible.width),
            height: max(0, source.height - visible.height)
        )
        let position = clamped(crop)

        return CGRect(
            x: slack.width * position.x / 100,
            y: slack.height * position.y / 100,
            width: visible.width,
            height: visible.height
        )
    }

    /// Le recadrage obtenu après un geste.
    ///
    /// **Le zoom s'applique avant le déplacement**, et l'ordre compte : un pincement
    /// change l'échelle, donc combien de pixels source vaut un point à l'écran. Les
    /// traiter dans l'autre sens ferait dériver le doigt de l'image pendant un geste
    /// combiné, ce qui est exactement ce qu'on remarque.
    ///
    /// - Parameters:
    ///   - translation: le déplacement du **doigt**, en points du cadre. Tirer vers la
    ///     droite fait glisser l'image vers la droite, donc découvre sa partie gauche :
    ///     la fenêtre visible recule, d'où le signe négatif dans le calcul.
    ///   - magnification: le facteur de pincement, `1` pour aucun changement.
    ///   - crop: le recadrage de départ.
    ///   - source: les dimensions de l'image source, en pixels.
    ///   - frame: les dimensions du cadre, en points.
    /// - Returns: un recadrage toujours dans les bornes.
    public static func crop(
        after translation: CGSize,
        magnifying magnification: Double,
        from crop: CropValues,
        source: CGSize,
        frame: CGSize
    ) -> CropValues {
        let zoom = clampedZoom(crop.zoom * magnification)
        let cover = coverScale(source: source, frame: frame)
        guard cover > 0 else { return CropValues(x: crop.x, y: crop.y, zoom: zoom) }

        let scale = cover * max(zoom, minimumApplicableZoom) / 100
        let visible = CGSize(width: frame.width / scale, height: frame.height / scale)
        let slack = CGSize(
            width: max(0, source.width - visible.width),
            height: max(0, source.height - visible.height)
        )

        return CropValues(
            x: shifted(crop.x, by: -translation.width / scale, slack: slack.width),
            y: shifted(crop.y, by: -translation.height / scale, slack: slack.height),
            zoom: zoom
        )
    }

    /// Déplace une position exprimée en pourcentage, d'un décalage en pixels source.
    ///
    /// Un jeu nul veut dire que cette dimension est déjà exactement remplie : aucune
    /// position n'y change quoi que ce soit, et diviser par zéro donnerait un `NaN` qui
    /// se propagerait jusqu'à la mise en page. On rend la valeur telle quelle.
    private static func shifted(_ percent: Double, by offset: Double, slack: Double) -> Double {
        guard slack > 0 else { return percent }
        return min(100, max(0, percent + 100 * offset / slack))
    }

    // MARK: Bornes

    /// Le recadrage ramené dans ses bornes de stockage.
    public static func clamped(_ crop: CropValues) -> CropValues {
        CropValues(
            x: min(100, max(0, crop.x)),
            y: min(100, max(0, crop.y)),
            zoom: clampedZoom(crop.zoom)
        )
    }

    public static func clampedZoom(_ zoom: Double) -> Double {
        min(storableZoom.upperBound, max(storableZoom.lowerBound, zoom))
    }

    /// Le zoom réellement applicable : jamais moins que « couvrir ».
    ///
    /// Distinct de `clampedZoom(_:)` à dessein. L'un borne ce qu'on **stocke** (plage
    /// de la v1, 50–400), l'autre ce qu'on **applique** (jamais de vide dans le cadre).
    /// Les confondre reviendrait soit à réécrire la donnée de l'utilisateur au premier
    /// affichage, soit à laisser des bandes noires.
    public static func applicableZoom(_ zoom: Double) -> Double {
        max(minimumApplicableZoom, clampedZoom(zoom))
    }

    // MARK: Consommation par une vue

    /// La position du recadrage exprimée en coordonnées unitaires.
    ///
    /// C'est la forme qu'attend un alignement SwiftUI : une image en `scaledToFill`
    /// dans un cadre aligné sur ce point reproduit exactement la sémantique
    /// « pourcentage du jeu restant », sans calcul de rect. C'est le chemin le moins
    /// intrusif pour appliquer un recadrage à un composant existant.
    public static func unitPoint(_ crop: CropValues) -> CGPoint {
        let position = clamped(crop)
        return CGPoint(x: position.x / 100, y: position.y / 100)
    }

    /// Le facteur d'échelle à appliquer par-dessus un `scaledToFill`.
    ///
    /// `scaledToFill` réalise déjà l'échelle « couvrir » ; il ne reste que le zoom.
    public static func fillScale(_ crop: CropValues) -> Double {
        applicableZoom(crop.zoom) / 100
    }
}
