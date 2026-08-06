import Foundation

// MARK: - L14 · Ce que le profil actif a le droit de voir
//
// **C'est la seule partie de `L14` à rigueur maximale**, et la raison tient en une phrase :
// un contenu marqué privé qui s'affiche dans un profil qui ne devrait pas le voir ne se
// répare pas. On ne peut pas « défaire » le fait que quelqu'un l'a vu.
//
// **Le défaut de forme que ce type corrige.** Neuf écrans écrivaient
// `session.current?.hidesPrivateContent ?? false`, c'est-à-dire : **en l'absence de profil,
// montrer le contenu privé**. Le repli va dans le mauvais sens. Il n'est pas atteignable
// aujourd'hui — `RootView` affiche le sélecteur de profil tant que `current` est `nil`, donc
// aucun écran de catalogue ne se rend — mais c'est un invariant tenu **à distance**, par un
// `if` dans un autre fichier, et rien ne le rappelle au dixième écran qu'on écrira.
//
// Un repli sûr ne dépend de personne. Ici, l'absence de réponse vaut « masque ».

/// Ce que le contexte courant autorise à voir.
///
/// **Un type et non un `Bool`.** Un booléen nu se passe dans le mauvais sens sans que rien ne
/// proteste — `hidingPrivate: false` et `hidingPrivate: true` compilent aussi bien, et la
/// moitié des appelants du dépôt le nommaient `hidesPrivate`, l'autre `hidingPrivate`. Un type
/// nommé rend l'inversion visible à la lecture et donne un seul endroit où écrire la règle.
public struct PrivacyScope: Sendable, Equatable {

    /// Les entités `isPrivate` doivent-elles être écartées des requêtes ?
    public let hidesPrivateContent: Bool

    private init(hidesPrivateContent: Bool) {
        self.hidesPrivateContent = hidesPrivateContent
    }

    /// **Le repli, et il masque.** Aucun profil résolu, aucune décision prise, aucun doute :
    /// on ne montre pas. C'est la valeur qu'obtient tout appelant qui n'a rien à dire.
    public static let masked = PrivacyScope(hidesPrivateContent: true)

    /// La portée d'un profil, à un état de verrou donné.
    ///
    /// **Trois raisons de masquer, et elles s'additionnent** — il suffit d'une seule :
    ///
    /// 1. **Aucun profil actif.** Le sélecteur n'a pas tranché : personne n'a demandé à voir
    ///    quoi que ce soit.
    /// 2. **Le profil exige une authentification et l'app est verrouillée.**
    ///    `Profile.requiresBiometry` était « affiché mais jamais appliqué » — c'est l'écart que
    ///    la fiche de `L14` nomme, et c'est ici qu'il se ferme. Sans cette clause, le réglage
    ///    serait un interrupteur qui ne fait rien, ce qui est pire que pas de réglage : il
    ///    donne une confiance qu'il ne mérite pas.
    /// 3. **Le profil masque le contenu privé.** Le réglage explicite, indépendant du verrou —
    ///    un profil « Invité » masque même quand l'app est déverrouillée.
    ///
    /// - Parameters:
    ///   - profile: le profil actif, ou `nil` si le sélecteur n'a pas tranché.
    ///   - isUnlocked: l'app a-t-elle été déverrouillée dans cette session.
    /// - Returns: la portée à passer aux requêtes. Masquée au moindre doute.
    public static func resolve(profile: Profile?, isUnlocked: Bool) -> PrivacyScope {
        guard let profile else { return .masked }
        if profile.requiresBiometry, !isUnlocked { return .masked }
        return PrivacyScope(hidesPrivateContent: profile.hidesPrivateContent)
    }

    /// La portée d'un profil hors de tout verrou — pour les chemins qui n'ont pas d'`AppLock`.
    ///
    /// **Existe pour l'import, l'archive et Spotlight**, qui tournent sans interface. Ils ne
    /// peuvent pas être « déverrouillés » et n'ont pas à l'être : ce sont des traitements, pas
    /// des affichages. Nommée explicitement pour qu'un écran ne l'appelle pas par mégarde en
    /// croyant appeler `resolve`.
    public static func unlockedSession(profile: Profile?) -> PrivacyScope {
        resolve(profile: profile, isUnlocked: true)
    }
}
