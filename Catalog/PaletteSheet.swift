import DesignSystem
import SwiftUI

// Les 59 Color Sets, nom et valeur résolue. La valeur suit la barre d'outils :
// bascule clair/sombre ou contraste élevé et les hex changent sous les yeux —
// c'est la vérification la plus directe que les 4 apparences sont bien câblées.

struct PaletteSheet: View {
    var body: some View {
        Sheet(
            "Couleurs",
            note: """
                \(ColorTokens.all.count) Color Sets. La valeur affichée est celle \
                résolue dans l'apparence courante — change le thème ou le contraste \
                pour les voir bouger.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.section) {
                group(
                    "Sémantiques",
                    note: "Le seul niveau que les vues lisent.",
                    tokens: ColorTokens.semantics
                )
                group(
                    "Primitives",
                    note: "Référence seule : aucune vue ne doit les lire.",
                    tokens: ColorTokens.primitives
                )
            }
        }
    }

    private func group(_ title: String, note: String, tokens: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(title).railLabelStyle()
            Text(note).font(Typo.caption).foregroundStyle(.textTertiary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190), spacing: Space.md)],
                spacing: Space.md
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

        VStack(alignment: .leading, spacing: Space.sm) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(color)
                .frame(height: 56)
                .dsBorder(.borderSubtle, radius: Radius.sm)

            Text(token)
                .font(Typo.cardMeta)
                .foregroundStyle(.textSecondary)
            Text(hexDescription(resolved))
                .font(Typo.cardMeta)
                .foregroundStyle(.textTertiary)
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
