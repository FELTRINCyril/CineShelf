import Foundation
import SwiftData

/// Les prédicats simples, nommés une fois et réutilisables.
///
/// **Pourquoi ils ne vivent pas dans les vues.** Six `#Predicate` étaient écrits
/// directement dans `App/` — deux « le titre d'identifiant X », les genres vivants,
/// les genres épinglés, un média par identifiant, un genre par clé repliée. Trois
/// raisons de les rapatrier ici :
///
/// 1. **Aucune cible de test ne monte les vues** : ces prédicats étaient les seuls
///    du dépôt sans couverture possible, et c'était un écart connu. Ici, ils sont
///    testables.
/// 2. **Le plafond de cinq clauses** (voir `predicateClause(active:_:)`) est une
///    propriété de `#Predicate` que personne ne devine. Concentrer les prédicats
///    dans un seul module met la documentation à côté du code qu'elle concerne, et
///    la règle SwiftLint `no_predicate_outside_core` empêche qu'un septième
///    réapparaisse dans une vue.
/// 3. `CLAUDE.md` l'exigeait déjà : aucune logique métier dans une `View`.
///
/// Chacun tient largement sous le plafond — le plus long en compte trois.
public enum TitleQuery {

    /// Un titre par identifiant.
    ///
    /// Sert aux vues de détail, qui reçoivent un `UUID` de route et non un objet :
    /// une route doit survivre à un redémarrage, donc elle ne peut pas transporter
    /// de référence.
    public static func withID(_ id: UUID) -> Predicate<Title> {
        #Predicate<Title> { $0.id == id }
    }

    /// Le titre vivant de ce nom replié et de cette année, dans une bibliothèque.
    ///
    /// **La clé de doublon d'un import**, arrêtée le 2026-08-04 : nom et année, pas la
    /// réalisation. Voir `EntityResolver.existingTitle(named:year:)` pour le raisonnement.
    ///
    /// L'année est comparée sur `releaseDate` par un intervalle plutôt que sur un champ
    /// d'année, qui n'existe pas — `Title.releaseYear` est calculé, donc inutilisable dans un
    /// `#Predicate`. Un titre sans date ne fait doublon qu'avec un autre sans date : `year`
    /// nul cherche `releaseDate == nil`, et non « n'importe quelle date ».
    public static func living(sortName: String, year: Int?, inLibrary libraryID: UUID) -> Predicate<Title> {
        guard let year else {
            return #Predicate<Title> {
                $0.sortName == sortName && $0.releaseDate == nil && $0.deletedAt == nil
                    && $0.library?.id == libraryID
            }
        }
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // Un intervalle `[1er janvier, 1er janvier suivant[` dans le **fuseau courant** :
        // `Title.releaseYear` utilise `Calendar.current`, donc borner en UTC ferait diverger
        // la recherche de doublon de l'année affichée pour les titres du 1er janvier.
        let start = calendar.date(from: components) ?? .distantPast
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? .distantFuture

        return #Predicate<Title> {
            $0.sortName == sortName && $0.deletedAt == nil
                && $0.library?.id == libraryID
                && $0.releaseDate.flatMap { $0 >= start && $0 < end } == true
        }
    }

    /// Les titres d'un lot d'identifiants.
    ///
    /// Sert a l'edition en masse, qui recoit une selection d'identifiants et doit la
    /// charger **dans son propre contexte** : un `@Model` appartient au contexte qui
    /// l'a lu, et le traverser vers un acteur ne compile pas en concurrence stricte.
    ///
    /// Un seul aller-retour plutot qu'un `fetch` par identifiant : sur cinquante
    /// titres, la difference n'est pas le temps mais le nombre de transactions
    /// ouvertes, et donc la fenetre pendant laquelle un lot peut echouer a moitie.
    /// `Set.contains` se traduit en `IN (...)`, ce qu'un test verifie sur le magasin.
    public static func withIDs(_ ids: Set<UUID>) -> Predicate<Title> {
        #Predicate<Title> { ids.contains($0.id) }
    }
}

public enum PersonQuery {

