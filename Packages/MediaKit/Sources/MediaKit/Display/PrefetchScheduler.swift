import Foundation

// MARK: - V3 · Ce que la vue ne doit pas décider
//
// `PrefetchWindow` dit **quoi** préparer autour d'une frontière. Il restait deux décisions,
// et une vue est le pire endroit pour les prendre :
//
// 1. **Comment une frontière se déduit d'apparitions individuelles.** `onAppear` arrive une
//    fois par élément, dans un ordre que rien ne garantit, et une maçonnerie en émet depuis
//    plusieurs colonnes à la fois.
// 2. **Quand une nouvelle commande vaut la peine d'être passée.** Recalculer la fenêtre à
//    chaque apparition enverrait trente-deux ordres pour un écran de défilement, tous
//    presque identiques.
//
// Les deux sont de l'arithmétique, donc les deux sortent de la vue — c'est la règle
// « l'arithmétique ne vit jamais dans une `View` », et le bénéfice habituel : ce type
// s'assène sur des entrées dégénérées sans monter un rendu.
//
// MARK: - L'agrégation entre colonnes est le **maximum**, et voici pourquoi
//
// En maçonnerie les colonnes ont des hauteurs différentes, donc des frontières différentes :
// la colonne 1 peut être à l'indice 40 quand la colonne 4 est à 25. Trois candidats, un seul
// tient :
//
// - **le maximum** — c'est celui-ci. Un index qui a **apparu** a déjà été réclamé par le
//   chemin d'affichage : sa vignette est en cours ou en cache, et la redemander en
//   préchargement ne ferait qu'allonger la file devant celles qui manquent vraiment. Donc
//   tout ce qui est en dessous du maximum est déjà demandé, et **seul l'au-delà du maximum
//   n'est réclamé par personne**. La frontière utile est celle du plus avancé ;
// - le minimum — il ferait précharger des index déjà visibles dans la colonne la plus
//   avancée, c'est-à-dire du travail déjà fait ;
// - la moyenne — elle n'a de sens géométrique nulle part : ce n'est ni une position visible,
//   ni une frontière, et un défaut y serait indétectable puisqu'aucune observation ne la
//   contredirait jamais.
//
// **La frontière ne régresse donc jamais**, et c'est délibéré. Une remontée émet des
// apparitions d'index plus petits ; les huit premiers sont couverts par `behind`, les autres
// sont servis par le chemin d'affichage — accélérés par rien, mais jamais faux.
//
// **Et c'est pour ça qu'il n'y a pas d'heuristique de demi-tour.** « Un index nettement sous
// la frontière signale une remontée, donc on se réancre » paraît meilleur, et c'est un piège
// exactement sur le cas ci-dessus : avec 40 et 25 sur deux colonnes, l'écart entre colonnes
// dépasse déjà le seuil qu'un tel test devrait employer, et la colonne en retard serait
// lue comme un demi-tour à chaque passe de rendu. L'écart de colonnes et le demi-tour sont
// indiscernables depuis ce type, donc il ne tranche pas — il garde le maximum.

/// Traduit un flux d'apparitions d'éléments en ordres de préchargement.
///
/// Non `Sendable` et mutable en place : c'est un état de vue, tenu par un `@State`, et il
/// n'est lu que depuis l'acteur principal. Ce qui traverse, ce sont les `Order` qu'il rend.
public struct PrefetchScheduler {

    /// La fenêtre à poser autour de la frontière.
    public let window: PrefetchWindow

    /// De combien la frontière doit avancer avant qu'un nouvel ordre soit émis.
    ///
    /// **Un cran et non zéro** : sans lui, chaque apparition produirait un ordre presque
    /// identique au précédent. Le tiers de la fenêtre avant, ce qui laisse toujours deux
    /// tiers de marge d'avance devant le défilement au moment où le suivant part.
    public let step: Int

    /// La frontière atteinte : le **maximum** des index apparus. `nil` avant la première.
    public private(set) var frontier: Int?

    /// Ce que le dernier ordre a demandé, pour n'annuler que ce qu'on avait commandé.
    private var planned: Set<Int> = []
    /// La frontière au moment du dernier ordre, pour mesurer le cran.
    private var plannedAt: Int?

    public init(window: PrefetchWindow = .default, step: Int? = nil) {
        self.window = window
        self.step = max(1, step ?? window.ahead / 3)
    }

    /// Un ordre à passer au cache : ce qu'il faut préparer, ce qu'il faut abandonner.
    public struct Order: Sendable, Equatable {
        public let prefetch: [Int]
        public let cancel: [Int]
    }

    /// Enregistre l'apparition d'un élément et rend l'ordre qui en découle, s'il en découle un.
    ///
    /// - Parameters:
    ///   - index: l'index de l'élément apparu, dans la collection entière.
    ///   - count: le nombre total d'éléments.
    /// - Returns: `nil` quand rien ne change — index hors bornes, frontière inchangée, ou
    ///   progression sous le cran. C'est le cas de loin le plus fréquent, et c'est voulu.
    public mutating func advance(appeared index: Int, count: Int) -> Order? {
        guard (0..<count).contains(index) else { return nil }

        // Le maximum, et rien d'autre. Voir l'en-tête.
        guard index > (frontier ?? Int.min) else { return orderIfNeeded(count: count) }
        frontier = index
        return orderIfNeeded(count: count)
    }

    /// La collection a changé : la frontière ne veut plus rien dire.
    ///
    /// **Rend ce qu'il faut annuler.** Un filtre reposé ou un mélange rejoué laisse une file
    /// de préchargement pointant sur des index qui désignent maintenant d'autres images :
    /// sans annulation, le cache travaillerait sur la liste précédente pendant que l'écran
    /// affiche la nouvelle.
    public mutating func reset() -> [Int] {
        let abandoned = Array(planned).sorted()
        frontier = nil
        planned = []
        plannedAt = nil
        return abandoned
    }

    private mutating func orderIfNeeded(count: Int) -> Order? {
        guard let frontier else { return nil }
        if let plannedAt, frontier - plannedAt < step { return nil }

        let next = window.indices(from: frontier, count: count)
        let target = Set(next)
        let cancel = planned.subtracting(target)
        let prefetch = next.filter { !planned.contains($0) }

        planned = target
        plannedAt = frontier

        guard !prefetch.isEmpty || !cancel.isEmpty else { return nil }
        return Order(prefetch: prefetch, cancel: cancel.sorted())
    }
}
