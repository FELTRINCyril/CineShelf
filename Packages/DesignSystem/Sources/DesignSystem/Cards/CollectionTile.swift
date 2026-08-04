import SwiftUI

// MARK: - I3 · La tuile de collection
//
// Relevée sur la **planche 3, bloc `4e`** — « Collections · rayons », dont le sous-titre
// dit l'essentiel : « couverture générée en mosaïque quand elle manque ».
//
//     <div style="display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;
//                 aspect-ratio:16/9;overflow:hidden;background:oklch(0.16 0 0)">
//       <img ×4 style="object-fit:cover">
//     </div>
//     … survol : transform:scale(1.03)
//
// Trois relevés qui ne se devinent pas :
//
// 1. **Une mosaïque 2 × 2, en 16:9, sans gouttière.** Le `grid` du prototype n'a pas de
//    `gap` : les quatre jaquettes se touchent. Une gouttière ferait quatre vignettes ; son
//    absence fait une seule image.
// 2. **Le survol agrandit de 3 %, pas de 6 %.** La collection est plus large qu'une
//    affiche, donc le même facteur la ferait déborder davantage. Valeur du prototype,
//    reprise telle quelle.
// 3. **La couverture générée est un repli, pas la règle.** Une collection qui a sa propre
//    image l'affiche en plein cadre ; la mosaïque n'apparaît que faute de mieux.
//
// **Ce que ça règle pour le report de `L6`.** `L6` (générer un `MediaAsset` de mosaïque)
// est reportée en v1.1, et le report notait « reste en v1 : un repli calculé à
// l'affichage ». Ce repli **est** le design retenu : la mosaïque se compose à l'écran, à
// partir des jaquettes déjà chargées, et n'écrit rien. `L6` n'ajoutera qu'une chose — la
// possibilité d'en faire un asset exportable et partageable.

/// Ce dont une tuile de collection a besoin, et rien de plus.
///
/// Défini ici plutôt que dans `PresentationModels` : le lot reste autonome, et `I1` n'a pas
/// à être rouvert pour ça.
public struct CollectionTileModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Nombre de titres, déjà formaté par l'appelant — `DesignSystem` ne localise rien.
    public let countLabel: String?
    /// La couverture propre de la collection, si elle en a une. Priorité sur la mosaïque.
    public let coverURL: URL?
    /// Jusqu'à quatre jaquettes pour composer la mosaïque de repli. Au-delà, ignorées.
    public let artwork: [URL]
    public let isPrivate: Bool

    public init(
        id: String,
        name: String,
        countLabel: String? = nil,
        coverURL: URL? = nil,
        artwork: [URL] = [],
        isPrivate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.countLabel = countLabel
        self.coverURL = coverURL
        self.artwork = artwork
        self.isPrivate = isPrivate
    }

    public var accessibilityDescription: String {
        var parts = [name]
        if let countLabel { parts.append(countLabel) }
        if isPrivate { parts.append("privé") }
        return parts.joined(separator: ", ")
    }
}

/// Une collection : sa couverture ou une mosaïque de quatre jaquettes, puis son nom.
public struct CollectionTile: View {
    private let model: CollectionTileModel
    private let scale: PosterScale
    private let action: (() -> Void)?

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ model: CollectionTileModel,
        scale: PosterScale = .l,
        action: (() -> Void)? = nil
    ) {
        self.model = model
        self.scale = scale
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: Space.s3) {
                cover
                caption
            }
            .frame(width: scale.width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && action != nil ? 1.03 : 1)
        .animation(reduceMotion ? Motion.instant : Motion.fast, value: isHovering)
        .onHover { isHovering = $0 }
        .focusable(action != nil)
        .accessibilityLabel(model.accessibilityDescription)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }

    /// Toujours en 16:9 : une collection est un rayonnage, pas une affiche. `CardLayout`
    /// n'est donc pas exposé — la matrice le règle par contexte, et le défaut de
    /// `PosterContext.collections` est déjà `landscape`.
    private var cover: some View {
        Group {
            if model.isPrivate {
                privateMask
            } else if let coverURL = model.coverURL {
                MediaFill(
                    imageURL: coverURL,
                    crop: .neutral,
                    targetAspect: CardLayout.landscape.aspectRatio,
                    background: Color.bgSurface)
            } else {
                mosaic
            }
        }
        .frame(
            width: scale.width,
            height: scale.width / CardLayout.landscape.aspectRatio
        )
        .clipped()
    }

    /// La mosaïque 2 × 2, **sans espacement** — le `grid` du prototype n'a pas de `gap`.
    ///
    /// Les replis à trois, deux et une jaquette sont des dispositions différentes, pas des
    /// cases vides : une grille 2 × 2 avec deux trous se lit comme une image cassée. La
    /// fiche `L6` demandait déjà « repli propre à 1, 2, 3 jaquettes », et c'est ici que ça
    /// se joue puisque la mosaïque est calculée à l'affichage.
    @ViewBuilder private var mosaic: some View {
        let art = Array(model.artwork.prefix(4))
        switch art.count {
        case 0:
            Color.bgSurface
        case 1:
            tile(art[0])
        case 2:
            // Deux colonnes pleine hauteur : plus lisible que deux quarts.
            HStack(spacing: 0) {
                tile(art[0])
                tile(art[1])
            }
        case 3:
            // Une grande à gauche, deux empilées à droite.
            HStack(spacing: 0) {
                tile(art[0])
                VStack(spacing: 0) {
                    tile(art[1])
                    tile(art[2])
                }
            }
        default:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tile(art[0])
                    tile(art[1])
                }
                HStack(spacing: 0) {
                    tile(art[2])
                    tile(art[3])
                }
            }
        }
    }

    private func tile(_ url: URL) -> some View {
        MediaFill(
            imageURL: url, crop: .neutral,
            targetAspect: CardLayout.portrait.aspectRatio,
            background: Color.bgSurface)
    }

    private var privateMask: some View {
        Color.privateMask.overlay {
            Image(systemName: Icon.isPrivate)
                .font(.system(size: min(scale.width * 0.16, 28)))
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.name)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            // Réservée même vide, comme pour `PersonTile` : sinon une rangée où une seule
            // collection porte un compte voit toutes ses tuiles se désaligner.
            Text(model.countLabel ?? " ")
                .font(Typo.label)
                .tracking(Typo.Tracking.label)
                .textCase(.uppercase)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Échantillons

extension CollectionTileModel {
    /// De quoi éprouver les quatre replis de mosaïque, plus le privé. Les URL sont
    /// factices : les previews exercent ainsi l'état de chargement, comme le reste du
    /// catalogue.
    public static let samples: [CollectionTileModel] = {
        let art = (1...4).compactMap { URL(string: "https://exemple.test/\($0).jpg") }
        return [
            .init(id: "c4", name: "Trilogie du Parrain", countLabel: "4 titres", artwork: art),
            .init(
                id: "c3", name: "Nouvelle Vague", countLabel: "3 titres",
                artwork: Array(art.prefix(3))),
            .init(
                id: "c2", name: "Diptyque de Kieślowski", countLabel: "2 titres",
                artwork: Array(art.prefix(2))),
            .init(id: "c1", name: "Hors série", countLabel: "1 titre", artwork: [art[0]]),
            .init(id: "c0", name: "Collection vide"),
            .init(id: "cp", name: "Collection privée", countLabel: "7 titres", isPrivate: true)
        ]
    }()
}

#Preview("Replis de mosaïque") {
    HStack(alignment: .top, spacing: Space.s4) {
        ForEach(CollectionTileModel.samples) { collection in
            CollectionTile(collection, scale: .l) {}
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