    /// La personne vivante de cette clé de tri, dans une bibliothèque.
    ///
    /// **`sortName` sert de clé de dédoublonnage**, parce que le schéma est fermé et que
    /// `Person` n'aura pas de `nameKey` comme `Genre`. Il est déjà replié en locale invariante
    /// par `refreshDerived()`, donc il est reproductible d'un appareil à l'autre — voir
    /// `docs/02` §3 et `EntityResolver.person(named:)`.
    ///
    /// Trois clauses, loin du plafond de cinq. Le filtre `deletedAt == nil` compte : sans lui,
    /// l'import ressusciterait une personne mise à la corbeille avec toutes ses anciennes
    /// associations, ce que personne n'a demandé.
    public static func living(sortName: String, inLibrary libraryID: UUID) -> Predicate<Person> {
        #Predicate<Person> {
            $0.sortName == sortName && $0.deletedAt == nil && $0.library?.id == libraryID
        }
    }

    /// Une personne par identifiant.
    public static func withID(_ id: UUID) -> Predicate<Person> {
        #Predicate<Person> { $0.id == id }
    }

    /// Les personnes d'un lot d'identifiants. Meme motif que `TitleQuery.withIDs`.
    public static func withIDs(_ ids: Set<UUID>) -> Predicate<Person> {
        #Predicate<Person> { ids.contains($0.id) }
    }
}

public enum GenreQuery {

    /// Les genres hors corbeille.
    ///
    /// `docs/02` §3.5 : **toute** requête de genres filtre `deletedAt == nil`. Sans
    /// ce filtre, un genre mis à la corbeille réapparaîtrait dans les sélecteurs, et
    /// le retaper le ressusciterait avec toutes ses anciennes associations.
    public static var living: Predicate<Genre> {
        #Predicate<Genre> { $0.deletedAt == nil }
    }

    /// Les genres épinglés, pour la barre latérale.
    public static var pinned: Predicate<Genre> {
        #Predicate<Genre> { $0.isPinned && $0.deletedAt == nil && $0.isArchived == false }
    }

    /// Un genre vivant par clé repliée, dans une bibliothèque donnée.
    ///
    /// C'est le dédoublonnage applicatif qui remplace `@Attribute(.unique)`, que
    /// CloudKit interdit. `GenreRepository.findOrCreate` s'en sert.
    public static func living(key: String, target: GenreTarget, inLibrary libraryID: UUID) -> Predicate<Genre> {
        let targetRaw = target.rawValue
        return #Predicate<Genre> {
            $0.nameKey == key && $0.targetRaw == targetRaw && $0.library?.id == libraryID
                && $0.deletedAt == nil
        }
    }

    /// Un genre vivant par clé repliée, toutes bibliothèques confondues.
    public static func living(key: String) -> Predicate<Genre> {
        #Predicate<Genre> { $0.nameKey == key && $0.deletedAt == nil }
    }

    /// Les genres d'un lot d'identifiants, **corbeille comprise**.
    ///
    /// Contrairement aux autres requetes de genre, celle-ci ne filtre pas
    /// `deletedAt == nil`, et c'est delibere : l'edition en masse doit distinguer
    /// « ce genre n'existe pas » de « ce genre est a la corbeille » pour rendre le bon
    /// refus. Filtrer ici rendrait les deux cas indiscernables.
    public static func withIDs(_ ids: Set<UUID>) -> Predicate<Genre> {
        #Predicate<Genre> { ids.contains($0.id) }
    }
}

public enum MediaQuery {

    /// Un média par identifiant.
    public static func asset(withID id: UUID) -> Predicate<MediaAsset> {
        #Predicate<MediaAsset> { $0.id == id }
    }
}

