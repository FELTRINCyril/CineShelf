import SwiftUI

// MARK: - V3 · La maçonnerie
//
// Relevée sur l'addendum 2 bloc `13c` — « Galerie · 2 colonnes, puis 4 » — et non sur la
// planche 4 bloc `6b`, et **c'est un arbitrage, pas une préférence**.
//
// Les deux blocs rendent la galerie, et **ils se contredisent à la seule largeur qu'ils
// rendent tous les deux** : 393 pt donne 3 colonnes en `6b` et 2 en `13c`. Ce ne sont donc pas
// « trois points de rupture différents » — à 393 pt, la largeur de carte implicite est de 116
// d'un côté et de 140 de l'autre. Et `6b` se contredit lui-même : ses trois largeurs
// impliquent 116, 222 puis 223 de carte, c'est-à-dire un **compte de colonnes par format**,
// pas une carte constante.
//
// Les rendus divergent, donc le jeton fait foi. Confirmation utile, et elle est nette :
// `13c` est le seul bloc qui **nomme** un cran de l'échelle — « iPhone portrait · poster.l,
// 2 colonnes », « iPad portrait · poster.l, 4 colonnes, gouttière 24 » —, il le nomme aux
// **deux** formats qu'il rend, et `PosterScale.l` avec les jetons de marge et de gouttière
// redonne exactement 2 à 393 pt et 4 à 834 pt. `GridMetricsTests` l'assène.
//
// C'est aussi la règle déjà arbitrée par `I4` : largeur de carte fixe, la grille prend ce qui
// rentre. Le §6 du handoff la répète pour la galerie en toutes lettres — « à cran de carte
// constant : le nombre de colonnes n'est pas un réglage ».
//
// **Pourquoi des colonnes indépendantes et non un `LazyVGrid`.** Un `LazyVGrid` aligne ses
// lignes : la plus haute image d'une ligne impose sa hauteur aux autres, et il reste un vide
// sous chacune. C'est exactement ce que la galerie ne veut pas — elle est le seul écran où les
// ratios se mélangent réellement (§6), donc le seul qui exige des colonnes qui coulent
// séparément. Chaque colonne est un `LazyVStack`, donc chacune reste paresseuse.

/// Une grille en maçonnerie : colonnes de largeur égale, hauteurs indépendantes.
public struct MasonryGrid<Element: Identifiable, Content: View>: View {
    private let items: [Element]
    private let cardWidth: CGFloat
    private let aspect: (Element) -> Double
    private let content: (Element) -> Content
    private let onAppear: ((Int) -> Void)?

    @Environment(\.density) private var density
    @Environment(\.breakpoint) private var breakpoint
    @State private var available: CGFloat = 0

    /// - Parameters:
    ///   - items: les éléments, dans l'ordre de la collection.
    ///   - cardWidth: la largeur de carte visée. Elle ne borne pas la colonne — celle-ci
    ///     prend sa part de la largeur utile — elle décide seulement **combien** de colonnes.
    ///   - aspect: la proportion de l'élément, largeur / hauteur. Les valeurs aberrantes sont
    ///     bornées par `MasonryColumns`.
    ///   - onAppear: l'index de l'élément qui entre à l'écran. C'est le seul signal qu'un
    ///     conteneur paresseux émette, et c'est ce qui alimente le préchargement.
    ///   - content: la tuile d'un élément.
    public init(
        _ items: [Element],
        cardWidth: CGFloat,
        aspect: @escaping (Element) -> Double,
        onAppear: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.items = items
        self.cardWidth = cardWidth
        self.aspect = aspect
        self.onAppear = onAppear
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .top, spacing: gutter) {
            ForEach(Array(columns.enumerated()), id: \.offset) { column in
                LazyVStack(spacing: gutter) {
                    ForEach(column.element, id: \.self) { index in
                        content(items[index])
                            .onAppear { onAppear?(index) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private var columns: [[Int]] {
        MasonryColumns.distribute(aspects: items.map(aspect), columnCount: columnCount)
    }

    private var gutter: CGFloat { breakpoint.gridGutter(density) }
}

// MARK: - Previews

#Preview("Maçonnerie · ratios mêlés, deux largeurs") {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.s6) {
            ForEach([393.0, 834.0], id: \.self) { width in
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text(verbatim: "\(Int(width)) pt")
                        .font(Typo.micro)
                        .foregroundStyle(Color.textTertiary)
                    MasonryGrid(
                        MediaThumbnailModel.galleryRatios,
                        cardWidth: PosterScale.l.width,
                        aspect: \.aspect
                    ) { thumb in
                        GalleryThumb(thumb) {}
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
