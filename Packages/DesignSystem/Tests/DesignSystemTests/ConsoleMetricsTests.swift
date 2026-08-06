import SwiftUI
import Testing

@testable import DesignSystem

// Les mesures de `I5`.
//
// **Ce que ces tests peuvent affirmer** : les deux hauteurs rendues, et les invariants qui les
// lient. **Ce qu'ils ne peuvent pas** : que la ligne *ressemble* au bloc `7a` — ça se regarde
// sur la planche du catalogue, comme pour tous les composants.

@Suite("Mesures de la console")
struct ConsoleMetricsTests {

    @Test("Les deux hauteurs de ligne sont celles des deux blocs qui les rendent")
    func rowHeightsMatchTheirBlocks() {
        // Sources : planche 5 bloc `7a` (`height:30px`, densité dense sur Mac) et addendum 2
        // bloc `13d` (« lignes de 44 puisque la densité par défaut est ample », iPad).
        #expect(ConsoleMetrics.rowHeight(.dense) == 30)
        #expect(ConsoleMetrics.rowHeight(.roomy) == 44)
    }

    @Test("La ligne ample atteint la cible tactile, la dense ne le prétend pas")
    func roomyRowIsTouchable() {
        // 44 n'est pas une coïncidence : c'est `Space.minHitTarget`, et c'est ce qui rend la
        // console utilisable au doigt sur iPad. En dense, le relevé assume l'usage clavier —
        // donc l'écran devra offrir une autre cible sur une plateforme tactile, et c'est
        // pourquoi cette asymétrie est assénée plutôt que subie.
        #expect(ConsoleMetrics.rowHeight(.roomy) == Space.minHitTarget)
        #expect(ConsoleMetrics.rowHeight(.dense) < Space.minHitTarget)
    }

    @Test("L'en-tête est plus bas qu'une ligne ample, et ne suit pas la densité")
    func headerIsShorterThanARoomyRow() {
        // 28 pt : c'est la valeur que le relevé de la planche 5 attribue par erreur à la ligne
        // (« lignes de 28 pt »), alors que le rendu la donne à l'**en-tête**. Un en-tête aussi
        // haut qu'une ligne de données se lirait comme une ligne de données.
        #expect(ConsoleMetrics.headerHeight == 28)
        #expect(ConsoleMetrics.headerHeight < ConsoleMetrics.rowHeight(.roomy))
    }

    @Test("La vignette tient dans la ligne dense, ce qu'aucun cran d'affiche ne fait")
    func thumbnailFitsTheDenseRow() {
        // C'est la raison d'être de cette mesure : `PosterScale.xs` fait 32 pt de large, donc
        // 48 de haut en 2:3 — une ligne de 30 pt ne peut pas la contenir. La contrainte vient
        // de la ligne, pas de l'échelle, et c'est le seul endroit de l'app dans ce cas.
        #expect(ConsoleMetrics.thumbnailHeight <= ConsoleMetrics.rowHeight(.dense))
        #expect(PosterScale.xs.size(.portrait).height > ConsoleMetrics.rowHeight(.dense))
        // Et elle reste au ratio d'une affiche : 16 × 24.
        #expect(ConsoleMetrics.thumbnailHeight == 24)
    }
}
