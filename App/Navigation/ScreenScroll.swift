import SwiftUI

/// Le conteneur défilant d'un écran **poussé**, et le seul endroit qui sait se rendre plat.
///
/// **Pourquoi ce type existe, et pourquoi il n'est pas du confort.** `ImageRenderer` ne sait
/// pas mettre en page un `ScrollView` : mesuré le 2026-08-06, un `ScrollView { Text("…") }`
/// rend **une seule couleur** là où le même texte nu en rend trois — donc un aplat, donc
/// exactement ce qu'une porte de non-vacuité cherche à attraper. Aucun contournement au niveau
/// de l'enveloppe ne marche : `.fixedSize`, `.scrollDisabled`, `.clipped`, hauteur libre ou
/// imposée rendent tous un aplat. La limite est dans le rendu, pas dans l'appel.
///
/// Sans ce type, **tout écran défilant est hors de portée de la sonde** — et ce sont
/// précisément les écrans denses, là où « ça rend du vide » coûte le plus cher.
///
/// **Ce qu'il ne faut pas en faire.** Il n'est **pas** le conteneur des écrans de section :
/// celles-ci vivent déjà dans le `ScrollView` de `RegularRootView`, et en ajouter un second y
/// serait un défilement imbriqué. Il est pour les écrans poussés par
/// `navigationDestination`, qui sont **hors** de ce conteneur — les fiches.
///
/// La bascule ne change ni les données, ni la géométrie, ni les couleurs : elle retire le
/// défilement, que la sonde ne peut de toute façon pas exercer.
struct ScreenScroll<Content: View>: View {
    @Environment(\.rendersFlat) private var rendersFlat

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if rendersFlat {
            content
        } else {
            ScrollView { content }
        }
    }
}

extension EnvironmentValues {
    /// Rendre sans défilement. **Posé par la sonde de rendu, jamais par l'app.**
    ///
    /// Une valeur d'environnement plutôt qu'un paramètre : la sonde la pose une fois sur la
    /// racine, et tout écran de la hiérarchie la reçoit. Un paramètre aurait demandé à chaque
    /// écran de le transmettre, donc à chacun de pouvoir l'oublier.
    @Entry var rendersFlat = false
}
