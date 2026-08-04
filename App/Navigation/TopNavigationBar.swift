import DesignSystem
import SwiftUI

// MARK: - V0 · La barre de navigation régulière
//
// Relevée sur la planche 2 bloc `3a` (Mac) et `3b` (iPad), qui portent la même barre :
//
//     <div style="height:60px;display:flex;align-items:center;gap:30px;padding:0 40px">
//       <span style="font:400 22px 'Bebas Neue';letter-spacing:0.14em;
//                    color:oklch(0.84 0.14 66)">CINESHELF</span>
//       <span style="font:600 12px 'Archivo Narrow';…;color:oklch(0.98 0 0)">Accueil</span>
//       <span …>Titres</span> … <span style="margin-left:auto">Rechercher ⌘K</span>
//     </div>
//
// **Il n'y a pas de barre latérale, et ce n'est pas un oubli du prototype.** Le bloc `3b`
// le dit dans sa légende : « même navigation régulière, **sans barre latérale** ». Le
// tableau des points de rupture du §4.6 en annonce pourtant une à quatre crans sur six ;
// c'est un résidu, comme sa colonne « Colonnes », et douze écrans rendus le contredisent.
// `Sidebar.swift` a été supprimée par `V0`. L'écart est inscrit dans `docs/PROMPTS.md`.
//
// **Le comportement au défilement est la seule animation de la barre** : fond nul en tête
// de page, `bg.canvas` opaque dès qu'on défile, transition `dur.base`. Aucune
// translucidité, aucun matériau — le §7 l'interdit explicitement, et c'est ce qui
// distingue cette barre de celle d'une app système.

struct TopNavigationBar: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La hauteur du prototype (planche 2 bloc `3a`). Publiée parce que les écrans qui ne
    /// passent **pas** sous la barre doivent s'en décaler eux-mêmes : elle est posée en
    /// `overlay`, pas en `safeAreaInset`.
    static let height: CGFloat = 60

    /// `true` dès que le contenu a défilé sous la barre.
    let isScrolled: Bool

    var body: some View {
        HStack(spacing: Space.s6) {
            logotype
            sections
            Spacer(minLength: Space.s4)
            searchEntry
            SyncIndicator()
            ProfileMenu()
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        .frame(height: Self.height)
        .background(isScrolled ? Color.bgCanvas : Color.clear)
        .dsAnimation(Motion.base, value: isScrolled)
    }

    /// Le mot CINESHELF en Bebas ambre. À partir d'une taille d'accessibilité, il perd son
    /// allure de logotype — le handoff l'annonce (§4.2) et l'accepte ; le transformer en
    /// image est une piste, pas une décision prise.
    private var logotype: some View {
        Text("CINESHELF")
            .font(Typo.title2(dynamicTypeSize))
            .tracking(Typo.Size.title2 * 0.14)
            .foregroundStyle(Color.accent)
            .accessibilityAddTraits(.isHeader)
    }

    /// Les six sections de la barre. `Signets` n'y est pas : le prototype ne la montre
    /// pas, elle vit dans le menu de profil.
    private var sections: some View {
        HStack(spacing: Space.s5) {
            ForEach(AppSection.navigationBar) { section in
                Button {
                    navigation.section = section
                } label: {
                    Text(section.title)
                        .actionStyle()
                        .foregroundStyle(tint(for: section))
                        .frame(minHeight: Space.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == navigation.section ? .isSelected : [])
            }
        }
    }

    /// Blanc pour la section courante, gris pour les autres — le prototype ne pose ni
    /// soulignement ni pastille, seule la valeur de gris distingue l'active.
    private func tint(for section: AppSection) -> Color {
        section == navigation.section ? Color.textPrimary : Color.textSecondary
    }

    /// « Rechercher ⌘K » — le raccourci est **affiché**, et il est réellement enregistré
    /// par la barre de menus. Une mention de raccourci qui ne marche pas est pire que pas
    /// de mention.
    private var searchEntry: some View {
        Button {
            navigation.section = .search
        } label: {
            HStack(spacing: Space.s2) {
                Text(AppSection.search.title)
                    .actionStyle()
                    .foregroundStyle(Color.textSecondary)
                #if os(macOS)
                    Text(verbatim: "⌘K")
                        .font(Typo.micro)
                        .foregroundStyle(Color.textTertiary)
                #endif
            }
            .frame(minHeight: Space.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Le fond qui suit le défilement
//
// Mesurer le défilement d'une `ScrollView` sans lui imposer de coordonnées : un capteur
// de hauteur nulle posé en tête du contenu, dont on lit la position dans l'espace de la
// barre. Au-dessus de zéro, on a défilé.

extension View {
    /// Signale à la barre que ce contenu a défilé sous elle.
    func reportsScrollOffset(to isScrolled: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 0
        } action: { _, scrolled in
            isScrolled.wrappedValue = scrolled
        }
    }
}
