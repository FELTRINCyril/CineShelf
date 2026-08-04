import DesignSystem
import SwiftUI

// La première planche du catalogue, et elle ne montre aucun token.
//
// Elle existe parce que la question s'est posée pour de vrai : en ouvrant le catalogue,
// on cherche les formulaires et la console de gestion, on ne les trouve pas, et rien ne
// dit s'ils sont oubliés ou simplement pas encore arrivés. Ce qui suit répond sans
// qu'on ait à demander.

struct RoadmapSheet: View {
    var body: some View {
        Sheet(
            "Où en est le design",
            note: """
                Ce catalogue montre ce qui est intégré, dans l'ordre où ça arrive. Ce qui \
                n'y figure pas n'est pas oublié : ce n'est pas encore intégré.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                stages
                formsNote
            }
        }
    }

    private struct Stage: Identifiable {
        let id: String
        let what: String
        let state: State
        let detail: String

        enum State {
            case done, next, later

            var label: String {
                switch self {
                case .done: "Intégré"
                case .next: "En cours"
                case .later: "À venir"
                }
            }
        }
    }

    private static let stages: [Stage] = [
        Stage(
            id: "I1",
            what: "Les tokens",
            state: .done,
            detail: """
                Couleur, typographie, espacement, densité, rayons, traits, mouvement, \
                plans, points de rupture, les six tailles d'affiche avec leur matrice, et \
                les symboles. C'est tout ce que les planches suivantes de ce catalogue \
                montrent aujourd'hui.
                """
        ),
        Stage(
            id: "I2…In",
            what: "Les composants, un par un",
            state: .next,
            detail: """
                Carte affiche, carte paysage, carte personne, carte collection, vignette \
                de galerie, rail horizontal, grille, ligne de tableau, jeton de filtre, \
                badge d'état, barre de notation, indicateur de progression, avatar de \
                profil, pastille de compteur. Chacun arrive séparément et se voit ici \
                avant d'entrer dans un écran.
                """
        ),
        Stage(
            id: "V1…V12",
            what: "Les écrans",
            state: .later,
            detail: """
                Recherche, médias, galerie, personnes, collections, console de gestion, \
                profils, import et export, migration, synchronisation, widget, \
                accessibilité. Ils s'écrivent une seule fois, contre le design final, et \
                ils ne s'affichent pas dans ce catalogue — c'est l'app qu'il faut ouvrir.
                """
        )
    ]

    private var stages: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("Trois étapes, dans cet ordre").title2Style()
            ForEach(Self.stages) { stage in
                VStack(alignment: .leading, spacing: Space.s2) {
                    HStack(spacing: Space.s3) {
                        Text(stage.id).numericStyle().foregroundStyle(.accent)
                        Text(stage.what).headlineStyle()
                        Text(stage.state.label)
                            .labelStyle()
                            .foregroundStyle(stage.state == .done ? .success : .textTertiary)
                    }
                    Text(stage.detail).bodyStyle().foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
                .background(.bgInset)
            }
        }
    }

    private var formsNote: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Le cas des formulaires").title2Style()
            Text(
                """
                « Les formulaires » ne sont pas une étape : ils se répartissent sur les \
                deux chaînes, et c'est la source de confusion la plus probable.
                """
            )
            .bodyStyle()
            .foregroundStyle(.textSecondary)

            VStack(alignment: .leading, spacing: Space.s2) {
                row(
                    "Les champs sont des composants",
                    "Texte, nombre, bascule, date à précision variable, notation, "
                        + "multi-sélecteur, jeton de couleur, et les quatre marques d'erreur. "
                        + "Ils arriveront dans la chaîne I, et se verront ici."
                )
                row(
                    "L'écran d'import est un écran",
                    "Les quatre étapes — correspondance des colonnes, aperçu, corrections "
                        + "en masse, import — appartiennent à V8. Elles ne se verront pas ici, "
                        + "même quand tous leurs champs seront intégrés."
                )
            }
        }
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(title).labelStyle()
            Text(detail).calloutStyle().foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(.bgInset)
    }
}
