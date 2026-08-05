import SwiftUI

// MARK: - I3 · La vignette de galerie
//
// Relevée sur la **planche 4, bloc `6b`** — « Masonry · colonnes selon la largeur » :
//
//     <div style="background:oklch(0.16 0 0);overflow:hidden;aspect-ratio: {{ g.r }}">
//       <img style="object-fit:cover">
//     </div>
//
// **Le relevé qui compte est `aspect-ratio: {{ g.r }}`** : le ratio est celui de *l'image*,
// pas un ratio imposé. C'est toute la différence entre une galerie et une grille — et c'est
// pour ça que cette vignette ne prend pas de `CardLayout`. Lui en donner un l'aurait
// transformée en `PosterTile`, et le masonry n'aurait plus eu d'objet.
//
// Ce qui suit du prototype et qu'on ne réinvente pas : gouttière de 8 pt entre les
// vignettes d'une colonne, colonnes en parts égales, et le compte de colonnes qui dépend de
// la largeur — 3 sur iPhone, 5 sur iPad, 8 sur Mac large. **Ce compte appartient à `I4`**
// (grille adaptative), pas ici : la vignette ne sait pas dans quoi elle est posée.

/// Une image de galerie, au ratio de l'image elle-même.
public struct GalleryThumb: View {
    private let model: MediaThumbnailModel
    private let width: CGFloat?
    private let isSelected: Bool
    private let action: (() -> Void)?

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - model: la vignette et son ratio natif.
    ///   - width: `nil` laisse la vignette prendre la largeur de sa colonne, ce qui est le
    ///     cas d'usage du masonry. Une valeur explicite sert le catalogue et les rangées à
    ///     largeur fixe.
    ///   - isSelected: pose le voile d'accent de la sélection multiple.
    ///   - action: `nil` rend la vignette inerte — ni survol, ni focus.
    public init(
        _ model: MediaThumbnailModel,
        width: CGFloat? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.model = model
        self.width = width
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            MediaFill(
                imageURL: model.imageURL,
                blurHash: model.blurHash,
                crop: model.crop,
                targetAspect: model.aspect,
                background: Color.bgSurface
            )
            // `aspectRatio(contentMode: .fit)` et non une hauteur calculée : c'est ce qui
            // permet à la vignette de prendre la largeur de sa colonne et de déduire sa
            // hauteur, donc au masonry de fonctionner sans que personne mesure quoi que
            // ce soit.
            .aspectRatio(model.aspect, contentMode: .fit)
            .frame(width: width)
            .overlay { selectionVeil }
            .overlay(alignment: .bottomLeading) { caption }
            .clipped()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && action != nil ? 1.03 : 1)
        .animation(reduceMotion ? Motion.instant : Motion.fast, value: isHovering)
        .onHover { isHovering = $0 }
        .focusable(action != nil)
        .accessibilityLabel(model.caption ?? "Image")
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }

    /// La légende n'apparaît **qu'au survol**, et seulement si elle existe.
    ///
    /// Une galerie est faite pour regarder des images : une légende permanente sur chacune
    /// ferait un mur de texte, et le prototype n'en montre aucune. Elle est là pour les cas
    /// où la vignette a un nom utile — une capture, un document.
    @ViewBuilder private var caption: some View {
        if let caption = model.caption, isHovering {
            Text(caption)
                .font(Typo.micro)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, Space.s2)
                .padding(.vertical, Space.s1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.chipOnImage)
        }
    }

    @ViewBuilder private var selectionVeil: some View {
        if isSelected {
            Color.accent.opacity(0.28)
        }
    }
}

// MARK: - Échantillons

extension MediaThumbnailModel {
    /// Des ratios franchement variés : c'est ce qui fait ou casse un masonry. Un panoramique
    /// à 2,4, un carré, deux portraits, un format d'affiche, une capture d'écran verticale.
    public static let galleryRatios: [MediaThumbnailModel] = {
        // Valeur nommée et non tuple à trois membres : convention du dépôt, comme
        // `CropValues` et `PosterContext.Scales`.
        struct Sample {
            let id: String
            let aspect: Double
            let caption: String?
        }
        let ratios = [
            Sample(id: "g1", aspect: 2.4, caption: "Panoramique"),
            Sample(id: "g2", aspect: 1.0, caption: nil),
            Sample(id: "g3", aspect: 2.0 / 3.0, caption: "Affiche"),
            Sample(id: "g4", aspect: 16.0 / 9.0, caption: nil),
            Sample(id: "g5", aspect: 0.46, caption: "Capture"),
            Sample(id: "g6", aspect: 3.0 / 4.0, caption: nil),
            Sample(id: "g7", aspect: 1.5, caption: nil)
        ]
        return ratios.map { sample in
            MediaThumbnailModel(
                id: sample.id,
                imageURL: URL(string: "https://exemple.test/\(sample.id).jpg"),
                aspect: sample.aspect,
                caption: sample.caption)
        }
    }()
}

#Preview("Ratios variés, trois colonnes") {
    HStack(alignment: .top, spacing: Space.s2) {
        ForEach(0..<3, id: \.self) { column in
            VStack(spacing: Space.s2) {
                ForEach(
                    MediaThumbnailModel.galleryRatios.enumerated()
                        .filter { $0.offset % 3 == column }
                        .map(\.element)
                ) { thumb in
                    GalleryThumb(thumb) {}
                }
            }
        }
    }
    .frame(width: 360)
    .padding(Space.s4)
    .background(Color.bgCanvas)
}
