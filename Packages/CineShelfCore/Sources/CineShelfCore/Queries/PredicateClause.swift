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
/// `build_*`. SwiftData le traduit donc de la même façon, et
/// `TitleFilterTests` le vérifie par le magasin.
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
