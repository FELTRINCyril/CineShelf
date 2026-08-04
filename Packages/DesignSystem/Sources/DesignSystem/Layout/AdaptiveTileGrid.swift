import SwiftUI

// MARK: - I4 · La grille adaptative
//
// Relevée sur la planche 3 bloc `4a` et sur l'addendum 2 bloc `13c`, qui donne la règle
// en toutes lettres : **largeur de carte fixe, la grille prend ce qui rentre.** Le
// nombre de colonnes n'est donc jamais fourni par un appelant, ni lu dans une table :
// il sort de `GridMetrics.columnCount`, qui est le seul endroit où il existe.
//
// **Pourquoi mesurer la largeur plutôt qu'un `GridItem.adaptive`.** `.adaptive(minimum:)`
// fait la même arithmétique, mais à l'intérieur de SwiftUI, où personne ne peut la lire.
// Il aurait fallu que `GridMetrics` la refasse de son côté pour le masonry et pour les
// tests — deux sources de vérité pour un seul nombre, exactement le défaut qu'on vient
// de retirer de `Breakpoint`. On mesure une fois, on calcule une fois, et le compte
// obtenu est celui que la grille pose.

/// Une grille de tuiles à largeur de carte constante.
public struct AdaptiveTileGrid<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    private let data: Data
    private let cardWidth: CGFloat
    private let content: (Data.Element) -> Content

    @Environment(\.density) private var density
    @Environment(\.breakpoint) private var breakpoint
    @State private var available: CGFloat = 0

    /// - Parameters:
    ///   - data: les éléments à poser.
    ///   - cardWidth: la largeur de carte, en général `scale.width`. C'est elle qui est
    ///     constante ; le nombre de colonnes s'en déduit.
    ///   - content: la tuile d'un élément.
    public init(
        _ data: Data,
        cardWidth: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.cardWidth = cardWidth
        self.content = content
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: gutter) {
            ForEach(data) { element in
                content(element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, breakpoint.screenMargin)
        // La largeur mesurée est celle du conteneur **avant** ses marges : c'est
        // `GridMetrics` qui les retire, pour que le calcul soit le même ici et dans les
        // tests, qui n'ont pas de conteneur.
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            available = $0
        }
    }

    private var columnCount: Int {
        GridMetrics.columnCount(
            available: available - 2 * breakpoint.screenMargin,
            cardWidth: cardWidth,
            gutter: gutter)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cardWidth), spacing: gutter, alignment: .top),
            count: columnCount)
    }

    private var gutter: CGFloat { breakpoint.gridGutter(density) }
}

// MARK: - Previews

#Preview("Grille · trois largeurs, carte constante") {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.s6) {
            ForEach([393.0, 834.0, 1280.0], id: \.self) { width in
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text(verbatim: "\(Int(width)) pt")
                        .font(Typo.micro)
                        .foregroundStyle(Color.textTertiary)
                    AdaptiveTileGrid(PosterCardModel.samples, cardWidth: PosterScale.l.width) {
                        PosterTile($0, scale: .l) {}
                    }
                    .frame(width: width)
                    .breakpoint(forWidth: width)
                }
            }
        }
        .padding(.vertical, Space.s6)
    }
    .background(Color.bgCanvas)
}
