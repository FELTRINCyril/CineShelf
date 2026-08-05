import SwiftUI
import Testing

@testable import DesignSystem

// La répartition en colonnes de `V3`.
//
// **Ce qui fait foi.** L'addendum 2 bloc `13c` pour le cran de carte (`poster.l`) et les deux
// comptes de colonnes rendus (2 à 393 pt, 4 à 834 pt) — ils sont assénés par
// `GridMetricsTests`, puisque c'est le même calcul. Ce fichier porte ce que `13c` ne dit pas :
// **dans quelle colonne va quelle image**, et ce que devient un ratio qui n'est pas une image.

@Suite("Maçonnerie")
struct MasonryColumnsTests {

    @Test("La galerie prend le même compte de colonnes que la grille, à poster.l")
    func galleryUsesTheSameColumnCount() {
        // Source : addendum 2 bloc `13c`, qui nomme le cran (« iPhone portrait · poster.l,
        // 2 colonnes », « iPad portrait · poster.l, 4 colonnes, gouttière 24 »).
        //
        // **La planche 4 bloc `6b` dit autre chose** — 3 colonnes à 393 pt, 5 à 1194, 8 à
        // 1920 — et à la seule largeur que les deux rendent, 393 pt, ils se contredisent.
        // `6b` se contredit d'ailleurs lui-même : ses largeurs de carte implicites valent
        // 116, 222 puis 223, donc il encode un compte par format et non une carte constante.
        // Les rendus divergent, donc le jeton fait foi, et `13c` est le seul qui le nomme.
        #expect(GridMetrics.columnCount(window: 393, cardWidth: PosterScale.l.width, density: .roomy) == 2)
        #expect(GridMetrics.columnCount(window: 834, cardWidth: PosterScale.l.width, density: .roomy) == 4)
    }

    @Test("La colonne la plus courte reçoit l'élément suivant")
    func shortestColumnWins() {
        // Trois carrés dans deux colonnes : 0 et 1 remplissent une colonne chacune, donc 2
        // retourne à la première — à égalité, la plus à gauche.
        #expect(MasonryColumns.distribute(aspects: [1, 1, 1], columnCount: 2) == [[0, 2], [1]])
        // Un panoramique est trois fois moins haut qu'un carré : la colonne qui le reçoit
        // reste la plus courte, donc elle reçoit aussi le suivant.
        let mixed = MasonryColumns.distribute(aspects: [1, 3, 1], columnCount: 2)
        #expect(mixed == [[0], [1, 2]])
    }

    @Test("Les proportions dégénérées ne détruisent pas l'équilibre")
    func degenerateAspectsAreBounded() {
        // Les trois cas que le modèle peut réellement produire. `MediaAsset.pixelWidth` et
        // `pixelHeight` valent **0 par défaut** — le schéma fermé l'exige — donc un média sans
        // dimensions lues arrive ici en 0/0, c'est-à-dire `nan`.
        #expect(MasonryColumns.clamped(aspect: 0) == MasonryColumns.fallbackAspect)
        #expect(MasonryColumns.clamped(aspect: .nan) == MasonryColumns.fallbackAspect)
        #expect(MasonryColumns.clamped(aspect: -2) == MasonryColumns.fallbackAspect)
        // L'infini part au **repli** et non à la borne haute : ce n'est pas une image très
        // large, c'est une division par zéro, donc une dimension qu'on ne connaît pas. La
        // borne haute, elle, ne sert qu'aux proportions réelles mais aberrantes.
        #expect(MasonryColumns.clamped(aspect: .infinity) == MasonryColumns.fallbackAspect)
        #expect(MasonryColumns.clamped(aspect: 400) == MasonryColumns.aspectBounds.upperBound)
        #expect(MasonryColumns.clamped(aspect: 0.001) == MasonryColumns.aspectBounds.lowerBound)

        // Et le résultat : une colonne empoisonnée par une hauteur infinie ne serait plus
        // jamais choisie. Avec bornes, les quatre éléments se répartissent.
        let columns = MasonryColumns.distribute(aspects: [0, .nan, 1, 1], columnCount: 2)
        #expect(columns.allSatisfy { !$0.isEmpty })
        #expect(columns.flatMap { $0 }.sorted() == [0, 1, 2, 3])
    }

    @Test("Les ratios que le prototype demande passent exacts")
    func realRatiosArePreserved() {
        // 21:9, 9:21 et le carré — les trois que `docs/design` §6 annonce mêlés dans une vraie
        // galerie, et ceux qui mettent l'algorithme de hauteur à l'épreuve. Aucun ne doit être
        // borné : ce sont des images.
        for aspect in [21.0 / 9, 9.0 / 21, 1.0] {
            #expect(MasonryColumns.clamped(aspect: aspect) == aspect)
        }
        // Un 9:21 est 5,4 fois plus haut qu'un 21:9 : une seule colonne doit suffire à
        // absorber plusieurs panoramiques pendant que l'autre porte le portrait.
        let columns = MasonryColumns.distribute(
            aspects: [9.0 / 21, 21.0 / 9, 21.0 / 9, 21.0 / 9], columnCount: 2)
        #expect(columns[0] == [0])
        #expect(columns[1] == [1, 2, 3])
    }

    @Test("Aucun élément n'est perdu ni dupliqué")
    func distributionIsAPartition() {
        let aspects = (0..<97).map { Double($0 % 7 + 1) / 3 }
        for count in 1...8 {
            let columns = MasonryColumns.distribute(aspects: aspects, columnCount: count)
            #expect(columns.count == count)
            #expect(columns.flatMap { $0 }.sorted() == Array(aspects.indices))
        }
    }

    @Test("Les cas dégénérés de comptage ne piègent pas")
    func degenerateColumnCounts() {
        // Sous 1, ramené à 1 : une fenêtre plus étroite qu'une carte rogne la carte.
        #expect(MasonryColumns.distribute(aspects: [1, 1], columnCount: 0) == [[0, 1]])
        #expect(MasonryColumns.distribute(aspects: [1, 1], columnCount: -3) == [[0, 1]])
        // Plus de colonnes que d'éléments : les colonnes vides existent, et c'est correct —
        // la grille garde ses gouttières et n'élargit pas les cartes restantes.
        #expect(MasonryColumns.distribute(aspects: [1], columnCount: 3) == [[0], [], []])
        #expect(MasonryColumns.distribute(aspects: [], columnCount: 3) == [[], [], []])
    }
}
