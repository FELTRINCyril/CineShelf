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
        // **En `overlay`, pas en `safeAreaInset`.** Corrigé par `V5a` : un `safeAreaInset`
        // *réserve* la hauteur de la barre, donc l'image du hero ne pouvait pas passer
        // dessous — il restait une bande noire au-dessus, et le « plein cadre bord à bord »
        // de la direction disparaissait. En `overlay`, l'écran décide : l'accueil et la
        // fiche passent dessous, les écrans à en-tête se décalent de `TopNavigationBar
        // .height` par `ScreenHeader`.
        .overlay(alignment: .top) {
            TopNavigationBar(isScrolled: isScrolled)
        }
        .background(Color.bgCanvas)
        .inspector(isPresented: $navigation.isInspectorPresented) {
            RouteInspector(route: navigation.path(for: navigation.section).last)
        }
    }

    /// Le contenu de la section, avec son en-tête d'écran et son capteur de défilement.
    private var sectionContent: some View {
        // **L'en-tête n'est pas posé ici, il est posé par l'écran.** Le poser au niveau du
        // chrome donnerait deux en-têtes à tout écran qui a des actions — la grille des
        // titres, la galerie — et forcerait un drapeau « celui-ci a le sien ».
        // `ScreenHeader` reste un composant du chrome ; c'est son *placement* qui
        // appartient à l'écran.
        ScrollView {
            navigation.section.destination
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
// Relevé sur la planche 2 bloc `3a` et la planche 3 bloc `4a`, « Barre d'outils d'écran —
// Titres » : un titre en Bebas 44 pt, un compte en capitales posé sur sa ligne de base, et
// les actions alignées à droite — Trier, Filtres, Affichage, Sélectionner, ＋ Nouveau.
//
// **Le chrome porte la forme, l'écran porte les actions.** `V0` avait laissé l'emplacement
// vide en écrivant qu'un menu « Trier » posé par le chrome trierait quoi ; `V0 bis` ouvre
// cet emplacement plutôt que d'ajouter une seconde barre dans la grille. C'est ce qui
// garantit que Titres, Personnes et Collections auront le même en-tête sans que personne
// n'ait à le recopier.

struct ScreenHeader<Actions: View>: View {
    private let title: String
    private let count: String?
    private let actions: Actions

    init(section: AppSection, count: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = section.title
        self.count = count
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text(title)
                .title1Style()
                .foregroundStyle(Color.textPrimary)

            if let count {
                Text(count)
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: Space.s4)
            actions
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        // La barre étant en `overlay`, c'est l'en-tête qui se décale. Les écrans qui
        // passent volontairement sous elle — l'accueil, la fiche — n'utilisent pas
        // `ScreenHeader` et ne paient donc pas ce décalage.
        .padding(.top, TopNavigationBar.height + Space.s4)
    }
}

extension ScreenHeader where Actions == EmptyView {
    /// L'en-tête d'un écran qui n'a pas encore d'actions — la plupart, jusqu'à leur `V`.
    init(section: AppSection, count: String? = nil) {
        self.init(section: section, count: count) { EmptyView() }
    }
}
