import Foundation

/// Rend une clause de prédicat inopérante quand son critère n'est pas actif.
///
/// **Pourquoi ce détour existe.** `#Predicate` ne peut pas porter plus de cinq
/// clauses sur un `@Model` SwiftData. Ce n'est pas une opinion : c'est mesuré, et
/// la mesure est reproductible avec
/// `-Xfrontend -warn-long-expression-type-checking`. Sur `Title`, une chaîne de
/// clauses coûte, en vérification de types :
///
/// | Clauses | Coût | Résultat |
/// |---|---|---|
/// | 4 | < 200 ms | passe |
/// | 5 | 1 328 ms | passe, déjà lent |
/// | 6 | 10 503 ms | **échoue** |
/// | 12 | 30 012 ms | **échoue** |
///
/// La cause n'est ni le nombre de clauses en soi, ni les traversées de relation
/// optionnelle — deux hypothèses testées et écartées. C'est que la macro doit
/// tenir dans **une seule expression** : l'inférence porte alors sur un arbre
/// générique `PredicateExpressions` de douze niveaux d'un coup, et son coût
/// explose. Un arbre équilibré n'y change rien (22 865 ms, échoue), et le modèle
/// `@Model` aggrave le tout — les mêmes douze clauses sur un `struct` nu passent
/// en moins de 200 ms.
///
/// **La sortie.** Construire le même arbre à la main, en le coupant par des `let`
/// intermédiaires. Chaque `let` est un problème d'inférence indépendant et
/// minuscule ; l'arbre final ne fait plus qu'assembler des types déjà connus. Ce
/// que la macro ne peut pas faire, parce qu'une macro d'expression n'a pas droit
/// aux instructions. Douze clauses passent alors sous les 200 ms — mesuré aussi.
///
/// **Ce que ça n'est pas.** Ce n'est pas un contournement de SQL : l'arbre produit
/// est exactement celui que `#Predicate` aurait expansé, avec les mêmes nœuds
/// `build_*`. SwiftData le traduit donc de la même façon, et `TitlePredicateTests`
/// le vérifie par le magasin.
///
/// ---
///
/// ## Le pari, et pourquoi il est tenable
///
/// **C'est l'endroit le plus fragile du dépôt, et il faut le savoir avant d'y
/// toucher.** Les fonctions `PredicateExpressions.build_*` sont l'interface que la
/// macro `#Predicate` utilise pour émettre son arbre. Leur nommage le dit : `build_`
/// n'est pas une convention d'API publique, c'est une convention de code généré.
/// Elles sont `public` parce qu'une macro doit pouvoir les appeler depuis le module
/// client, pas parce qu'on est invité à les écrire à la main. Une mise à jour de
/// Foundation peut en changer la forme sans que ce soit une rupture au sens d'Apple.
///
/// **Pourquoi on le fait quand même.** Il n'y a pas d'alternative. `#Predicate`
/// plafonne à cinq clauses sur un `@Model` (tableau ci-dessus), et une macro
/// d'expression doit tenir dans **une seule expression** : elle n'a pas droit aux
/// instructions, donc pas aux `let` intermédiaires qui découpent l'inférence. Le
/// choix n'est pas « macro ou arbre manuel », c'est « arbre manuel ou filtrage en
/// mémoire du catalogue entier ». Le second était l'état d'avant `L1`, et c'est ce
/// que `L1` avait pour objet de supprimer.
///
/// **Pourquoi le risque d'API est acceptable.** Une disparition ou un changement de
/// signature de ces fonctions **ne compile pas**. C'est un échec bruyant, immédiat,
/// et localisé dans trois fichiers (celui-ci, `TitleFilter`, `PersonFilter`). Un
/// échec de compilation au premier build après une mise à jour de Xcode est le
/// meilleur mode de défaillance qu'on puisse souhaiter pour un pari de ce genre.
///
/// **Le vrai risque n'est pas là.** C'est que SwiftData cesse de **reconnaître** la
/// forme de l'arbre et retombe sur une évaluation en mémoire : le code compile, les
/// tests de critères restent verts — ils vérifient *quels* titres sortent, pas *où*
/// le filtrage a eu lieu — et l'app se remet silencieusement à rapatrier cinq mille
/// lignes pour les filtrer en Swift. Aucune erreur, aucun avertissement. Exactement
/// la forme de défaillance qui a déjà coûté 42 tests verts sur une grille vide.
///
/// Ce qui l'attrape est **un seul test** :
///
///   `TitleFilterPerformanceTests.selectiveFilterDoesNotScanEverything`
///
/// Il compare une requête sélective à une requête sans filtre sur 5 000 titres.
/// Mesuré : 5,3 ms contre 248 ms, un rapport de 46. Si le filtrage repassait en
/// mémoire, les deux matérialiseraient les mêmes 5 000 objets et le rapport
/// tomberait à 1. C'est un test de *forme*, pas de vitesse — c'est pour ça que son
/// seuil est un rapport et non une durée.
///
/// **Donc : ne pas modifier cet arbre, ni celui de `TitleFilter` ou de
/// `PersonFilter`, sans que ce test tourne.** Le supprimer parce qu'il « mesure des
/// performances » reviendrait à retirer le seul garde-fou d'une construction dont
/// tous les autres tests peuvent rester verts alors qu'elle a cessé de fonctionner.
///
/// - Parameters:
///   - active: `false` neutralise la clause — la disjonction devient vraie côté
///     SQL, sans que la clause ait à être satisfaite.
///   - clause: la clause à garder.
/// - Returns: la clause gardée, prête à entrer dans une conjonction.
public func predicateClause<Expression: StandardPredicateExpression<Bool>>(
    active: Bool,
    _ clause: Expression
) -> PredicateExpressions.Disjunction<PredicateExpressions.Value<Bool>, Expression> {
    PredicateExpressions.build_Disjunction(
        lhs: PredicateExpressions.build_Arg(active == false),
        rhs: clause
    )
}
