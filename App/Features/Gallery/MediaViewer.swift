import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V3 · La visionneuse et le mode immersif — blocs `6c` et `6d`
//
// **Deux blocs, un seul écran, et c'est le design qui le dit** : `6d` est décrit comme
// « défilement immersif · une image par écran, aucun chrome, la suivante affleure ». Ce n'est
// pas une autre surface, c'est la même sans son chrome. En faire deux vues aurait dupliqué le
// chargement d'image et la navigation entre médias.
//
// **Ce que `6c` porte, et qui n'est pas négociable** : fond `bg.viewer`, image en `contain` —
// donc **avec** bandes, à l'inverse de partout ailleurs — compteur « 12 / 47 », ligne de
// description, deux cibles de 44 pt sur les côtés, et une bande de vignettes en bas.
//
// **Pourquoi `contain` ici alors que la règle du système est « remplit et recadre ».** Parce
// que c'est le seul endroit où l'on regarde l'image *pour elle-même* : la recadrer serait
// cacher une partie de ce qu'on est venu voir. Le §3 ne parle de remplissage que pour les
// **fonds de hero**, et le prototype de `6c` écrit `object-fit:contain` noir sur blanc.
//
// **Présentation : feuille sur Mac, plein écran sur iOS.** `fullScreenCover` n'existe pas sur
// macOS, et une feuille y est déjà une surface pleine qu'on ferme par ⎋. C'est le même choix
// que `CropEditor`, livré par `V2 bis`.

struct MediaViewer: View {
    let assets: [MediaAsset]
    @Binding var index: Int

    let onCrop: (MediaAsset) -> Void

    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Le mode immersif : le chrome s'efface, l'image prend tout.
    @State private var isImmersive = false
    /// Le facteur de zoom, borné. `1` ajuste, le double-clic fait l'aller-retour.
    @State private var zoom: CGFloat = 1
    /// Le zoom au **début** du pincement.
    ///
    /// **`MagnifyGesture` rend une valeur cumulée depuis le début du geste**, pas un
    /// incrément : repartir de `zoom` à chaque notification composerait le mouvement, et
    /// l'image grossirait de plus en plus vite pour un doigt qui avance régulièrement. C'est
    /// exactement le défaut trouvé dans `CropEditor` à `V2 bis`, et `CropGestureTests` le
    /// verrouille là-bas ; ici il n'y a rien à verrouiller de plus, seulement à ne pas le
    /// refaire.
    @State private var zoomAtGestureStart: CGFloat = 1

    /// Le zoom ne descend pas sous « ajusté » et ne monte pas à quatre fois.
    ///
    /// La borne basse est la seule qui compte vraiment : sous 1, l'image rétrécirait dans un
    /// écran noir, ce qui n'est pas un cadrage mais une perte.
    private static let zoomBounds: ClosedRange<CGFloat> = 1...4

    var body: some View {
        ZStack {
            Color.bgViewer.ignoresSafeArea()
            image
            if !isImmersive {
                chrome
                if zoom > 1 { zoomBadge }
            } else {
                immersiveCounter
            }
        }
        .gesture(magnify)
        .frame(minWidth: 640, minHeight: 480)
        // La visionneuse est une surface de visionnage : sombre dans les quatre apparences,
        // et `bg/viewer` est d'ailleurs identique dans les quatre — c'est le seul jeton du
        // système dans ce cas.
        .preferredColorScheme(.dark)
        .onTapGesture(count: 2) { zoom = zoom > 1 ? Self.zoomBounds.lowerBound : 2 }
        // ⎋ ferme, et **seulement sur Mac** : `onExitCommand` est indisponible sur iOS, où le
        // geste est le balayage vers le bas que `fullScreenCover` fournit déjà.
        #if os(macOS)
            .onExitCommand { dismiss() }
        #endif
        // ⌥ pour le mode immersif, ← → pour changer d'image : trois raccourcis, et les trois
        // sont indispensables au clavier sur Mac (règle d'accessibilité du projet).
        .background { shortcuts }
    }

    private var current: MediaAsset? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    // MARK: L'image

