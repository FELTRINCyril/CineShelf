import DesignSystem
import SwiftUI

// Les trois composants de `I2`, dans la direction courante — à ne pas confondre avec la
// planche `PosterCard`, qui montre le composant de l'**ancienne** direction et partira
// avec `Legacy/` à `V12`.
//
// Ce qu'on vient vérifier ici, et qui ne se voit pas dans un test :
//
// - qu'aucun des six crans ne rend une tuile absurde, dans les deux dispositions ;
// - que le masque privé ne laisse rien deviner — c'est un aplat, pas un flou ;
// - que le repli sur initiales tient sur un nom composé, un nom à particule et un nom
//   d'un seul mot ;
// - que les quatre apparences passent, le sélecteur du catalogue étant en haut.

struct CardTilesSheet: View {
    var body: some View {
        Sheet(
            "Tuiles · I2",
            note: """
                Direction « 2a Plein cadre » : angles vifs, aucune ombre, aucune bordure. \
                Le survol agrandit de 6 % — il n'entoure pas. Pointe une tuile pour le \
                voir ; au doigt, rien ne se produit, et c'est voulu.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                portraitScales
                landscapeScales
                states
                detail
                people
            }
        }
    }

    private var portraitScales: some View {
        section("Affiche · portrait 2:3", note: "Les six crans, à taille réelle.") {
            HStack(alignment: .bottom, spacing: Space.s3) {
                ForEach(PosterScale.allCases) { scale in
                    VStack(spacing: Space.s1) {
                        PosterTile(.sample, layout: .portrait, scale: scale) {}
                        Text(scale.rawValue)
                            .font(Typo.micro)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    private var landscapeScales: some View {
        section(
            "Affiche · paysage 16:9",
            note: """
                Le même composant, `layout: .landscape`. Deux vues auraient dupliqué le \
                remplissage et le recadrage, et trahi la matrice — qui est une \
                fonctionnalité, pas une variante de dessin.
                """
        ) {
            HStack(alignment: .bottom, spacing: Space.s3) {
                ForEach(PosterScale.allCases) { scale in
                    PosterTile(.sample, layout: .landscape, scale: scale) {}
                }
            }
        }
    }

    private var states: some View {
        section(
            "États",
            note: """
                Un seul bandeau à la fois, par précédence archivé > vu > à voir. Sous le \
                cran `m`, aucun bandeau : il serait illisible. Le privé est un aplat \
                `private.mask`, jamais un flou — un flou laisse deviner la composition et \
                se défait sur une capture d'écran.
                """
        ) {
            HStack(alignment: .top, spacing: Space.s3) {
                labelled("vu") { PosterTile(.samples[1], scale: .l) {} }
                labelled("à voir") { PosterTile(.samples[2], scale: .l) {} }
                labelled("archivé") { PosterTile(.samples[7], scale: .l) {} }
                labelled("privé") { PosterTile(.samples[6], scale: .l) {} }
                labelled("sélectionné") { PosterTile(.sample, scale: .l, isSelected: true) {} }
                labelled("privé · cran s") { PosterTile(.samples[6], scale: .s) {} }
            }
        }
    }

    private var detail: some View {
        section(
            "Tuile détaillée",
            note: """
                L'élément mis en avant dans une grille : image, titre, méta avec la note \
                en accent, et trois actions. Une pastille n'apparaît que si son action est \
                fournie — une pastille inerte est pire qu'une pastille absente.
                """
        ) {
            HStack(alignment: .top, spacing: Space.s4) {
                PosterTileDetail(
                    .sample, scale: .l, onOpen: {}, onToggleWatched: {}, onMore: {})
                labelled("sans actions secondaires") {
                    PosterTileDetail(.samples[4], scale: .l, onOpen: {})
                }
                labelled("privé") {
                    PosterTileDetail(.samples[6], scale: .l, onOpen: {}, onMore: {})
                }
            }
        }
    }

    private var people: some View {
        section(
            "Personne",
            note: """
                Le nom est toujours affiché : une affiche se reconnaît, un visage rarement. \
                Sans portrait, le repli est les initiales et non un aplat — un pavé vide \
                répété deux cents fois ne donne aucune prise. Les deux lignes de légende \
                sont réservées même vides, sinon la rangée se désaligne.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s5) {
                HStack(alignment: .top, spacing: Space.s4) {
                    ForEach([PosterScale.s, .m, .l, .xl]) { scale in
                        PersonTile(.person, scale: scale) {}
                    }
                }
                HStack(alignment: .top, spacing: Space.s3) {
                    ForEach(PosterCardModel.people) { person in
                        PersonTile(person, scale: .m) {}
                    }
                }
            }
        }
    }

    // MARK: - Habillage

    private func section(
        _ title: String, note: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).font(Typo.title2(.large)).foregroundStyle(Color.textPrimary)
            Text(note).font(Typo.body).foregroundStyle(Color.textSecondary)
            content()
        }
    }

    private func labelled(
        _ label: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            content()
            Text(label).font(Typo.micro).foregroundStyle(Color.textTertiary)
        }
    }
}
