import SwiftUI

// MARK: - I2 · La tuile détaillée
//
// Relevée sur la planche 3 bloc 4a (grille des titres), sur l'élément mis en avant :
//
//     <div style="background:oklch(0.15 0 0);transform:scale(1.1);transform-origin:left top">
//       <div style="aspect-ratio:2/3;overflow:hidden"><img …></div>
//       <div style="padding:8px 9px 10px">
//         <span style="font:600 12px 'Archivo Narrow'">Dune</span>
//         <span style="font:400 9px 'Archivo Narrow';letter-spacing:0.1em;uppercase">
//           2021 · 2 h 35 · <span style="color:accent">★ 4,5</span></span>
//         <div>Ouvrir · ✓ Vu · ···</div>
//       </div>
//     </div>
//
// **Ce n'est pas une variante de `PosterTile`, c'est un autre composant.** La tuile nue
// est une image ; celle-ci est une image **plus un pavé de texte et trois actions**, sur
// un fond qui descend sous l'image. Les mettre dans la même vue derrière un booléen aurait
// donné un composant dont la moitié du corps ne sert jamais dans le cas courant — et le
// cas courant, c'est deux cents tuiles nues à l'écran.
//
// `transform-origin: left top` est significatif : la tuile détaillée grandit **vers la
// droite et vers le bas**, elle ne pousse pas ses voisines et ne sort pas de la marge
// gauche. C'est ce qui permet de l'afficher en place dans une grille.

/// L'affiche avec ses métadonnées et ses actions — l'état mis en avant d'une grille.
public struct PosterTileDetail: View {
    private let model: PosterCardModel
    private let layout: CardLayout
    private let scale: PosterScale
    private let onOpen: (() -> Void)?
    private let onToggleWatched: (() -> Void)?
    private let onMore: (() -> Void)?

    public init(
        _ model: PosterCardModel,
        layout: CardLayout = .portrait,
        scale: PosterScale = .l,
        onOpen: (() -> Void)? = nil,
        onToggleWatched: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil
    ) {
        self.model = model
        self.layout = layout
        self.scale = scale
        self.onOpen = onOpen
        self.onToggleWatched = onToggleWatched
        self.onMore = onMore
    }

    public var body: some View {
        let size = scale.size(layout)
        VStack(alignment: .leading, spacing: 0) {
            PosterTile(model, layout: layout, scale: scale, action: onOpen)
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(model.title)
                    .font(Typo.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                metaLine
                actions
            }
            .padding(.horizontal, Space.s2)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
            .frame(width: size.width, alignment: .leading)
        }
        // Le fond descend **sous** l'image et englobe le texte : c'est ce qui fait que la
        // tuile détaillée se lit comme un bloc et non comme une image suivie d'une légende.
        .background(Color.bgSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityDescription)
    }

    /// « 2021 · 2 h 35 · ★ 4,5 » — la note en accent, le reste en gris.
    ///
    /// La méta arrive **déjà formatée** dans le modèle (`PosterCardModel.meta`) : le
    /// composant ne sait ni formater une durée ni localiser une date, et c'est voulu —
    /// `DesignSystem` ne dépend de rien.
    @ViewBuilder private var metaLine: some View {
        if model.meta != nil || model.rating != nil {
            HStack(spacing: Space.s1) {
                if let meta = model.meta {
                    Text(meta)
                        .font(Typo.label)
                        .tracking(Typo.Tracking.label)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.textTertiary)
                }
                if let rating = model.rating {
                    Label {
                        // Chiffres tabulaires et virgule décimale : `Typo.numeric` est
                        // tabulaire, et le format suit la locale — « 4,5 » en français.
                        Text(rating.formatted(.number.precision(.fractionLength(0...1))))
                    } icon: {
                        Image(systemName: Icon.ratingStar)
                    }
                    .font(Typo.numeric)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accent)
                }
            }
            .lineLimit(1)
        }
    }

    /// Les trois pastilles du prototype, sur `rgba(white, 0.12)` — soit `fill/onImage`.
    ///
    /// Elles ne sont posées que si l'appelant fournit l'action correspondante : une
    /// pastille inerte est pire qu'une pastille absente, et c'est un défaut que le banc
    /// d'essai a déjà (les raccourcis d'import grisés).
    @ViewBuilder private var actions: some View {
        HStack(spacing: Space.s1) {
            if let onOpen { pill("Ouvrir", symbol: nil, action: onOpen) }
            if let onToggleWatched {
                pill(
                    model.isWatched ? "Vu" : "Marquer vu",
                    symbol: Icon.watchedMark, action: onToggleWatched)
            }
            if let onMore { pill(nil, symbol: Icon.moreActions, action: onMore) }
        }
        .padding(.top, Space.s1)
    }

    private func pill(
        _ title: LocalizedStringKey?, symbol: String?, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s1) {
                if let symbol { Image(systemName: symbol) }
                if let title { Text(title) }
            }
            .font(Typo.action)
            .tracking(Typo.Tracking.action)
            .textCase(.uppercase)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Space.s2)
            .padding(.vertical, Space.s1)
            .background(Color.fillOnImage)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // La cible tactile de 44 pt ne peut pas être atteinte par la pastille elle-même —
        // le prototype la dessine à 17 pt de haut, et l'agrandir casserait la composition.
        // Le contour tactile est donc étendu sans changer le dessin. C'est la seule façon
        // de tenir la règle des 44 pt sans trahir la planche.
        .frame(minWidth: Space.minHitTarget * 0.6, minHeight: Space.s5, alignment: .leading)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Tuile détaillée") {
    HStack(alignment: .top, spacing: Space.s4) {
        PosterTileDetail(.sample, scale: .l, onOpen: {}, onToggleWatched: {}, onMore: {})
        PosterTileDetail(.samples[4], scale: .l, onOpen: {})
        PosterTileDetail(.samples[6], scale: .l, onOpen: {}, onToggleWatched: {}, onMore: {})
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
