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
// MARK: - V3 · La signature prenait une tranche que personne ne pouvait lui donner
//
// **Corrigé, pas contourné.** L'API prenait `visible: Range<Int>`, et c'était inutilisable :
// **aucun conteneur paresseux de SwiftUI ne rapporte cette tranche.** Un `LazyVStack` notifie
// élément par élément, par `onAppear`, et il notifie **un index**. L'écart était inscrit
// depuis quatre sessions sous la forme « `prefetch` n'a aucun appelant de vue » ; la cause
// n'était pas l'absence d'appelant, c'était une signature qu'aucun appelant ne pouvait
// remplir.
//
// **Les deux routes envisagées, et pourquoi celle-ci.** `ScrollPosition` (iOS 18) rend **un
// seul** identifiant d'ancrage pour toute la vue de défilement : dans une maçonnerie à
// quatre colonnes indépendantes il ne dit rien des trois autres, et il ne dit rien du tout
// **au repos** — c'est-à-dire au premier affichage, précisément le moment où précharger
// l'écran suivant sert le plus. `onAppear` est le seul signal qu'un `LazyVStack` émette, et
// la tranche visible n'existe de toute façon pas en maçonnerie : les colonnes ont des
// hauteurs différentes, donc des frontières différentes.
//
// L'ancienne signature est **supprimée**, pas doublée : la garder aurait laissé au prochain
// lecteur le choix entre une API utilisable et une API qui ne l'est pas, et rien n'aurait dit
// laquelle.

/// La tranche d'éléments à précharger autour de la frontière atteinte par le défilement.
public struct PrefetchWindow: Sendable, Equatable {
    /// Combien d'éléments préparer **devant** la frontière.
    public let ahead: Int
    /// Combien en garder **derrière** elle, pour un défilement qui remonte.
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

    /// Les index à précharger autour d'une frontière, **elle exclue**.
    ///
    /// - Parameters:
    ///   - frontier: le dernier index dont l'apparition a été signalée. Hors bornes, rien
    ///     n'est préchargé : on ne sait pas où on est, et deviner reviendrait à précharger le
    ///     début d'une liste qu'on parcourt peut-être par la fin.
    ///   - count: le nombre total d'éléments.
    /// - Returns: les index à préparer, les plus proches de la frontière d'abord, devant
    ///   avant derrière.
    public func indices(from frontier: Int, count: Int) -> [Int] {
        guard count > 0, (0..<count).contains(frontier) else { return [] }

        // Construits par décalage plutôt qu'en `Range` : `(frontier + 1)...(frontier + ahead)`
        // est un intervalle **invalide** quand `ahead` vaut 0, et il ne rend pas une
        // collection vide — il piège au premier appel avec une fenêtre nulle.
        let forward = (0..<ahead).map { frontier + 1 + $0 }
        let backward = (0..<behind).map { frontier - 1 - $0 }

        // L'ordre compte : la file de préchargement est servie dans l'ordre reçu, donc le
        // plus proche de la frontière part en premier, devant d'abord.
        return forward.filter { $0 < count } + backward.filter { $0 >= 0 }
    }
}