// MARK: - Visibilité et recherche des collections et des signets
//
// `Title` et `Person` ont leurs propres filtres (`TitleFilter`, `PersonFilter`).
// `TitleCollection` et `SavedLink` n'en avaient pas : `L2` les leur donne, sous la
// forme réduite dont la recherche a besoin — visibilité + terme.
//
// **Ces deux prédicats sont construits à la main, et c'est mesuré, pas prudentiel.**
// Écrits avec `#Predicate`, les cinq clauses — corbeille, archivage, privé,
// bibliothèque, terme — coûtent **7 253 ms** de vérification de types pour les
// collections et **7 446 ms** pour les signets. Elles compilent, mais à une clause de
// l'échec et pour quinze secondes ajoutées à chaque build propre du paquet. En arbre
// manuel : **moins de 200 ms**. Voir `predicateClause(active:_:)` pour le pourquoi.
//
// Le coût vient de la traversée `library?.id`, que ces deux modèles n'ont pas
// dénormalisée. **Décision de ne pas leur ajouter de `filterKeys`** : la
// dénormalisation a un coût permanent — un invariant de plus à maintenir à chaque
// écriture — et ces deux tables comptent des dizaines de lignes, pas des milliers. La
// jointure ne se paie qu'en SQL, où elle est négligeable ; le plafond de type-check,
// lui, se paie à chaque compilation. L'arbre manuel règle le second sans introduire le
// premier.

public enum CollectionQuery {

    /// La collection vivante de cette clé de tri, dans une bibliothèque.
    ///
    /// Même motif que `PersonQuery.living(sortName:inLibrary:)`.
    public static func living(sortName: String, inLibrary libraryID: UUID) -> Predicate<TitleCollection> {
        #Predicate<TitleCollection> {
            $0.sortName == sortName && $0.deletedAt == nil && $0.library?.id == libraryID
        }
    }

    /// Les collections d'un lot d'identifiants, **corbeille comprise**.
    ///
    /// Meme motif que `GenreQuery.withIDs` : l'edition en masse doit pouvoir dire
    /// « cette collection est a la corbeille » plutot que « elle n'existe pas ».
    public static func withIDs(_ ids: Set<UUID>) -> Predicate<TitleCollection> {
        #Predicate<TitleCollection> { ids.contains($0.id) }
    }

    /// Les collections visibles qui correspondent à un terme.
    ///
    /// - Parameters:
    ///   - term: le terme **déjà replié** (sans accents, sans casse). Vide, la clause
    ///     est neutralisée — un `CONTAINS ''` ne matche aucune ligne en SQL.
    ///   - hidingPrivate: le profil actif masque les entités privées.
    ///   - libraryID: la bibliothèque du profil actif. `nil` ne filtre pas.
    ///   - showsArchived: inclut les collections archivées.
    /// - Returns: le prédicat correspondant.
    public static func matching(
        term: String,
        hidingPrivate: Bool,
        libraryID: UUID?,
        showsArchived: Bool = false
    ) -> Predicate<TitleCollection> {
        let noID = UUID()
        let libraryTarget = libraryID ?? noID

        return Predicate<TitleCollection> { collection in
            let root = PredicateExpressions.build_Arg(collection)
            let alive = PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.deletedAt),
                rhs: PredicateExpressions.build_NilLiteral()
            )
            let notArchived = predicateClause(
                active: showsArchived == false,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isArchived),
                    rhs: PredicateExpressions.build_Arg(false)
                )
            )
            let notPrivate = predicateClause(
                active: hidingPrivate,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isPrivate),
                    rhs: PredicateExpressions.build_Arg(false)
                )
            )
            let inLibrary = predicateClause(
                active: libraryID != nil,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_NilCoalesce(
                        lhs: PredicateExpressions.build_flatMap(
                            PredicateExpressions.build_KeyPath(root: root, keyPath: \.library)
                        ) {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0), keyPath: \.id)
                        },
                        rhs: PredicateExpressions.build_Arg(noID)
                    ),
                    rhs: PredicateExpressions.build_Arg(libraryTarget)
                )
            )
            let matchesTerm = predicateClause(
                active: term.isEmpty == false,
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_KeyPath(root: root, keyPath: \.searchText),
                    PredicateExpressions.build_Arg(term)
                )
            )

            return PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Conjunction(
                    lhs: PredicateExpressions.build_Conjunction(lhs: alive, rhs: notArchived),
                    rhs: notPrivate
                ),
                rhs: PredicateExpressions.build_Conjunction(lhs: inLibrary, rhs: matchesTerm)
            )
        }
    }
}

public enum SavedLinkQuery {

