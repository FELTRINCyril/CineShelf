import DesignSystem
import SwiftUI

// Espacements, densité, rayons, traits, mouvement, plans et points de rupture, à
// taille réelle. Tout ce que la planche 8 chiffre et qu'aucune capture ne prouve.

struct MetricsSheet: View {
    @Environment(\.density) private var density

    var body: some View {
        Sheet(
            "Espacement · Densité · Rayons · Mouvement",
            note: """
                Valeurs dessinées à l'échelle. La densité est la seule valeur dynamique \
                du système : elle est posée une fois par plateforme dans l'environnement.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                spacing
                densities
                radii
                strokes
                motion
                layers
                breakpoints
            }
        }
    }

    // MARK: Espacement

    private static let spaces: [(String, CGFloat)] = [
        ("s1", Space.s1), ("s2", Space.s2), ("s3", Space.s3), ("s4", Space.s4),
        ("s5", Space.s5), ("s6", Space.s6), ("s7", Space.s7), ("s8", Space.s8)
    ]

    private var spacing: some View {
        section("Espacement", note: "Base 4 pt. Un cran se désigne par son rang.") {
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(Self.spaces, id: \.0) { name, value in
                    HStack(spacing: Space.s3) {
                        Text(name).metaStyle().frame(width: 28, alignment: .leading)
                        Rectangle().fill(.accent).frame(width: value, height: 12)
                        caption(number(value))
                    }
                }
            }
        }
    }

    // MARK: Densité

    private var densities: some View {
        section(
            "Densité — deux crans",
            note: "Courant : \(density == .dense ? "dense" : "ample"). Dense sur macOS, ample sur iOS."
        ) {
            HStack(alignment: .top, spacing: Space.s5) {
                ForEach(Density.allCases) { cran in
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text(cran == .dense ? "Dense" : "Ample").labelStyle()
                        measure("ligne de tableau", cran.rowHeight)
                        measure("barre d'outils", cran.toolbarHeight)
                        measure("marge d'écran", cran.screenMargin)
                        measure("espacement de formulaire", cran.formSpacing)
                        measure("hauteur de champ", cran.fieldHeight)
                        measure("gouttière de grille", cran.gridGutter)
                        caption("interlignage du corps · \(number(cran.bodyLeading))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.s3)
                    .background(.bgInset)
                }
            }
        }
    }

    private func measure(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: Space.s2) {
            Rectangle().fill(.bgFill).frame(width: 44, height: value)
            caption("\(name) · \(number(value))")
        }
    }

    // MARK: Rayons

    private static let radii: [(String, CGFloat)] = [
        ("none", Radius.none), ("xs", Radius.xs), ("s", Radius.s),
        ("m", Radius.m), ("l", Radius.l), ("sheet", Radius.sheet)
    ]

    private var radii: some View {
        section(
            "Rayons",
            note: """
                Toujours continus, par .dsClip(_:). `none` sur tout ce qui est \
                photographique : une affiche n'a ni cadre, ni coin arrondi, ni ombre.
                """
        ) {
            HStack(alignment: .top, spacing: Space.s4) {
                ForEach(Self.radii, id: \.0) { name, value in
                    VStack(spacing: Space.s2) {
                        Rectangle()
                            .fill(.bgFill)
                            .frame(width: 80, height: 80)
                            .dsClip(value)
                        caption("\(name) · \(number(value))")
                    }
                }
            }
        }
    }

    // MARK: Trait

    private var strokes: some View {
        section("Trait", note: "Le seul trait autorisé, dans la seule couleur autorisée.") {
            VStack(alignment: .leading, spacing: Space.s3) {
                ForEach(
                    [("hairline", Stroke.hairline), ("emphasis", Stroke.emphasis)], id: \.0
                ) { name, width in
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Rectangle().fill(.separatorLine).frame(height: width)
                        caption("\(name) · \(number(width)) pt")
                    }
                }
            }
        }
    }

    // MARK: Mouvement

    @State private var animated = false

    private static let durations: [(String, String)] = [
        ("instant", "0 ms — sélection dans un tableau dense"),
        ("fast", "120 ms easeOut — survol, focus, bascule d'état"),
        ("base", "220 ms easeInOut — panneau, bandeau, densité"),
        ("sheet", "320 ms spring — feuille, changement de palier"),
        ("zoom", "380 ms spring — affiche vers visionneuse"),
        ("slow", "600 ms easeInOut — fondu du hero")
    ]

    private var motion: some View {
        section("Mouvement", note: "Toutes les animations passent par .dsAnimation, qui respecte Reduce Motion.") {
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(Self.durations, id: \.0) { name, detail in
                    caption("\(name) — \(detail)")
                }
                Button("Jouer") { animated.toggle() }
                    .actionStyle()
                    .frame(minHeight: Space.minHitTarget)
                Rectangle()
                    .fill(.accent)
                    .frame(width: 44, height: 44)
                    .offset(x: animated ? 160 : 0)
                    .dsAnimation(Motion.base, value: animated)
            }
        }
    }

    // MARK: Plans

    private static let layers: [(String, Double)] = [
        ("content", Layer.content), ("sticky", Layer.sticky), ("menu", Layer.menu),
        ("scrim", Layer.scrim), ("modal", Layer.modal), ("viewer", Layer.viewer),
        ("notification", Layer.notification)
    ]

    private var layers: some View {
        section(
            "Plans",
            note: """
                Un seul plan modal à la fois — une feuille remplace un dialogue, elle ne \
                s'ouvre pas au-dessus. La notification passe au-dessus de tout.
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s1) {
                ForEach(Self.layers, id: \.0) { name, value in
                    caption("\(name) · \(Int(value))")
                }
            }
        }
    }

    // MARK: Points de rupture

    private var breakpoints: some View {
        section("Points de rupture", note: "Sur largeur de fenêtre, pas sur classe de taille.") {
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(Breakpoint.allCases) { cran in
                    caption(
                        """
                        \(cran.rawValue) · ≥ \(number(cran.minWidth)) pt · \
                        \(cran.columns) colonnes · marge \(number(cran.screenMargin)) · \
                        inspecteur \(cran.showsInspectorAsColumn ? "en colonne" : "en feuille")
                        """
                    )
                }
            }
        }
    }

    // MARK: Habillage

    private func section(
        _ title: String, note: String?, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).labelStyle()
            if let note { Text(note).microStyle().foregroundStyle(.textTertiary) }
            content()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).metaStyle().foregroundStyle(.textSecondary)
    }

    private func number(_ value: CGFloat) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value)
    }
}
