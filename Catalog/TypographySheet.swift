import DesignSystem
import SwiftUI

// Les onze rôles typographiques, avec la police et le TextStyle de rattachement.
// Le sélecteur Dynamic Type de la barre d'outils agit ici : à AX5, aucun rôle
// ne doit tronquer.

struct TypographySheet: View {
    var body: some View {
        Sheet(
            "Typographie",
            note: "Chaque rôle est relatif à un TextStyle : teste AX3 et AX5."
        ) {
            VStack(alignment: .leading, spacing: Space.section) {
                display
                interface
                data
                faces
            }
        }
    }

    private var display: some View {
        group("Display — Archivo embarquée") {
            role("heroTitle", ".largeTitle · Archivo SemiExpanded ExtraBold") {
                Text("Une étagère personnelle").font(Typo.heroTitle)
            }
            role("pageTitle", ".title · Archivo Bold") {
                Text("Catalogue").font(Typo.pageTitle)
            }
            role("sectionTitle", ".title3 · Archivo SemiBold") {
                Text("Ajouts récents").font(Typo.sectionTitle)
            }
            role("railLabel", ".caption · Archivo SemiExpanded SemiBold, majuscules") {
                Text("Action").railLabelStyle()
            }
        }
    }

    private var interface: some View {
        group("Interface et corps — SF Pro") {
            role("cardTitle", ".subheadline") {
                Text("Le Conformiste").font(Typo.cardTitle)
            }
            role("body", ".body") {
                Text("La densité vient de la grille, pas de la petitesse du texte.")
                    .font(Typo.body)
            }
            role("bodyEmphasis", ".body semibold") {
                Text("Impossible de synchroniser.").font(Typo.bodyEmphasis)
            }
            role("fieldLabel", ".footnote") {
                Text("Titre original").font(Typo.fieldLabel)
            }
            role("caption", ".caption") {
                Text("Importée depuis le fichier.").font(Typo.caption)
            }
        }
    }

    private var data: some View {
        group("Données — SF Mono") {
            role("cardMeta", ".caption2 monospaced") {
                Text("1970 · 1 h 51").font(Typo.cardMeta)
            }
            role("dataValue", ".callout monospaced") {
                Text("4,5 / 5").font(Typo.dataValue)
            }
            role("railCounter", ".caption2 monospaced, chiffres tabulaires") {
                Text("01–08 / 24").font(Typo.railCounter)
            }
        }
    }

    /// Preuve visuelle que les deux chasses sont bien deux familles distinctes :
    /// si Archivo ne se chargeait pas, les deux lignes seraient identiques.
    private var faces: some View {
        group("Chasses embarquées") {
            ForEach(DesignSystemFonts.Face.allCases, id: \.rawValue) { face in
                role(face.postScriptName, face.familyName) {
                    Text("Étagère · Handling")
                        .font(.custom(face.postScriptName, size: 22, relativeTo: .title2))
                }
            }
        }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(title).railLabelStyle()
            content()
        }
    }

    private func role(
        _ name: String, _ detail: String, @ViewBuilder sample: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            sample().foregroundStyle(.textPrimary)
            Text("\(name) — \(detail)")
                .font(Typo.cardMeta)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
