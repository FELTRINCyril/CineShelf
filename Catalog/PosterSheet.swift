import DesignSystem
import SwiftUI

// Les six crans d'affiche à taille réelle, et la matrice contexte × disposition ×
// taille en entier — 8 contextes × 2 dispositions × 3 tailles.
//
// Ce n'est pas une planche décorative : la matrice est une fonctionnalité de l'app,
// persistée par profil et par contexte. Ce qu'on vient vérifier ici, c'est qu'aucune
// combinaison ne rend une carte absurde, et que le paysage recadre bien à 16/9.

struct PosterSheet: View {
    var body: some View {
        Sheet(
            "Affiches",
            note: """
                Largeurs fixes, hauteur dérivée du ratio : 2:3 en portrait, 16:9 en \
                paysage. Le nombre de colonnes n'est jamais un réglage — la grille prend \
                ce qui rentre.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                scales
                matrix
            }
        }
    }

    private var scales: some View {
        section("Les six crans", note: "En largeur de carte, points.") {
            HStack(alignment: .bottom, spacing: Space.s4) {
                ForEach(PosterScale.allCases) { scale in
                    VStack(spacing: Space.s2) {
                        placeholder(scale.size(.portrait))
                        caption("\(scale.rawValue) · \(Int(scale.width))")
                    }
                }
            }
        }
    }

    private var matrix: some View {
        section(
            "La matrice",
            note: """
                Le cran par défaut de chaque contexte est marqué. Une affiche portrait \
                recadrée en 16:9 perd le haut et le bas de la composition, donc souvent \
                son titre imprimé : le paysage n'a de sens que là où l'image source est \
                réellement large.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                ForEach(PosterContext.allCases) { context in
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text(context.label).labelStyle()
                        caption(
                            """
                            défaut · \(context.defaultSetting.layout.rawValue) \
                            \(context.defaultSetting.size.rawValue)
                            """
                        )
                        ForEach(CardLayout.allCases) { layout in
                            HStack(alignment: .bottom, spacing: Space.s3) {
                                ForEach(CardSize.allCases) { size in
                                    let setting = PosterSetting(layout: layout, size: size)
                                    let isDefault = setting == context.defaultSetting
                                    VStack(spacing: Space.s1) {
                                        placeholder(setting.cardSize(in: context))
                                        caption(
                                            """
                                            \(size.rawValue) · \
                                            \(setting.scale(in: context).rawValue)\
                                            \(isDefault ? " ·" : "")
                                            """
                                        )
                                        .foregroundStyle(isDefault ? .accent : .textTertiary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.s3)
                    .background(.bgInset)
                }
            }
        }
    }

    /// Un substitut d'affiche : aplat, aucun rayon, aucune bordure, aucune ombre.
    private func placeholder(_ size: CGSize) -> some View {
        Rectangle()
            .fill(.bgFill)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottomLeading) {
                Rectangle()
                    .fill(.accent)
                    .frame(width: size.width, height: max(2, size.height / 24))
            }
    }

    private func section(
        _ title: String, note: String?, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).title2Style()
            if let note { Text(note).microStyle().foregroundStyle(.textTertiary) }
            content()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).metaStyle().foregroundStyle(.textSecondary)
    }
}
