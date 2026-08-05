import CoreGraphics
import Foundation

// MARK: - V3 · La répartition en colonnes de la maçonnerie
//
// **Le calcul est ici et pas dans la vue.** Quatrième fois que le motif se répète —
// `GridMetrics` hors d'`AdaptiveTileGrid`, `ProgressMetrics` hors de `ProgressTrack`,
// `CropGeometry` hors de l'éditeur — et la raison ne change pas : une clôture qui capture
// `self` dans une `View` déclenche un contrôle d'isolation depuis un test non isolé, et ce
// contrôle **tue le processus de test** au lieu d'échouer proprement. Le bénéfice second est
// celui qui compte ici : un calcul extrait est le seul qu'on puisse assener sur des entrées
// dégénérées.
//
// **Et les entrées dégénérées sont précisément ce qui casse une maçonnerie.** L'algorithme
// est « la colonne la plus courte d'abord », donc il additionne des hauteurs ; une hauteur
// infinie ou nulle empoisonne une colonne pour toujours :
//
// | Entrée | Hauteur à largeur 1 | Sans borne |
// |---|---|---|
// | ratio 0 (`pixelWidth` renseigné, `pixelHeight` à 0) | ∞ | la colonne n'est plus jamais choisie |
// | ratio `nan` (dimensions absentes, division 0/0) | `nan` | toute comparaison est fausse, la colonne 0 rafle tout |
// | ratio 400 (une bande de 4000 × 10) | 0,0025 | la colonne absorbe des dizaines d'éléments |
//
// Aucun de ces trois cas n'est théorique : `MediaAsset.pixelWidth` et `pixelHeight` valent
// **0 par défaut** — le schéma l'exige, toute propriété a une valeur par défaut — donc un
// média importé sans que ses dimensions soient lues arrive ici en 0/0.

/// Répartit des éléments en colonnes de hauteurs équilibrées.
public enum MasonryColumns {

    /// Les proportions acceptées, largeur / hauteur.
    ///
    /// Les bornes sont larges exprès : un 21:9 (2,33) et un 9:21 (0,43) doivent passer
    /// **exacts**, parce que ce sont de vraies images. Ce qu'on écarte est ce qui n'est pas
    /// une image — le zéro, l'infini, le non-nombre — et l'aberration à deux ordres de
    /// grandeur, qui déséquilibrerait la grille sans qu'aucun utilisateur l'ait voulu.
    public static let aspectBounds: ClosedRange<Double> = 0.05...20

    /// La proportion de repli : celle d'une affiche.
    ///
    /// Un repli et non un rejet : un média dont on ignore les dimensions doit **quand même
    /// s'afficher**. Le faire disparaître de la galerie serait une perte silencieuse, et
    /// l'utilisateur n'aurait aucun moyen de savoir que son image est là.
    public static let fallbackAspect = Double(Ratio.poster)

    /// Ramène une proportion dans les bornes, et remplace ce qui n'est pas un nombre.
    public static func clamped(aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return fallbackAspect }
        return min(max(aspect, aspectBounds.lowerBound), aspectBounds.upperBound)
    }

    /// Les index des éléments, répartis en `columnCount` colonnes.
    ///
    /// **La colonne la plus courte d'abord**, la hauteur étant mesurée à largeur de colonne
    /// unitaire : `1 / proportion`. À égalité, la colonne la plus à gauche gagne — ce qui rend
    /// la répartition déterministe, donc comparable d'une passe de rendu à l'autre. Une
    /// répartition qui changerait à ratio égal ferait sauter les images de colonne pendant
    /// qu'on les regarde.
    ///
    /// - Parameters:
    ///   - aspects: la proportion de chaque élément, dans l'ordre de la collection.
    ///   - columnCount: le nombre de colonnes. Sous 1, ramené à 1 : une fenêtre plus étroite
    ///     qu'une carte rogne la carte, elle ne rend pas une grille vide.
    /// - Returns: `columnCount` tableaux d'index, dans l'ordre d'affichage de chaque colonne.
    public static func distribute(aspects: [Double], columnCount: Int) -> [[Int]] {
        let count = max(1, columnCount)
        var columns = [[Int]](repeating: [], count: count)
        var heights = [Double](repeating: 0, count: count)

        for (index, aspect) in aspects.enumerated() {
            // `min(by:)` rendrait la même colonne à égalité, mais rien ne garantit laquelle :
            // la recherche est explicite pour que « la plus à gauche » soit une propriété du
            // code et non de l'implémentation de la bibliothèque standard.
            var target = 0
            for column in 1..<count where heights[column] < heights[target] {
                target = column
            }
            columns[target].append(index)
            heights[target] += 1 / clamped(aspect: aspect)
        }
        return columns
    }
}
