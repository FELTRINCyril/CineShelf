import CoreGraphics
import Foundation
import Testing

@testable import MediaKit

// MARK: - L5 · La fenêtre de préchargement
//
// Extraite dans son propre fichier : `ThumbnailCacheTests` passait 500 lignes, et la règle
// `file_length` a raison de le refuser — ces tests ne partagent aucune fixture avec le
// cache, ils portent sur un calcul pur.
//
// **Réécrits par `V3`** : la fenêtre prenait une tranche visible qu'aucun conteneur paresseux
// de SwiftUI ne rapporte, donc les cinq tests assénaient une API que personne ne pouvait
// appeler. Ils portent maintenant sur la frontière, qui est ce qu'`onAppear` donne.

@Suite("Fenêtre de préchargement")
struct PrefetchWindowTests {

    @Test("La fenêtre précharge devant en priorité, puis derrière")
    func windowFavoursWhatComesNext() {
        let window = PrefetchWindow(ahead: 3, behind: 2)
        #expect(window.indices(from: 13, count: 100) == [14, 15, 16, 12, 11])
    }

    @Test("La fenêtre est asymétrique : c'est l'écran suivant qu'on précharge")
    func windowIsAsymmetric() {
        // Le correctif de performance noté depuis le prompt 13a : on défile vers le bas.
        #expect(PrefetchWindow.default.ahead > PrefetchWindow.default.behind)
    }

    @Test("La frontière elle-même n'est jamais recommandée")
    func windowExcludesTheFrontier() {
        let indices = PrefetchWindow(ahead: 5, behind: 5).indices(from: 25, count: 100)
        #expect(!indices.contains(25))
    }

    @Test("Les bords ne débordent pas de la collection")
    func windowClampsToBounds() {
        let window = PrefetchWindow(ahead: 10, behind: 10)
        #expect(window.indices(from: 2, count: 5) == [3, 4, 1, 0])
        #expect(window.indices(from: 4, count: 5) == [3, 2, 1, 0])
    }

    @Test("Les cas dégénérés rendent une fenêtre vide plutôt qu'une supposition")
    func windowHandlesDegenerateInput() {
        let window = PrefetchWindow(ahead: 4, behind: 4)
        // Frontière hors bornes : on ne sait pas où on est, et deviner reviendrait à
        // précharger le début d'une liste qu'on parcourt peut-être par la fin.
        #expect(window.indices(from: -1, count: 50).isEmpty)
        #expect(window.indices(from: 50, count: 50).isEmpty)
        #expect(window.indices(from: 0, count: 0).isEmpty)
        // Une fenêtre nulle ne piège pas : `(frontier + 1)...(frontier + 0)` serait un
        // intervalle invalide, et c'est le défaut que la construction par décalage évite.
        #expect(PrefetchWindow(ahead: 0, behind: 0).indices(from: 5, count: 50).isEmpty)
        // Les valeurs négatives sont ramenées à zéro à la construction.
        #expect(PrefetchWindow(ahead: -3, behind: -3) == PrefetchWindow(ahead: 0, behind: 0))
    }
}

// MARK: - V3 · L'ordonnanceur, et l'agrégation entre colonnes

@Suite("Ordonnanceur de préchargement")
struct PrefetchSchedulerTests {

    @Test("La frontière est le maximum des apparitions, pas la dernière")
    func frontierIsTheMaximum() {
        // Le cas de la maçonnerie : quatre colonnes de hauteurs différentes émettent leurs
        // apparitions dans un ordre qui n'a rien de croissant. Sans le maximum, la frontière
        // suivrait la colonne la plus courte et le préchargement viserait des index déjà
        // affichés — donc du travail déjà fait.
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 6, behind: 2), step: 1)
        _ = scheduler.advance(appeared: 40, count: 200)
        _ = scheduler.advance(appeared: 25, count: 200)
        _ = scheduler.advance(appeared: 31, count: 200)
        #expect(scheduler.frontier == 40)
    }

    @Test("Une colonne en retard ne fait pas régresser la frontière")
    func laggingColumnDoesNotRegress() {
        // Corollaire du précédent, et la raison pour laquelle il n'y a **pas** d'heuristique
        // de demi-tour : 25 est loin sous 40, et pourtant ce n'est pas une remontée, c'est la
        // quatrième colonne. Les deux sont indiscernables depuis ce type.
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 4, behind: 2), step: 1)
        _ = scheduler.advance(appeared: 40, count: 200)
        let order = scheduler.advance(appeared: 25, count: 200)
        #expect(order == nil)
        #expect(scheduler.frontier == 40)
    }

    @Test("Le premier ordre part dès la première apparition")
    func firstAppearanceOrders() {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 3, behind: 1), step: 4)
        let order = scheduler.advance(appeared: 10, count: 100)
        // Le cran ne retient pas le **premier** ordre : au repos, rien n'a encore été
        // commandé, et attendre reviendrait à ne jamais précharger le premier écran.
        #expect(order?.prefetch == [11, 12, 13, 9])
    }

    @Test("Le cran évite un ordre par apparition")
    func stepThrottlesOrders() {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 9, behind: 3), step: 3)
        #expect(scheduler.advance(appeared: 10, count: 100) != nil)
        #expect(scheduler.advance(appeared: 11, count: 100) == nil)
        #expect(scheduler.advance(appeared: 12, count: 100) == nil)
        #expect(scheduler.advance(appeared: 13, count: 100) != nil)
    }

    @Test("Un ordre ne redemande pas ce qui est déjà commandé, et annule ce qui sort")
    func orderIsADifference() {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 3, behind: 1), step: 2)
        _ = scheduler.advance(appeared: 10, count: 100)  // demande 11 12 13 9
        let order = scheduler.advance(appeared: 13, count: 100)  // veut 14 15 16 12
        #expect(order?.prefetch == [14, 15, 16])
        // 9, 11 et 13 sortent de la fenêtre : on les abandonne, et **seulement eux** — le
        // cache, lui, ne renonce pas à ce qu'un affichage attend.
        #expect(order?.cancel == [9, 11, 13])
    }

    @Test("Un changement de collection annule ce qui était commandé")
    func resetCancelsWhatWasOrdered() {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 2, behind: 0), step: 1)
        _ = scheduler.advance(appeared: 5, count: 100)
        #expect(scheduler.reset() == [6, 7])
        #expect(scheduler.frontier == nil)
        // Après remise à zéro, la première apparition redevient un premier ordre.
        #expect(scheduler.advance(appeared: 0, count: 100)?.prefetch == [1, 2])
    }

    @Test("Les entrées dégénérées ne produisent aucun ordre")
    func degenerateInputOrdersNothing() {
        var scheduler = PrefetchScheduler(window: PrefetchWindow(ahead: 4, behind: 4), step: 1)
        #expect(scheduler.advance(appeared: -1, count: 10) == nil)
        #expect(scheduler.advance(appeared: 10, count: 10) == nil)
        #expect(scheduler.advance(appeared: 0, count: 0) == nil)
        #expect(scheduler.frontier == nil)
        // Une collection d'un seul élément : la fenêtre n'a rien à préparer autour, et
        // l'ordre vide n'est pas émis.
        #expect(scheduler.advance(appeared: 0, count: 1) == nil)
    }
}
