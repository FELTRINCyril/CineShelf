import DesignSystem
import SwiftUI

// Les onze rôles typographiques, avec la police et le TextStyle de rattachement.
// Le sélecteur Dynamic Type de la barre d'outils agit ici : à AX5, aucun rôle
// ne doit tronquer — et les trois titrages doivent avoir quitté Bebas Neue.

struct TypographySheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Sheet(
            "Typographie",
            note: """
                Chaque rôle est relatif à un TextStyle : teste AX3 et AX5. À partir de \
                la première taille d'accessibilité, display / title.1 / title.2 passent \
                de Bebas Neue à Archivo Narrow 700.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                titling
                interface
                data
                faces
            }
        }
    }

    private var titling: some View {
        group("Titrage — Bebas Neue, Archivo Narrow 700 en accessibilité") {
            // L'indicateur de bascule : c'est ce qu'on vient vérifier ici.
            Text(
                dynamicTypeSize.usesAccessibleTitling
                    ? "Bascule active — Archivo Narrow 700"
                    : "Bebas Neue"
            )
            .labelStyle()
            .foregroundStyle(dynamicTypeSize.usesAccessibleTitling ? .accent : .textTertiary)

            role("display", "56 / 1.0 · +0.02em · .largeTitle") {
                Text("Une étagère personnelle").displayStyle()
            }
            role("title.1", "34 / 1.05 · +0.02em · .title") {
                Text("Catalogue").title1Style()
            }
            role("title.2", "22 / 1.15 · +0.03em · .title2") {
                Text("Ajouts récents").title2Style()
            }
        }
    }

    private var interface: some View {
        group("Interface et corps") {
            role("headline", "15 / 1.3 · Archivo 600 · .headline") {
                Text("Le Conformiste").headlineStyle()
            }
            role("body", "15 / 1.55 · Public Sans 300 · .body") {
                Text("La densité vient de la grille, pas de la petitesse du texte.")
                    .bodyStyle()
            }
            role("callout", "13 / 1.45 · Archivo 400 · .callout") {
                Text("Importée depuis le fichier.").calloutStyle()
            }
            role("label", "11 / 1 · Archivo Narrow 600 · +0.12em · capitales") {
                Text("Titre original").labelStyle()
            }
            role("action", "12 / 1 · Archivo Narrow 600 · +0.08em · capitales") {
                Text("Enregistrer").actionStyle()
            }
        }
    }

    private var data: some View {
        group("Chiffres et métadonnées — IBM Plex Mono") {
            role("meta", "11 / 1.35 · Plex Mono 400 · +0.02em") {
                Text("1970 · 1 h 51").metaStyle()
            }
            role("numeric", "12 / 1.3 · Plex Mono 500 · tabulaire") {
                // Deux lignes, pour que l'alignement en colonne se voie : c'est la
                // seule raison d'être des chiffres tabulaires.
                VStack(alignment: .trailing, spacing: 0) {
                    Text("1 284").numericStyle()
                    Text("417").numericStyle()
                }
            }
            role("micro", "10 / 1.4 · Plex Mono 400 · +0.04em") {
                Text("Année attendue entre 1888 et 2030").microStyle()
            }
        }
    }

    /// Preuve visuelle que les cinq familles se chargent : si l'une ne se résolvait
    /// pas, sa ligne retomberait sur Helvetica et se distinguerait immédiatement.
    private var faces: some View {
        group("Fontes embarquées") {
            ForEach(DesignSystemFonts.Face.allCases, id: \.rawValue) { face in
                role(face.postScriptName, face.familyName) {
                    Text("Étagère · Handling · 0123")
                        .font(.custom(face.postScriptName, size: 22, relativeTo: .title2))
                }
            }
        }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text(title).labelStyle().foregroundStyle(.textSecondary)
            content()
        }
    }

    private func role(
        _ name: String, _ detail: String, @ViewBuilder sample: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            sample().foregroundStyle(.textPrimary)
            Text("\(name) — \(detail)")
                .metaStyle()
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
