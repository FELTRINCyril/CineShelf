import DesignSystem
import SwiftUI

// Les trois composants de `I4`. Ce sont eux qui portent la mise en page, donc ce sont
// eux qu'on ne peut pas juger sur une capture : il faut redimensionner.
//
// Ce qu'on vient vérifier ici, et qui ne se voit pas dans un test :
//
// - que la **dernière carte du rail est coupée** par le bord, et qu'aucun dégradé,
//   aucune flèche, aucun compteur ne vient l'expliquer — c'est le seul signal de
//   défilement de la direction ;
// - que le libellé du rail, lui, n'est **pas** coupé : seule la rangée est asymétrique ;
// - que la grille perd et regagne des colonnes à largeur de carte constante, sans que
//   la carte change jamais de taille ;
// - que le squelette occupe **exactement** la place de la tuile qu'il remplace, donc
//   qu'aucune ligne ne bouge au moment où l'image arrive.

struct LayoutSheet: View {
    private static let widths: [CGFloat] = [393, 834, 1280]

    var body: some View {
        Sheet(
            "Rail · Grille · Squelette · I4",
            note: """
                Le lot qui porte la mise en page. Le nombre de colonnes n'est jamais \
                déclaré : la largeur de carte est fixe, la grille prend ce qui rentre.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                rails
                grids
                skeletons
            }
        }
    }

    private var rails: some View {
        section(
            "Rail horizontal",
            note: """
                Marge d'écran à gauche, aucune à droite : la carte coupée par le bord est \
                le seul signal de défilement. Ni flèche, ni dégradé, ni pagination — et \
                pas non plus le filet compteur de l'ancien `ShelfRail`, qui était de la \
                pagination déguisée.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                framed(720) {
                    TileRail("Ajoutés cette semaine") {
                        ForEach(PosterCardModel.artworkSamples) { item in
                            PosterTile(item, scale: .l) {}
                        }
                    }
                }
                framed(720) {
                    TileRail("Documentaires", action: .init("Tout voir") {}) {
                        ForEach(PosterCardModel.artworkSamples) { item in
                            PosterTile(item, layout: .landscape, scale: .l) {}
                        }
                    }
                }
                framed(720) {
                    TileRail("Casting") {
                        ForEach(PosterCardModel.people) { person in
                            PersonTile(person, scale: .m) {}
                        }
                    }
                }
                BlockNote(.tileRail)
            }
        }
    }

    private var grids: some View {
        section(
            "Grille adaptative",
            note: """
                Les trois largeurs, à `poster.l`. Les deux premières sont celles que \
                l'addendum 2 a rendues pour de vrai — 393 px donnent 2 colonnes, 834 px \
                en donnent 4 — et ce sont les seules que le design vérifie.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                ForEach(Self.widths, id: \.self) { width in
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text(verbatim: "\(Int(width)) pt · \(columnCount(width)) colonnes")
                            .font(Typo.micro)
                            .foregroundStyle(.textTertiary)
                        framed(width) {
                            AdaptiveTileGrid(
                                PosterCardModel.artworkSamples, cardWidth: PosterScale.l.width
                            ) {
                                PosterTile($0, scale: .l) {}
                            }
                        }
                    }
                }
                BlockNote(.adaptiveTileGrid)
            }
        }
    }

    private var skeletons: some View {
        section(
            "Squelette de chargement",
            note: """
                Géométrie finale exacte, ratio réservé, aucun balayage. Il n'a pas de \
                conteneur à lui : c'est le rail et la grille qui le portent, sinon il \
                dériverait de la mise en page qu'il est censé réserver. La couleur \
                dominante de l'image viendra avec son producteur, à `L5`.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                framed(720) {
                    TileRail("Ajoutés cette semaine") {
                        ForEach(0..<8, id: \.self) { _ in
                            TileSkeleton(scale: .l)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Space.s3) {
                    SkeletonBar(width: 180, height: Space.s3)
                    SkeletonBar(width: 430, height: Space.s8 + Space.s7)
                    HStack(spacing: Space.s3) {
                        SkeletonBar(width: 54)
                        SkeletonBar(width: 64)
                        SkeletonBar(width: 110)
                    }
                }
                .padding(Space.s4)
                .background(.bgInset)
                BlockNote(.tileSkeleton)
            }
        }
    }

    // MARK: - Habillage

    /// La densité que la plateforme de cette largeur poserait : ample sous 1024, dense
    /// au-delà. C'est le défaut de plateforme, pas un réglage de la grille.
    private func density(_ width: CGFloat) -> Density {
        width >= Breakpoint.padLandscape.minWidth ? .dense : .roomy
    }

    /// Le compte affiché en légende — le même appel que celui que la grille fait.
    private func columnCount(_ width: CGFloat) -> Int {
        GridMetrics.columnCount(
            window: width, cardWidth: PosterScale.l.width, density: density(width))
    }

    /// Un cadre à largeur imposée, qui pose le cran de rupture correspondant — comme le
    /// fera l'écran. Sans lui, tout le catalogue rendrait au cran de sa propre fenêtre.
    private func framed(_ width: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: width, alignment: .leading)
            .padding(.vertical, Space.s4)
            .background(.bgInset)
            .breakpoint(forWidth: width)
            .environment(\.density, density(width))
            .clipped()
    }

    private func section(
        _ title: String, note: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).font(Typo.title2(.large)).foregroundStyle(.textPrimary)
            Text(note).font(Typo.body).foregroundStyle(.textSecondary)
            content()
        }
    }
}