    /// Les signets visibles qui correspondent à un terme.
    ///
    /// `SavedLink.searchText` agrège le nom, les notes **et l'URL** : chercher
    /// « imdb » trouve donc un signet dont seule l'adresse le contient, ce qui est le
    /// comportement attendu d'un gestionnaire de signets.
    ///
    /// - Parameters:
    ///   - term: le terme déjà replié. Vide, la clause est neutralisée.
    ///   - hidingPrivate: le profil actif masque les entités privées.
    ///   - libraryID: la bibliothèque du profil actif. `nil` ne filtre pas.
    ///   - showsArchived: inclut les signets archivés.
    /// - Returns: le prédicat correspondant.
    public static func matching(
        term: String,
        hidingPrivate: Bool,
        libraryID: UUID?,
        showsArchived: Bool = false
    ) -> Predicate<SavedLink> {
        let noID = UUID()
        let libraryTarget = libraryID ?? noID

        return Predicate<SavedLink> { link in
            let root = PredicateExpressions.build_Arg(link)
            let alive = PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.deletedAt),
                rhs: PredicateExpressions.build_NilLiteral()
            )
            let notArchived = predicateClause(
                active: showsArchived == false,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isArchived),
                    rhs: PredicateExpressions.build_Arg(false)
                )
            )
            let notPrivate = predicateClause(
                active: hidingPrivate,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_KeyPath(root: root, keyPath: \.isPrivate),
                    rhs: PredicateExpressions.build_Arg(false)
                )
            )
            let inLibrary = predicateClause(
                active: libraryID != nil,
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_NilCoalesce(
                        lhs: PredicateExpressions.build_flatMap(
                            PredicateExpressions.build_KeyPath(root: root, keyPath: \.library)
                        ) {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0), keyPath: \.id)
                        },
                        rhs: PredicateExpressions.build_Arg(noID)
                    ),
                    rhs: PredicateExpressions.build_Arg(libraryTarget)
                )
            )
            let matchesTerm = predicateClause(
                active: term.isEmpty == false,
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_KeyPath(root: root, keyPath: \.searchText),
                    PredicateExpressions.build_Arg(term)
                )
            )

            return PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Conjunction(
                    lhs: PredicateExpressions.build_Conjunction(lhs: alive, rhs: notArchived),
                    rhs: notPrivate
                ),
                rhs: PredicateExpressions.build_Conjunction(lhs: inLibrary, rhs: matchesTerm)
            )
        }
    }
}

public enum ImportMappingQuery {

    /// La correspondance mémorisée d'un en-tête, dans une bibliothèque.
    ///
    /// Deux clauses, très loin du plafond de cinq. La signature est comparée **telle
    /// quelle** : elle a déjà été repliée sous locale invariante à l'écriture comme à la
    /// lecture (`ColumnMapping.headerSignature`), et la replier une seconde fois ici
    /// n'ajouterait rien qu'un endroit de plus où les deux côtés peuvent diverger.
    ///
    /// Pas de filtre `deletedAt` : `ImportMapping` n'a pas de corbeille, une correspondance
    /// perdue ne coûtant que de refaire un écran.
    public static func matching(signature: String, inLibrary libraryID: UUID) -> Predicate<ImportMapping> {
        #Predicate<ImportMapping> {
            $0.headerSignature == signature && $0.library?.id == libraryID
        }
    }

    /// La correspondance **personnelle** d'un en-tête, à l'exclusion des intégrées.
    ///
    /// C'est celle que `save` doit retrouver pour la mettre à jour. Chercher « la plus
    /// récente de même signature » y créait un doublon : si l'intégrée était la plus récente
    /// — et elle l'est, puisqu'elle arrive par une mise à jour de l'app ou par une fusion
    /// CloudKit — `save` insérait un second enregistrement personnel à chaque appel.
    public static func personal(signature: String, inLibrary libraryID: UUID) -> Predicate<ImportMapping> {
        #Predicate<ImportMapping> {
            $0.headerSignature == signature && $0.library?.id == libraryID && $0.isBuiltIn == false
        }
    }

    public static func inLibrary(_ libraryID: UUID) -> Predicate<ImportMapping> {
        #Predicate<ImportMapping> { $0.library?.id == libraryID }
    }
}
