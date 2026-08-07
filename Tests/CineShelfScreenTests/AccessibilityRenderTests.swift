import CoreGraphics
import SwiftData
import SwiftUI
import Testing

@testable import CineShelf
@testable import CineShelfCore
@testable import DesignSystem

// MARK: - V12 · Les sondes d'accessibilité
//
// **Scindé de `ScreenRenderTests` le 2026-08-07**, quand la sonde de Dynamic Type a fait
// dépasser les 500 lignes au fichier d'origine. Le décor (`Stage`), la mesure de pixels et
// `render(_:typeSize:)` y restent : ce sont les outils, pas les questions.

@Suite("Accessibilité des écrans")
@MainActor
struct AccessibilityRenderTests {

    /// **`V12` — Dynamic Type de `xSmall` à `AX5`, sur un écran réel.**
    ///
    /// Source : `docs/06` §« Accessibilité » — « Dynamic Type de `xSmall` à `AX5`, **sans
    /// troncature**. Au-delà de `.accessibility1`, les grilles basculent en liste. »
    ///
    /// **Ce que cette sonde peut prouver, et ce qu'elle ne peut pas.** Elle prouve que chaque
    /// cran **dessine** — aucun ne rend un aplat, donc aucun ne s'effondre. Elle ne peut pas
    /// prouver l'absence de troncature : `ImageRenderer` rend des pixels, pas des boîtes de
    /// texte, et un « … » est trois pixels comme un autre. Ce point-là reste à l'œil, et il est
    /// inscrit comme tel — mieux vaut une porte qui dit ce qu'elle couvre qu'une porte qu'on
    /// croit complète.
    ///
    /// **La grille bascule, et ça se voit.** Le compte de couleurs à `AX5` diffère de celui à
    /// `large` : une colonne au lieu de plusieurs, donc une composition différente. Sans cette
    /// paire, la sonde passerait même si `prefersList` n'était branché nulle part — c'est le
    /// contrôle qui relie la règle testée dans `DesignSystem` à son effet réel.
    @Test("Chaque cran de Dynamic Type dessine, de xSmall à AX5")
    func dynamicTypeScaleDraws() throws {
        let stage = try Stage()
        try stage.populate()

        var measured: [(DynamicTypeSize, Int)] = []
        for size in [
            DynamicTypeSize.xSmall, .large, .xxxLarge, .accessibility1, .accessibility3,
            .accessibility5
        ] {
            let stats = try #require(render(stage.host(TitlesView()), typeSize: size))
            measured.append((size, stats.distinctColours))
            #expect(!stats.isUniform, Comment(rawValue: "\(size) rend un aplat"))
        }

        print(
            "Dynamic Type — "
                + measured.map { "\($0.0): \($0.1)" }.joined(separator: " · "))

        // La paire qui relie la règle à son effet : `large` est une grille, `AX5` une liste.
        let large = try #require(measured.first { $0.0 == .large }?.1)
        let ax5 = try #require(measured.first { $0.0 == .accessibility5 }?.1)
        #expect(
            large != ax5,
            Comment(rawValue: "grille \(large) == liste \(ax5) : la bascule ne se voit pas"))
    }
}
