import SwiftUI

// MARK: - I2 · La tuile d'affiche
//
// La carte de la direction « 2a Plein cadre », relevée sur la planche 1 bloc 2a et la
// planche 3 bloc 4a :
//
//     <div style="width:172px;aspect-ratio:2/3;background:oklch(0.16 0 0);overflow:hidden"
//          style-hover="transform:scale(1.06)">
//       <img style="width:100%;height:100%;object-fit:cover">
//     </div>
//
// Quatre choses s'y lisent, et toutes les quatre sont des ruptures avec l'ancienne
// direction :
//
// 1. **Aucun rayon.** Angles vifs. `Radius` n'intervient pas — la tuile n'est pas une
//    carte posée sur un fond, c'est un pavé d'image.
// 2. **Aucune ombre, aucune bordure.** Ce que la règle de lint `no_legacy_design_system`
//    impose déjà.
// 3. **Aucun texte dans la tuile.** Le titre ne s'affiche pas sous l'image dans les rails
//    ni dans la grille : l'affiche parle seule. Les métadonnées apparaissent au survol,
//    et c'est `PosterTileDetail` qui les porte.
// 4. **Le survol agrandit** de 6 %, il n'entoure pas. Pas de liseré — le liseré était la
//    direction 1a, écartée.
//
// **Pourquoi un seul composant pour l'affiche et le paysage.** Le brief les compte comme
// deux (« carte affiche · carte paysage »), mais la différence est le **ratio**, et le
// ratio est déjà une donnée du système : `CardLayout`. En faire deux vues dupliquerait le
// remplissage, le recadrage, le masque privé et le survol — et la matrice
// `disposition × taille` est une **fonctionnalité de l'app**, mémorisée par contexte, pas
// une variante de dessin. Deux composants l'auraient trahie au premier écran qui bascule.

/// Une affiche, en portrait 2:3 ou en paysage 16:9, à l'un des six crans.
///
/// **Nommée `PosterTile` et non `PosterCard`** : ce dernier nom est pris par le composant
/// de l'ancienne direction, qui vit dans `Components/` jusqu'à `V12`. Même situation que
/// `Icon.ratingStar`, et le nom court se libérera avec `Legacy/`.
public struct PosterTile: View {
    private let model: PosterCardModel
    private let layout: CardLayout
    private let scale: PosterScale
    private let isSelected: Bool
    private let action: (() -> Void)?

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ model: PosterCardModel,
        layout: CardLayout = .portrait,
        scale: PosterScale = .m,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.model = model
        self.layout = layout
        self.scale = scale
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        let size = scale.size(layout)
        Button {
            action?()
        } label: {
            surface
                .frame(width: size.width, height: size.height)
                // `clipped()` et non `clipShape` : il n'y a pas de forme, juste des bords
                // vifs. `overflow: hidden` du prototype.
                .clipped()
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Le grossissement est un effet de **survol**, donc sans objet au doigt : `onHover`
        // ne se déclenche pas sur un écran tactile, et c'est le comportement voulu — la
        // planche montre un état de pointeur.
        .scaleEffect(magnification)
        .animation(reduceMotion ? Motion.instant : Motion.fast, value: isHovering)
        .onHover { isHovering = $0 }
        // Le focus clavier est obligatoire sur macOS (règle du projet : tout élément
        // interactif accessible au clavier). Il emprunte le même grossissement que le
        // survol plutôt qu'un anneau, pour rester dans la direction.
        .focusable(action != nil)
        .accessibilityLabel(model.accessibilityDescription)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }

    /// 1.06 au survol, comme le prototype. La sélection ne grossit pas : deux tuiles
    /// sélectionnées côte à côte se chevaucheraient.
    private var magnification: CGFloat {
        isHovering && action != nil ? 1.06 : 1
    }

    @ViewBuilder private var surface: some View {
        if model.isPrivate {
            privateMask
        } else {
            image
                .overlay(alignment: .topLeading) { stateBadge }
                .overlay { selectionVeil }
        }
    }

    /// Le fond avant chargement, et derrière une image transparente.
    ///
    /// `bgSurface` est le token le plus proche du `oklch(0.16 0 0)` du prototype —
    /// `bgFill` (0.25) serait trop clair et ferait une tuile grise au lieu d'un trou noir.
    /// L'écart exact est de trois centièmes de luminance, invisible à l'œil, et préférable
    /// à un jeton de plus dans la palette pour ce seul usage.
    private var image: some View {
        MediaFill(
            imageURL: model.imageURL,
            crop: model.crop,
            targetAspect: layout.aspectRatio,
            background: Color.bgSurface
        )
    }

