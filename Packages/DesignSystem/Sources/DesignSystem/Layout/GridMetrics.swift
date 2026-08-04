import SwiftUI

// MARK: - I4 · Le compte de colonnes
//
// **Une seule règle, et elle est arrêtée** — addendum 2, bloc `13c` :
//
// > Le nombre de colonnes n'est pas un réglage : la largeur de carte est fixe par le
// > cran de la matrice, la grille prend ce qui rentre. À `poster.l`, 393 px donnent
// > 2 colonnes et 834 px en donnent 4, conformément au bloc 10i.
//
// D'où la forme de ce fichier : le compte est une **fonction**, jamais une constante.
// `Breakpoint` portait une colonne « Colonnes » transcrite du tableau §4.6 ; `I4` l'a
// retirée. Elle n'avait aucun lecteur, et elle contredisait ce calcul à certaines
// largeurs — une constante morte qui contredit le code vivant finit par gagner, parce
// que le prochain lecteur la prend pour la référence et « corrige » le calcul.
//
// Le tableau du §4.6 garde son rôle : une référence indicative, ce qu'il dit être.
// Le contrôle qu'on peut réellement exercer sur lui est celui des deux largeurs que
// l'addendum a **rendues pour de vrai**, et ce sont elles que les tests assènent.
//
// Ce même compte sert le masonry de la galerie, que `I3` a renvoyé ici explicitement :
// la vignette ne sait pas dans quoi elle est posée, et le compte de colonnes n'est pas
// une propriété de la vignette.

public enum GridMetrics {

    /// Le nombre de colonnes qui tiennent dans une largeur utile, à largeur de carte
    /// constante.
    ///
    /// `n` colonnes occupent `n × carte + (n - 1) × gouttière`. On cherche le plus grand
    /// `n` qui tient, donc `n = ⌊(utile + gouttière) / (carte + gouttière)⌋`.
    ///
    /// Jamais moins d'une colonne : une fenêtre plus étroite qu'une carte rogne la carte,
    /// elle ne rend pas une grille vide.
    public static func columnCount(
        available: CGFloat,
        cardWidth: CGFloat,
        gutter: CGFloat
    ) -> Int {
        guard cardWidth > 0, available > 0 else { return 1 }
        let pitch = cardWidth + gutter
        guard pitch > 0 else { return 1 }
        return max(1, Int((available + gutter) / pitch))
    }

    /// La largeur utile d'une fenêtre : sa largeur, moins les deux marges de son cran.
    public static func contentWidth(window: CGFloat) -> CGFloat {
        max(0, window - 2 * Breakpoint.forWidth(window).screenMargin)
    }

    /// Le nombre de colonnes d'une fenêtre, pour un cran d'affiche et une densité.
    ///
    /// C'est le chemin normal : il résout la marge et la gouttière depuis le point de
    /// rupture, de sorte qu'aucun appelant n'ait à les connaître.
    public static func columnCount(
        window: CGFloat,
        cardWidth: CGFloat,
        density: Density
    ) -> Int {
        columnCount(
            available: contentWidth(window: window),
            cardWidth: cardWidth,
            gutter: Breakpoint.forWidth(window).gridGutter(density))
    }
}
