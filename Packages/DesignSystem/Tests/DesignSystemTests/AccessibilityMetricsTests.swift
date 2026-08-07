import SwiftUI
import Testing

@testable import DesignSystem

// MARK: - V12 · Les règles d'accessibilité qui sont du calcul
//
// **Testées ici parce qu'elles sont nonisolées et sans rendu.** La bascule grille → liste est
// une décision, pas un dessin : l'écrire dans le corps d'`AdaptiveTileGrid` l'aurait rendue
// intestable, et c'est la règle « l'arithmétique ne vit jamais dans une `View` ».
//
// Source de toutes les assertions : `docs/06-BRIEF-DESIGN.md` §« Accessibilité » — « Dynamic
// Type de `xSmall` à `AX5`, sans troncature. **Au-delà de `.accessibility1`, les grilles
// basculent en liste.** »

@Suite("Bascule grille → liste")
struct GridListSwitchTests {

    /// **Le mot « au-delà » est strict, et c'est tout l'enjeu du test.**
    ///
    /// `.accessibility1` **reste** en grille ; c'est `.accessibility2` qui bascule. Un `>=`
    /// ferait basculer une taille de trop — et la différence se voit : `AX1` est la première
    /// taille d'accessibilité, celle que beaucoup d'utilisateurs gardent en permanence.
    @Test("La bascule se fait au-delà d'accessibility1, pas à partir de lui")
    func thresholdIsStrict() {
        #expect(!GridMetrics.prefersList(at: .accessibility1))
        #expect(GridMetrics.prefersList(at: .accessibility2))
    }

    /// Les deux bouts de l'échelle que le brief nomme, plus les crans intermédiaires.
    ///
    /// **Toutes les tailles et non trois choisies** : `DynamicTypeSize.allCases` est la seule
    /// façon de garantir qu'un cran ajouté par une version future d'iOS ne tombe pas dans un
    /// trou. Le test dit alors « il y a un cran que je ne sais pas classer », ce qui est
    /// exactement l'information utile.
    @Test("Toute taille jusqu'à accessibility1 reste en grille, toutes celles d'après basculent")
    func everySizeIsClassified() {
        for size in DynamicTypeSize.allCases {
            let expected = size > .accessibility1
            #expect(
                GridMetrics.prefersList(at: size) == expected,
                Comment(rawValue: "\(size) mal classée"))
        }
    }

    /// Les deux extrémités du brief, nommément : `xSmall` et `AX5`.
    @Test("xSmall reste une grille, AX5 est une liste")
    func bothEndsOfTheScale() {
        #expect(!GridMetrics.prefersList(at: .xSmall))
        #expect(GridMetrics.prefersList(at: .accessibility5))
    }

    /// **Le contrôle négatif : sans la bascule, la grille garderait plusieurs colonnes.**
    ///
    /// Sur une fenêtre large, `columnCount` rend plusieurs colonnes — donc le test précédent ne
    /// prouverait rien si `prefersList` était ignoré par la vue. Celui-ci montre qu'il y a bien
    /// quelque chose à ignorer : la largeur choisie **est** une largeur où la grille est dense.
    @Test("À largeur égale, la grille dense a plusieurs colonnes")
    func wideWindowIsDenseWithoutTheSwitch() {
        // 1 280 pt, le format des prototypes de la planche 3, et une carte de 150 pt.
        let columns = GridMetrics.columnCount(window: 1_280, cardWidth: 150, density: .roomy)
        #expect(columns > 1, "Sans bascule, cette fenêtre porte \(columns) colonnes")
    }
}