    /// Le contenu privé est **remplacé**, pas flouté.
    ///
    /// Un flou reste une image : il laisse deviner la composition et se défait sur une
    /// capture d'écran. L'aplat `private.mask` ne laisse rien. C'est la contrepartie de
    /// l'arbitrage du privé — la seule erreur qui ne se répare pas est d'exposer.
    private var privateMask: some View {
        Color.privateMask
            .overlay {
                Image(systemName: Icon.isPrivate)
                    .font(.system(size: min(scale.width * 0.22, 28)))
                    .foregroundStyle(Color.textTertiary)
            }
    }

    /// Le bandeau d'état en haut à gauche. Un seul état à la fois : celui qui informe le
    /// plus.
    ///
    /// **Le badge lui-même appartient à `I6`** — cette vue l'a porté en propre le temps
    /// que le lot arrive, et n'en garde que la décision qui est bien de la tuile : à
    /// partir de quel cran il s'affiche, et lequel des trois états gagne.
    @ViewBuilder private var stateBadge: some View {
        if let text = badgeText, scale.width >= PosterScale.m.width {
            StateBadge(text)
                .padding(Space.s2)
        }
    }

    /// Précédence : archivé, puis vu, puis watchlist. Un titre archivé et vu est d'abord
    /// archivé — c'est l'information qui explique son absence des listes.
    private var badgeText: LocalizedStringKey? {
        if model.isArchived { return "Archivé" }
        if model.isWatched { return "Vu" }
        if model.isInWatchlist { return "À voir" }
        return nil
    }

    /// La sélection ne peut pas être un liseré — la direction n'en a pas. Un voile d'accent
    /// très léger, qui se lit sur une image claire comme sur une sombre.
    @ViewBuilder private var selectionVeil: some View {
        if isSelected {
            Color.accent.opacity(0.28)
        }
    }
}

// MARK: - Remplissage et recadrage

/// Une image qui **remplit** son cadre en respectant un recadrage, sans jamais laisser de
/// bande.
///
/// Extrait de la tuile parce que les trois composants de `I2` en ont besoin à l'identique,
/// et que `I3` (vignette de galerie, avatar) en aura besoin aussi. La règle du hero —
/// « remplit et recadre, jamais de bandes noires » — est la même ici.
struct MediaFill: View {
    let imageURL: URL?
    let crop: MediaCropDisplay
    let targetAspect: CGFloat
    let background: Color

    var body: some View {
        background.overlay {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(crop.zoom)
                            // `UnitPoint` de recadrage : `MediaCropDisplay.focus` est déjà
                            // exprimé en pourcentage du jeu restant (`L4`), donc il se
                            // passe tel quel à l'alignement.
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    } else {
                        // Ni indicateur ni symbole : un aplat. Un spinner sur une grille de
                        // deux cents affiches ferait clignoter tout l'écran au défilement,
                        // et le squelette de chargement est un composant à part (`I4`).
                        Color.clear
                    }
                }
            }
        }
    }

    /// L'alignement dérivé du point de focus. `.center` quand le recadrage est neutre —
    /// le cas de loin le plus fréquent, et celui où l'on ne veut aucun calcul.
    private var alignment: Alignment {
        if crop.focus == .center { return .center }
        return Alignment(
            horizontal: HorizontalAlignment(FocusHorizontal.self),
            vertical: VerticalAlignment(FocusVertical.self))
    }

    private enum FocusHorizontal: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.width / 2 }
    }
    private enum FocusVertical: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height / 2 }
    }
}

// MARK: - Previews

#Preview("Portrait, six crans") {
    HStack(alignment: .top, spacing: Space.s3) {
        ForEach(PosterScale.allCases) { scale in
            VStack(spacing: Space.s1) {
                PosterTile(.sample, layout: .portrait, scale: scale) {}
                Text(scale.rawValue).font(Typo.micro).foregroundStyle(Color.textTertiary)
            }
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}

#Preview("Paysage, six crans") {
    HStack(alignment: .top, spacing: Space.s3) {
        ForEach(PosterScale.allCases) { scale in
            PosterTile(.sample, layout: .landscape, scale: scale) {}
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}

#Preview("États") {
    HStack(spacing: Space.s3) {
        PosterTile(.samples[1], scale: .l) {}
        PosterTile(.samples[2], scale: .l) {}
        PosterTile(.samples[7], scale: .l) {}
        PosterTile(.samples[6], scale: .l) {}
        PosterTile(.sample, scale: .l, isSelected: true) {}
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
