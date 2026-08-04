import SwiftUI
import Testing

@testable import DesignSystem

// Le compte de colonnes de `I4`.
//
// **Ce qui fait foi, et ce qui n'en fait pas.** La regle est celle de l'addendum 2 bloc
// `13c` : « le nombre de colonnes n'est pas un reglage : la largeur de carte est fixe
// par le cran de la matrice, la grille prend ce qui rentre ». Le tableau des points de
// rupture de `docs/design/README.md` §4.6 donne aussi une colonne « Colonnes », mais il
// la presente lui-meme comme indicative — et sur les six crans, **deux seulement ont ete
// rendus pour de vrai** : 393 px et 834 px, dans l'addendum 2. Ce sont ceux-la que ce
// fichier assene ; les quatre autres n'ont pas de rendu qui les verifie.

@Test("Les deux largeurs rendues par l'addendum 2 donnent 2 et 4 colonnes")
func renderedWidthsMatchTheAddendum() {
    // Source : `docs/design/` addendum 2, bloc `13c` — « A poster.l, 393 px donnent 2
    // colonnes et 834 px en donnent 4 ». Densite ample sur les deux formats, dit le
    // meme bloc (« dense uniquement si un pointeur est connecte »).
    #expect(GridMetrics.columnCount(window: 393, cardWidth: PosterScale.l.width, density: .roomy) == 2)
    #expect(GridMetrics.columnCount(window: 834, cardWidth: PosterScale.l.width, density: .roomy) == 4)
}

@Test("La largeur utile retire les deux marges du cran")
func contentWidthRemovesBothMargins() {
    // 393 -> cran phonePortrait, marge 20 ; 834 -> padPortrait, marge 28.
    #expect(GridMetrics.contentWidth(window: 393) == 353)
    #expect(GridMetrics.contentWidth(window: 834) == 778)
}

@Test("n colonnes tiennent, n + 1 ne tiennent pas")
func theCountIsTheLargestThatFits() {
    let card: CGFloat = 140
    let gutter: CGFloat = 24
    for available in stride(from: 100.0 as CGFloat, through: 2000, by: 7) {
        let count = GridMetrics.columnCount(available: available, cardWidth: card, gutter: gutter)
        let occupied = CGFloat(count) * card + CGFloat(count - 1) * gutter
        let withOneMore = CGFloat(count + 1) * card + CGFloat(count) * gutter
        // La seule exception au « n colonnes tiennent » est le plancher a 1 : une
        // fenetre plus etroite qu'une carte rogne la carte, elle ne rend pas le vide.
        #expect(count == 1 || occupied <= available, "\(available) pt")
        #expect(withOneMore > available, "\(available) pt")
    }
}

@Test("Le compte ne descend jamais sous une colonne")
func neverFewerThanOneColumn() {
    #expect(GridMetrics.columnCount(available: 0, cardWidth: 140, gutter: 24) == 1)
    #expect(GridMetrics.columnCount(available: 12, cardWidth: 140, gutter: 24) == 1)
    #expect(GridMetrics.columnCount(available: -300, cardWidth: 140, gutter: 24) == 1)
    #expect(GridMetrics.columnCount(available: 900, cardWidth: 0, gutter: 24) == 1)
}

@Test("A largeur egale, une carte plus large donne moins de colonnes")
func biggerCardsMeanFewerColumns() {
    let counts = PosterScale.allCases.map {
        GridMetrics.columnCount(window: 1280, cardWidth: $0.width, density: .dense)
    }
    // `PosterScale.allCases` va de xs a xxl, donc du plus grand compte au plus petit.
    #expect(counts == counts.sorted(by: >))
    // 4 × 280 + 3 × 16 = 1168, et 5 colonnes en demanderaient 1464.
    #expect(counts.last == 4, "poster.xxl (280 pt) dans 1216 pt utiles, gouttiere 16")
}

@Test("Le compte croit avec la largeur de fenetre")
func theCountGrowsWithTheWindow() {
    let widths: [CGFloat] = [393, 430, 744, 834, 1024, 1280, 1680, 1920]
    let counts = widths.map {
        GridMetrics.columnCount(window: $0, cardWidth: PosterScale.l.width, density: .roomy)
    }
    #expect(counts == counts.sorted())
}
