import Foundation

// MARK: - L5 · La fenêtre de préchargement
//
// **Le calcul est ici et pas dans la vue**, comme `GridMetrics` et `ProgressMetrics` avant
// lui : un type nonisolé se teste sur des entrées dégénérées — collection vide, index hors
// bornes, fenêtre plus large que la collection — sans monter un rendu, et sans risquer le
// contrôle d'isolation qui tue le processus de test.
//
// **La fenêtre est asymétrique, et c'est tout le sujet.** Le correctif de performance noté
// depuis le prompt `13a` n'est pas « précharger autour », c'est **précharger l'écran
// suivant** : on défile vers le bas, donc ce qui va être demandé est devant. Une fenêtre
// symétrique dépenserait la moitié de son budget sur des vignettes déjà affichées, dont
// celles du cache mémoire — donc sur rien.
//
// Ce que ce type ne fait pas : décider *quand* précharger. C'est la vue qui sait qu'elle a
// défilé, et `L5` ne livre que l'API.

/// La tranche d'éléments à précharger autour de ce qui est visible.
public struct PrefetchWindow: Sendable, Equatable {
    /// Combien d'éléments préparer **devant** le dernier visible.
    public let ahead: Int
    /// Combien en garder **derrière** le premier visible, pour un défilement qui remonte.
    public let behind: Int

    /// Le réglage par défaut : un écran devant, un tiers d'écran derrière.
    ///
    /// Les valeurs sont un point de départ et non une mesure : les budgets de `docs/04` §4
    /// se vérifient avec Instruments sur appareil, et le simulateur donne des chiffres
    /// rassurants qui ne disent rien du matériel (écart connu).
    public static let `default` = PrefetchWindow(ahead: 24, behind: 8)

    public init(ahead: Int, behind: Int) {
        self.ahead = max(0, ahead)
        self.behind = max(0, behind)
    }

    /// Les index à précharger, **hors** de ce qui est déjà visible.
    ///
    /// Exclure le visible n'est pas une optimisation : ces vignettes ont déjà été demandées
    /// par le chemin d'affichage, et les redemander en préchargement ne ferait qu'allonger
    /// la file devant celles qui manquent vraiment.
    ///
    /// - Parameters:
    ///   - visible: la tranche visible. Vide, rien n'est préchargé : on ne sait pas où on
    ///     est, et deviner reviendrait à précharger le début d'une liste qu'on parcourt
    ///     peut-être par la fin.
    ///   - count: le nombre total d'éléments.
    /// - Returns: les index à préparer, les plus proches du visible d'abord, devant avant
    ///   derrière. Vide plutôt qu'une supposition quand on ne sait pas où on est.
    public func indices(visible: Range<Int>, count: Int) -> [Int] {
        guard count > 0, !visible.isEmpty else { return [] }

        let first = max(0, visible.lowerBound)
        let last = min(count - 1, visible.upperBound - 1)
        guard first <= last else { return [] }

        // Construits par décalage plutôt qu'en `Range` : `(last + 1)...(last + ahead)` est
        // un intervalle **invalide** quand `ahead` vaut 0, et il ne rend pas une collection
        // vide — il piège au premier appel avec une fenêtre nulle.
        let forward = (0..<ahead).map { last + 1 + $0 }
        let backward = (0..<behind).map { first - 1 - $0 }

        // L'ordre compte : la file de préchargement est servie dans l'ordre reçu, donc le
        // plus proche du visible part en premier, devant d'abord.
        return forward.filter { $0 < count } + backward.filter { $0 >= 0 }
    }
}
