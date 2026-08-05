import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

// MARK: - L5 · La fenêtre de préchargement
//
// Extraite dans son propre fichier : `ThumbnailCacheTests` passait 500 lignes, et la règle
// `file_length` a raison de le refuser — ces tests ne partagent aucune fixture avec le
// cache, ils portent sur un calcul pur.

@Suite("Fenêtre de préchargement")
struct PrefetchWindowTests {

    @Test("La fenêtre précharge devant en priorité, puis derrière")
    func windowFavoursWhatComesNext() {
        let window = PrefetchWindow(ahead: 3, behind: 2)
        // Visible 10..<14, donc dernier visible 13 et premier 10.
        #expect(window.indices(visible: 10..<14, count: 100) == [14, 15, 16, 9, 8])
    }

    @Test("La fenêtre est asymétrique : c'est l'écran suivant qu'on précharge")
    func windowIsAsymmetric() {
        // Le correctif de performance noté depuis le prompt 13a : on défile vers le bas.
        #expect(PrefetchWindow.default.ahead > PrefetchWindow.default.behind)
    }

    @Test("Le visible n'est jamais rechargé en préchargement")
    func windowExcludesTheVisibleRange() {
        let indices = PrefetchWindow(ahead: 5, behind: 5).indices(visible: 20..<30, count: 100)
        #expect(indices.allSatisfy { !(20..<30).contains($0) })
    }

    @Test("Les bords ne débordent pas de la collection")
    func windowClampsToBounds() {
        let window = PrefetchWindow(ahead: 10, behind: 10)
        #expect(window.indices(visible: 0..<3, count: 5) == [3, 4])
        #expect(window.indices(visible: 3..<5, count: 5) == [2, 1, 0])
    }

    @Test("Les cas dégénérés rendent une fenêtre vide plutôt qu'une supposition")
    func windowHandlesDegenerateInput() {
        let window = PrefetchWindow(ahead: 4, behind: 4)
        // Aucun visible : on ne sait pas où on est, et deviner reviendrait à précharger le
        // début d'une liste qu'on parcourt peut-être par la fin.
        #expect(window.indices(visible: 0..<0, count: 50).isEmpty)
        #expect(window.indices(visible: 0..<10, count: 0).isEmpty)
        // Une fenêtre nulle ne piège pas : `(last + 1)...(last + 0)` serait un intervalle
        // invalide, et c'est le défaut que la construction par décalage évite.
        #expect(PrefetchWindow(ahead: 0, behind: 0).indices(visible: 5..<8, count: 50).isEmpty)
        // Les valeurs négatives sont ramenées à zéro à la construction.
        #expect(PrefetchWindow(ahead: -3, behind: -3) == PrefetchWindow(ahead: 0, behind: 0))
    }
}
