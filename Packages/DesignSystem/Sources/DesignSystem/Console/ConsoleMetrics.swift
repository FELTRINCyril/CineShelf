import CoreGraphics

// MARK: - I5 · Les mesures de la console
//
// **Hors des vues, comme `GridMetrics` et `MasonryColumns`.** Cinquième fois que le motif se
// répète, et la raison ne change pas : un membre de `View` est `@MainActor`, donc intestable
// depuis un test non isolé, et ces trois nombres sont ce que la console a de plus facile à
// faire diverger — la ligne, son en-tête et sa marge doivent s'accorder au pixel, sans quoi
// les colonnes du corps ne tombent plus sous celles du titre.
//
// **Relevé sur la planche 5 bloc `7a`**, et le désaccord est dans la planche elle-même :
//
//     <span style="…height:30px;flex:none;padding:0 18px;…border-bottom:1px solid …">
//
// Le rendu donne **30 pt**, et le relevé de la même planche écrit « La console est en lignes
// de **28 pt** ». Un bloc rendu contre une prose de synthèse : le bloc gagne, comme la barre
// latérale du §4.6 avait perdu contre les douze écrans qui n'en montraient aucune. Les 28 pt
// existent bien dans le rendu — c'est la hauteur de la **ligne d'en-tête**, ce qui explique
// sans doute la confusion.

/// Les mesures d'un tableau de gestion, par cran de densité.
public enum ConsoleMetrics {

    /// La hauteur d'une ligne de corps.
    ///
    /// **30 pt en dense** (bloc `7a`), **44 pt en ample** (addendum 2 bloc `13d` : « lignes de
    /// 44 puisque la densité par défaut est ample »). Ce sont les deux seules valeurs rendues,
    /// et elles viennent de deux blocs différents — donc deux plateformes, pas une
    /// interpolation.
    ///
    /// 44 n'est pas un hasard : c'est la cible tactile minimale, et c'est bien la valeur que
    /// l'addendum retient pour l'iPad. En dense, 30 pt est **sous** cette cible, ce qui est
    /// assumé par le design — la console dense « assume un usage clavier », dit le relevé.
    public static func rowHeight(_ density: Density) -> CGFloat {
        density == .dense ? 30 : Space.minHitTarget
    }

    /// La hauteur de la ligne d'en-tête. Constante, et **plus basse que la ligne** en ample.
    ///
    /// Elle ne suit pas la densité parce qu'elle ne porte pas de cible cliquable en dehors du
    /// tri, et qu'un en-tête aussi haut qu'une ligne de données se lit comme une ligne de
    /// données. Relevé à 28 pt sur le bloc `7a`.
    public static let headerHeight: CGFloat = 28

    /// La marge horizontale du tableau, en-tête et lignes confondus.
    ///
    /// **18 pt aux deux crans**, et c'est un choix de ne pas inventer : seul le bloc dense la
    /// rend. Une valeur ample déduite par proportion serait une mesure que personne n'a
    /// dessinée — l'écart est inscrit plutôt que comblé.
    public static let horizontalPadding: CGFloat = 18

    /// La vignette en tête de ligne : 16 × 24, soit une affiche 2:3 au plus petit cran utile.
    ///
    /// Elle n'est pas `PosterScale.xs` (32 pt) : la ligne fait 30 pt de haut, donc une carte de
    /// 32 pt de large en ferait 48 et déborderait. C'est le seul endroit de l'app où une image
    /// sort de l'échelle d'affiche, et c'est parce que la contrainte vient de la ligne.
    public static let thumbnailWidth: CGFloat = 16

    public static var thumbnailHeight: CGFloat { thumbnailWidth / Ratio.poster }
}
