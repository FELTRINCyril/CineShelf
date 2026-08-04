import DesignSystem
import SwiftUI

// Les Color Sets, nom et valeur résolue. La valeur suit la barre d'outils :
// bascule clair/sombre ou contraste élevé et les hex changent sous les yeux —
// c'est la vérification la plus directe que les 4 apparences sont bien câblées.

struct PaletteSheet: View {
    var body: some View {
        Sheet(
            "Couleurs",
            note: """
                \(ColorTokens.semantics.count) rôles, 4 apparences chacun. La valeur \
                affichée est celle résolue dans l'apparence courante — change le thème \
                ou le contraste pour les voir bouger.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                group(
                    "Direction courante",
                    note: """
                        Le seul niveau qu'une vue lit. Pas de primitives : la planche 8 \
                        ne fournit aucune rampe, elle pose directement ces rôles.
                        """,
                    tokens: ColorTokens.semantics
                )
                group(
                    "Ancienne direction — en sursis",
                    note: """
                        Lus par le banc d'essai des prompts 10 et 11, et par rien d'autre. \
                        Partent avec Legacy/ à V12.
                        """,
                    tokens: LegacyColorTokens.semantics
                )
            }
        }
    }

    private func group(_ title: String, note: String, tokens: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).labelStyle()
            Text(note).microStyle().foregroundStyle(.textTertiary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190), spacing: Space.s3)],
                spacing: Space.s3
            ) {
                ForEach(tokens, id: \.self) { Swatch(token: $0) }
            }
        }
    }
}

private struct Swatch: View {
    let token: String

    @Environment(\.self) private var environment

    var body: some View {
        let color = ColorTokens.color(for: token)
        let resolved = color.resolve(in: environment)

        VStack(alignment: .leading, spacing: Space.s2) {
            // Un trait `separator` de 1 pt, et pas une bordure : c'est le seul trait
            // que le système autorise. Il est nécessaire ici parce qu'un échantillon
            // de `bg/canvas` sur un fond `bg/canvas` serait invisible.
            Rectangle()
                .fill(color)
                .frame(height: 56)
                .overlay {
                    Rectangle().strokeBorder(.separatorLine, lineWidth: Stroke.hairline)
                }

            Text(token).metaStyle().foregroundStyle(.textSecondary)
            Text(hexDescription(resolved)).metaStyle().foregroundStyle(.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(token), \(hexDescription(resolved))")
    }

    /// `#RRGGBB`, suivi de l'opacité quand le jeu n'est pas opaque.
    private func hexDescription(_ resolved: Color.Resolved) -> String {
        let channel = { (value: Float) in Int((value * 255).rounded()) }
        let hex = String(
            format: "#%02X%02X%02X",
            channel(resolved.red), channel(resolved.green), channel(resolved.blue)
        )
        guard resolved.opacity < 0.999 else { return hex }
        return "\(hex) · \(Int((resolved.opacity * 100).rounded())) %"
    }
}
