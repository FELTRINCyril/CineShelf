import SwiftUI

// MARK: - I5 · La ligne de tableau
//
// Relevée sur la planche 5 bloc `7a` :
//
//     <span style="display:flex;align-items:center;height:30px;padding:0 18px;
//                  font:400 12px/1 'Archivo Narrow';color:oklch(0.88 0 0);
//                  border-bottom:1px solid oklch(1 0 0 / 0.05)"
//           style-hover="background:oklch(1 0 0 / 0.05)">
//
// **Le composant porte la géométrie, l'écran porte les colonnes.** C'est la règle du dépôt, et
// elle est plus tranchante ici qu'ailleurs : les colonnes de la console changent d'une entité
// à l'autre — un titre a une année et une durée, une personne a une date de naissance et un
// nombre de crédits. Une ligne qui connaîtrait ses colonnes serait à réécrire à chaque entité.
//
// Ce que la ligne possède : la **hauteur** par densité, la marge, le séparateur, le survol, la
// sélection, et l'alignement vertical. Ce que l'écran fournit : des cellules, posées avec
// `.tableCell(width:alignment:)` — un modificateur du package, pour que les largeurs se
// composent de la même façon dans l'en-tête et dans le corps.
//
// **`dur.instant` sur la sélection**, et le §7 le dit en toutes lettres : « Sélection dans un
// tableau dense : `dur.instant`, aucune animation. » Une ligne qui s'anime dans une liste
// qu'on parcourt au clavier traîne derrière le curseur.

/// Une ligne de tableau de gestion.
public struct TableRow<Content: View>: View {
    private let isSelected: Bool
    private let isHeader: Bool
    private let action: (() -> Void)?
    private let content: Content

    @Environment(\.density) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    /// - Parameters:
    ///   - isSelected: pose le fond de sélection et la barre d'accent.
    ///   - isHeader: la ligne de titres de colonnes. Plus basse, sans séparateur bas, inerte.
    ///   - action: `nil` rend la ligne inerte — ni survol, ni focus.
    ///   - content: les cellules, dans l'ordre des colonnes.
    public init(
        isSelected: Bool = false,
        isHeader: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isHeader = isHeader
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 0) {
                content
            }
            .padding(.horizontal, ConsoleMetrics.horizontalPadding)
            .frame(height: height, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(alignment: .leading) { selectionBar }
            .overlay(alignment: .bottom) { separator }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isHovering = $0 }
        .focusable(action != nil)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var height: CGFloat {
        isHeader ? ConsoleMetrics.headerHeight : ConsoleMetrics.rowHeight(density)
    }

    /// **Aucune animation, quel que soit le réglage d'accessibilité.**
    ///
    /// `reduceMotion` n'a rien à retirer ici : il n'y a déjà rien à réduire. La propriété est
    /// lue quand même pour que le compilateur signale toute animation qu'on ajouterait sans y
    /// penser — et pour que la raison soit écrite à l'endroit où la tentation se présente.
    private var background: Color {
        if isHeader { return Color.bgSurface }
        if isSelected { return Color.bgFill }
        return isHovering && action != nil ? Color.bgFill.opacity(0.5) : Color.clear
    }

    /// La barre d'accent d'une ligne sélectionnée.
    ///
    /// **Aucun bloc ne rend une ligne sélectionnée** — le bloc `7a` annonce « 1 sélectionnée »
    /// dans son en-tête sans qu'on voie laquelle. Le fond seul ne suffirait pas : il est déjà
    /// celui du survol, donc « sélectionnée » et « sous le curseur » seraient indistinguables,
    /// et c'est exactement le motif « deux états qui rendent la même chose ». La barre les
    /// sépare. Écart inscrit : c'est une déduction, pas un relevé.
    @ViewBuilder private var selectionBar: some View {
        if isSelected {
            Color.accent.frame(width: Stroke.emphasis)
        }
    }

    @ViewBuilder private var separator: some View {
        if !isHeader {
            Color.separatorLine.frame(height: Stroke.hairline)
        }
    }
}

// MARK: - Les cellules

extension View {

    /// Pose une cellule à largeur fixe dans une ligne de tableau.
    ///
    /// **Le même modificateur pour l'en-tête et pour le corps**, et c'est tout l'intérêt : les
    /// deux se composent avec les mêmes largeurs, donc les colonnes tombent l'une sous l'autre
    /// sans que personne ait à additionner des marges. Le prototype le fait à la main, avec un
    /// `box-sizing:border-box` répété sur chaque cellule — c'est précisément ce qu'un
    /// modificateur évite d'oublier.
    ///
    /// - Parameters:
    ///   - width: `nil` laisse la cellule prendre la place restante. C'est la colonne
    ///     principale — le titre dans le bloc `7a`, `flex:1 1 200px`.
    ///   - alignment: `.trailing` pour les nombres, `.leading` pour le texte. Le prototype
    ///     aligne à droite l'année, la durée, la note et la date d'ajout.
    /// - Returns: la cellule, prête à être posée dans une `TableRow`.
    public func tableCell(
        width: CGFloat? = nil, alignment: Alignment = .leading
    ) -> some View {
        frame(maxWidth: width ?? .infinity, alignment: alignment)
            .frame(width: width, alignment: alignment)
            .padding(.trailing, Space.s3)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Previews

#Preview("Ligne de tableau · dense et ample") {
    VStack(alignment: .leading, spacing: Space.s6) {
        ForEach([Density.dense, .roomy], id: \.self) { density in
            VStack(spacing: 0) {
                TableRow(isHeader: true) {
                    Text("Titre").tableCell()
                    Text("Année").tableCell(width: 56, alignment: .trailing)
                }
                TableRow(
                    action: {},
                    content: {
                        Text("Dune").tableCell()
                        Text(verbatim: "2021").tableCell(width: 56, alignment: .trailing)
                    })
                TableRow(
                    isSelected: true, action: {},
                    content: {
                        Text("Oppenheimer").tableCell()
                        Text(verbatim: "2023").tableCell(width: 56, alignment: .trailing)
                    })
            }
            .environment(\.density, density)
            .frame(width: 420)
            .background(Color.bgInset)
        }
    }
    .padding(Space.s6)
    .background(Color.bgCanvas)
}
