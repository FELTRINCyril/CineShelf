import SwiftUI

// MARK: - I4 · Le rail horizontal
//
// Relevé sur la planche 1 bloc `2a` (le rail qui affleure en bas du hero), et confirmé
// à l'identique sur la planche 3 blocs `4b` et `4f` (casting, galerie du titre) :
//
//     <div style="display:flex;flex-direction:column;gap:10px">
//       <span style="font:700 12px/1 'Archivo Narrow';letter-spacing:0.12em;
//                    text-transform:uppercase;padding:0 44px">Ajoutés cette semaine</span>
//       <div style="display:flex;gap:14px;padding:0 0 0 44px">…</div>
//     </div>
//
// **La gouttière de 14 px est une mesure par point de rupture, pas de densité.** L'addendum
// 2 rend les mêmes rails en iPhone 393 (10 px) et en iPad 834 (14 px) : trois formats
// d'accord entre eux, et aucun ne suit `Density.baseGridGutter`. C'était l'écart 3 de la
// revue du 2026-08-04 — la gouttière passe par `Breakpoint.railGutter`.
//
// **Le relevé qui décide de tout est `padding: 0 0 0 44px`** — une marge à gauche, et
// *aucune à droite*. La dernière carte est donc coupée par le bord du cadre, et c'est
// voulu : le §7 du handoff en fait le seul signal de défilement.
//
// > Défilement horizontal : signalé uniquement par la carte coupée au bord droit.
// > Ni flèche, ni dégradé, ni pagination.
//
// Ce que ça interdit, et qui existe pourtant à côté : le rail de l'ancienne direction
// (`Components/ShelfRail.swift`) pose sous la rangée un filet avec un compteur
// « 01–08 / 24 » et une portion visible en accent. C'est de la pagination déguisée.
// `ShelfRailModel.counter(visible:)` et `.progress(visible:)` ne sont donc plus appelés
// par personne dès ce lot — ils partent avec `Legacy/` à `V12`, où c'est inscrit.

/// Une rangée horizontale de tuiles, précédée de son libellé.
///
/// Générique sur son contenu : le rail ne sait pas ce qu'il porte, et c'est ce qui lui
/// permet d'accueillir aussi bien `PosterTile` que `PersonTile`, `CollectionTile`,
/// `GalleryThumb` ou `TileSkeleton`. Un rail par type aurait dupliqué la marge
/// asymétrique — donc le seul détail qui porte la direction.
public struct TileRail<Content: View>: View {
    private let label: LocalizedStringKey
    private let action: RailAction?
    private let content: Content

    // Pas de `\.density` ici : la gouttière du rail est une mesure par point de rupture,
    // et le rail n'a aucune autre raison de lire la densité.
    @Environment(\.breakpoint) private var breakpoint

    /// Une action facultative en bout de libellé — « Tout voir », le plus souvent.
    public struct RailAction {
        let label: LocalizedStringKey
        let perform: () -> Void

        public init(_ label: LocalizedStringKey, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    public init(
        _ label: LocalizedStringKey,
        action: RailAction? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.action = action
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            header
            row
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text(label)
                .labelStyle()
                .foregroundStyle(Color.textPrimary)
            if let action {
                Spacer(minLength: Space.s4)
                Button(action.label, action: action.perform)
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: Space.minHitTarget)
            }
        }
        // Le libellé prend la marge d'écran des deux côtés. Seule la **rangée** est
        // asymétrique : un libellé coupé par le bord serait une faute, pas un signal.
        .padding(.horizontal, breakpoint.screenMargin)
    }

    private var row: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: gutter) {
                content
            }
            // La marge de gauche seulement. Aucune à droite : la carte coupée au bord
            // est le signal de défilement, et un `padding` symétrique l'effacerait en
            // ménageant une fin propre.
            .padding(.leading, breakpoint.screenMargin)
        }
        // Ni flèche, ni dégradé, ni pagination — et la barre de défilement système est
        // l'un des trois. Sur macOS elle est déjà transitoire ; la masquer aligne les
        // deux plateformes sur le même signal unique.
        .scrollIndicators(.hidden)
        // Sans quoi le grossissement au survol de la tuile est rogné par la ScrollView.
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// La gouttière du cran courant — 10 pt sur iPhone, 14 pt au-delà.
    ///
    /// Elle ne passe **pas** par `gridGutter(_:)` : trois formats rendus s'accordent sur
    /// une mesure par point de rupture, et aucun ne suit la densité. Voir
    /// `Breakpoint.railGutter`, qui porte le relevé.
    private var gutter: CGFloat { breakpoint.railGutter }
}

// MARK: - Le cran de rupture courant
//
// Le rail et la grille ont tous deux besoin de la marge d'écran et de la gouttière du
// cran courant. Les faire mesurer chacun de leur côté produirait deux réponses
// différentes dans la même fenêtre — l'un mesurant sa propre largeur, l'autre celle de
// son conteneur. Le cran se pose donc **une fois**, au niveau de l'écran, comme la
// densité.

extension EnvironmentValues {
    /// Le cran de rupture de la fenêtre courante.
    ///
    /// Posé par `.breakpoint(forWidth:)` sur la vue racine d'un écran. Sa valeur par
    /// défaut vaut pour les previews et le catalogue, où aucun écran ne l'a posé.
    @Entry public var breakpoint: Breakpoint = .macStandard
}

extension View {
    /// Pose le cran de rupture qui correspond à une largeur de fenêtre.
    public func breakpoint(forWidth width: CGFloat) -> some View {
        environment(\.breakpoint, .forWidth(width))
    }
}

// MARK: - Previews

#Preview("Rail · la dernière carte est coupée") {
    VStack(alignment: .leading, spacing: Space.s6) {
        TileRail("Ajoutés cette semaine") {
            ForEach(PosterCardModel.samples) { item in
                PosterTile(item, scale: .l) {}
            }
        }
        TileRail("Documentaires", action: .init("Tout voir") {}) {
            ForEach(PosterCardModel.samples) { item in
                PosterTile(item, layout: .landscape, scale: .l) {}
            }
        }
    }
    .padding(.vertical, Space.s6)
    .frame(width: 720, alignment: .leading)
    .background(Color.bgCanvas)
}