    @ViewBuilder private var image: some View {
        if let current {
            MediaFit(
                imageURL: AssetURL.url(for: current.id, preset: .hero),
                blurHash: current.blurHash
            )
            .accessibilityLabel(GalleryFormat.caption(of: current))
            .scaleEffect(zoom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            // Changer d'image remet le zoom à plat : garder un zoom de 4 en passant à la
            // suivante montrerait le coin haut gauche d'une image qu'on n'a pas choisi
            // d'agrandir.
            .onChange(of: index) { _, _ in zoom = 1 }
        }
    }

    /// Le pincement, borné par `zoomBounds`.
    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(
                    max(zoomAtGestureStart * value.magnification, Self.zoomBounds.lowerBound),
                    Self.zoomBounds.upperBound)
            }
            .onEnded { _ in zoomAtGestureStart = zoom }
    }

    /// « 180 % · double-clic pour ajuster » — bloc `6c`, en bas à gauche.
    ///
    /// Il n'apparaît **qu'au-delà de 1** : à l'ajusté, il n'y aurait rien à dire, et une
    /// pastille permanente sur une visionneuse est du bruit posé sur l'image.
    private var zoomBadge: some View {
        Text("\(Int(zoom * 100)) % · double-clic pour ajuster")
            .font(Typo.micro)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2)
            .background(Color.bgViewer.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, Space.s5)
            .padding(.bottom, 104)
            .allowsHitTesting(false)
    }

    // MARK: Le chrome — bloc `6c`

    @ViewBuilder private var chrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            thumbnailStrip
        }
        .overlay(alignment: .leading) { step(-1, symbol: Icon.previousImage) }
        .overlay(alignment: .trailing) { step(+1, symbol: Icon.nextImage) }
    }

    private var topBar: some View {
        HStack(spacing: Space.s4) {
            Button {
                dismiss()
            } label: {
                Label("Fermer", systemImage: Icon.close)
                    .labelStyle(.iconOnly)
                    .frame(width: Space.minHitTarget, height: Space.minHitTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textPrimary)

            Text(GalleryFormat.counter(index, of: assets.count))
                .font(Typo.micro)
                .foregroundStyle(Color.textSecondary)

            if let current {
                Text(GalleryFormat.caption(of: current))
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s4)
            topActions
        }
        .padding(.horizontal, Space.s5)
        .frame(height: 64)
        // Le dégradé du prototype, et non un aplat : l'image passe dessous, donc une barre
        // opaque la couperait. C'est la seule superposition de l'app qui ne soit pas un fond
        // plein — et elle n'est pas un matériau pour autant.
        .background {
            LinearGradient(
                colors: [Color.bgViewer.opacity(0.8), Color.bgViewer.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder private var topActions: some View {
        HStack(spacing: Space.s5) {
            if let current, let flags {
                Button(flags.isFavorite(current) ? "Favori" : "Ajouter aux favoris") {
                    flags.toggleFavorite(current)
                }
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(flags.isFavorite(current) ? Color.accent : Color.textPrimary)
                .frame(minHeight: Space.minHitTarget)
            }
            if let current {
                Button("Recadrer") { onCrop(current) }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textPrimary)
                    .frame(minHeight: Space.minHitTarget)
            }
            Button("Immersif") { isImmersive = true }
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textPrimary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    /// Les deux cibles de 44 pt du prototype. Désactivées aux extrémités plutôt que
    /// masquées : un bouton qui disparaît déplace ce qui reste, et on clique à côté.
    private func step(_ offset: Int, symbol: String) -> some View {
        Button {
            index = min(max(index + offset, 0), assets.count - 1)
        } label: {
            Image(systemName: symbol)
                .font(Typo.action)
                .frame(width: Space.minHitTarget, height: Space.minHitTarget)
                .background(Color.fillOnImage)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.textPrimary)
        .padding(Space.s5)
        .disabled(!assets.indices.contains(index + offset))
    }

    /// La bande de vignettes du bas — 44 × 56 dans le prototype, à 55 % d'opacité sauf la
    /// courante.
    private var thumbnailStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.s2) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { position, asset in
                    Button {
                        index = position
                    } label: {
                        MediaFit(
                            imageURL: AssetURL.url(for: asset.id, preset: .thumb),
                            blurHash: asset.blurHash,
                            background: Color.bgSurface
                        )
                        .frame(width: 44, height: 56)
                        .opacity(position == index ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.s5)
        }
        .scrollIndicators(.hidden)
        .frame(height: 88)
        .background {
            LinearGradient(
                colors: [Color.bgViewer.opacity(0), Color.bgViewer.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Le mode immersif — bloc `6d`

    /// « The Batman · galerie » puis « Image 14 sur 47 », en bas à gauche.
    ///
    /// **C'est tout ce que le mode immersif garde**, et le bloc est explicite : « aucun
    /// chrome ». Le compteur reste parce que sans lui on ne sait plus où l'on est dans une
    /// série de quarante-sept images.
    @ViewBuilder private var immersiveCounter: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Spacer(minLength: 0)
            if let current, let owner = GalleryFormat.owner(of: current) {
                Text(owner)
                    .labelStyle()
                    .foregroundStyle(Color.accent)
            }
            Text(GalleryFormat.position(index, of: assets.count))
                .title1Style()
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s6)
        .contentShape(.rect)
        .onTapGesture { isImmersive = false }
    }

    // MARK: Clavier

    /// Les raccourcis, posés sur des boutons invisibles.
    ///
    /// **`.keyboardShortcut` a besoin d'un bouton**, et les trois gestes n'en ont pas tous un
    /// visible — le mode immersif n'affiche rien à cliquer. Un `.background` de boutons vides
    /// est la forme habituelle ; ils restent atteignables au clavier, ce que le projet exige.
    @ViewBuilder private var shortcuts: some View {
        Group {
            Button("Précédente") { index = max(index - 1, 0) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(index == 0)
            Button("Suivante") { index = min(index + 1, assets.count - 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(index >= assets.count - 1)
            Button("Immersif") { isImmersive.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private var flags: FlagRepository? {
        session.current.map { FlagRepository(context: modelContext, profile: $0) }
    }
}

// MARK: - La présentation, pour que les deux écrans l'appellent d'une ligne

extension View {

    /// Présente la visionneuse sur l'index donné, `nil` la fermant.
    ///
    /// Un modificateur plutôt qu'un `sheet` recopié : la galerie **et** la fiche titre
    /// l'ouvrent, et la différence de présentation entre iOS et macOS n'a pas à être écrite
    /// deux fois.
    func mediaViewer(
        index: Binding<Int?>,
        assets: [MediaAsset],
        onCrop: @escaping (MediaAsset) -> Void
    ) -> some View {
        modifier(MediaViewerPresentation(index: index, assets: assets, onCrop: onCrop))
    }
}

private struct MediaViewerPresentation: ViewModifier {
    @Binding var index: Int?
    let assets: [MediaAsset]
    let onCrop: (MediaAsset) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
            content.fullScreenCover(isPresented: presented) { viewer }
        #else
            content.sheet(isPresented: presented) { viewer }
        #endif
    }

    /// Un `Bool` dérivé de l'index, et non `sheet(item:)`.
    ///
    /// **La visionneuse a besoin d'un `Binding<Int>` mutable** : les flèches et la bande de
    /// vignettes changent l'image affichée sans refermer la surface. `sheet(item:)` passe une
    /// **valeur**, donc chaque changement d'image aurait refermé puis réouvert la feuille.
    private var presented: Binding<Bool> {
        Binding(get: { index != nil }, set: { if !$0 { index = nil } })
    }

    @ViewBuilder private var viewer: some View {
        if let start = index {
            MediaViewer(
                assets: assets,
                index: Binding(get: { index ?? start }, set: { index = $0 }),
                onCrop: { asset in
                    // Refermer avant d'ouvrir l'éditeur : deux surfaces modales superposées
                    // sont exactement ce que le §7 interdit — « un seul plan modal à la fois,
                    // une feuille ne s'ouvre pas au-dessus d'un dialogue, elle le remplace ».
                    index = nil
                    onCrop(asset)
                })
        }
    }
}
