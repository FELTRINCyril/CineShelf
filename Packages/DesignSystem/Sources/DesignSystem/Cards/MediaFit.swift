import SwiftUI

// MARK: - V3 · L'image montrée pour elle-même
//
// **Le pendant de `MediaFill`, et le seul endroit du système qui laisse des bandes.** Partout
// ailleurs la règle est « remplit et recadre, jamais de bande » — une affiche, une tuile, un
// fond de hero. Dans la visionneuse (bloc `6c`), elle s'inverse :
//
//     <img style="height:100%;width:auto;object-fit:contain">
//
// La raison est dans ce qu'on regarde. Une tuile est un **cadre** qu'une image remplit ; la
// visionneuse est une **image** qu'on est venu voir en entier, et la recadrer y cacherait
// précisément ce qu'on cherche. C'est aussi pourquoi elle ne consomme aucun `MediaCrop` : le
// recadrage décrit comment l'image entre dans un cadre, et il n'y a pas de cadre ici.
//
// **Pourquoi un composant et pas un `AsyncImage` dans l'écran.** Deux raisons, et la seconde
// est celle qui a coûté quatre sessions : `AsyncImage` **ne sait pas résoudre**
// `cineshelf-asset://`, le schéma interne du cache de vignettes — c'est exactement le défaut
// qui a rendu toutes les affiches invisibles depuis `I2`. Le chargement passe donc par
// `\.imageLoader`, comme `MediaFill`, et jamais par le réseau.

/// Une image entière, centrée dans la place disponible, bandes comprises.
public struct MediaFit: View {
    private let imageURL: URL?
    private let blurHash: String?
    private let background: Color

    @Environment(\.imageLoader) private var loader
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .loading

    /// Les trois états de `MediaFill`, pour la même raison : sans l'échec, « en cours » et
    /// « raté » rendent le même pixel, et toute porte visuelle est aveugle sur les deux.
    private enum Phase: Equatable {
        case loading
        case loaded(Image)
        case failed
    }

    public init(imageURL: URL?, blurHash: String? = nil, background: Color = Color.bgViewer) {
        self.imageURL = imageURL
        self.blurHash = blurHash
        self.background = background
    }

    public var body: some View {
        ZStack {
            background
            switch phase {
            case .loaded(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(reduceMotion ? .identity : .opacity)
            case .loading:
                if let blurHash, let gradient = BlurHashPreview.gradient(from: blurHash) {
                    // Le blurhash est **flouté et non ajusté** : à la taille d'un écran, un
                    // dégradé net se lirait comme une image qu'on a vraiment chargée.
                    gradient.blur(radius: Space.s5)
                }
            case .failed:
                Image(systemName: Icon.error)
                    .font(.system(.title2))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .dsAnimation(Motion.base, value: phase)
        .task(id: imageURL) { await load() }
    }

    private func load() async {
        phase = .loading
        guard let imageURL else {
            phase = .failed
            return
        }
        do {
            let image = try await loader(imageURL)
            guard !Task.isCancelled else { return }
            phase = .loaded(image)
        } catch is CancellationError {
            // Surface partie ou image changée : on ne touche à rien. Marquer `failed` ferait
            // clignoter un symbole d'erreur à chaque coup de flèche.
        } catch {
            phase = .failed
        }
    }
}

#Preview("Visionneuse · trois états") {
    HStack(spacing: 0) {
        MediaFit(imageURL: nil)
        MediaFit(imageURL: URL(string: "https://exemple.test/a.jpg"), blurHash: "L6PZfSjE.A")
        MediaFit(imageURL: URL(string: "https://exemple.test/b.jpg"))
    }
    .frame(height: 240)
    .environment(\.imageLoader, .stubbed())
}
