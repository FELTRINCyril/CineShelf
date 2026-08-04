import DesignSystem
import SwiftUI

/// Disposition régulière (Mac, iPad) — planche 2 blocs `3a` et `3b`.
///
/// **Barre horizontale en haut, contenu plein cadre, inspecteur à droite.** Pas de
/// `NavigationSplitView` : la direction retenue n'a **pas** de barre latérale, et le bloc
/// `3b` le dit dans sa légende. C'est le changement le plus structurel de `V0`, et il a
/// coûté `Sidebar.swift`.
///
/// L'inspecteur, lui, reste : il est bien rendu, en colonne à droite au-dessus de
/// 1024 pt. `Breakpoint.showsInspectorAsColumn` porte cette règle.
struct RegularRootView: View {
    @Environment(NavigationModel.self) private var navigation

    @State private var isScrolled = false

    var body: some View {
        @Bindable var navigation = navigation

        NavigationStack(path: navigation.pathBinding(for: .section(navigation.section))) {
            sectionContent
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
        // La barre est posée en `safeAreaInset` et non en `overlay` : le contenu doit
        // pouvoir passer **sous** elle quand elle est transparente — c'est tout l'effet du
        // hero plein cadre — mais garder sa hauteur réservée quand elle devient opaque.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopNavigationBar(isScrolled: isScrolled)
        }
        .background(Color.bgCanvas)
        .inspector(isPresented: $navigation.isInspectorPresented) {
            RouteInspector(route: navigation.path(for: navigation.section).last)
        }
    }

    /// Le contenu de la section, avec son en-tête d'écran et son capteur de défilement.
    private var sectionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s5) {
                ScreenHeader(section: navigation.section)
                navigation.section.destination
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.s8)
        }
        .reportsScrollOffset(to: $isScrolled)
        .scrollContentBackground(.hidden)
        .background(Color.bgCanvas)
    }
}

// MARK: - L'en-tête d'écran
//
// Relevé sur la planche 2 bloc `3a`, « Barre d'outils d'écran — Titres (Mac / iPad) » :
// un titre en Bebas, un compte en capitales à côté, et les actions alignées à droite —
// Trier, Filtres, Affichage, Sélectionner, ＋ Nouveau.
//
// **Les actions ne sont pas branchées ici, et c'est volontaire.** Elles appartiennent aux
// écrans qui les portent (`V0 bis` pour Titres, `V3` pour la galerie), et un menu « Trier »
// posé par le chrome trierait quoi ? L'en-tête rend donc le titre, et laisse l'écran
// remplir le reste. Poser des menus inertes ici serait la version chrome du code
// « au cas où ».

struct ScreenHeader: View {
    let section: AppSection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text(section.title)
                .title1Style()
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: Space.s4)
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        .padding(.top, Space.s4)
    }
}
