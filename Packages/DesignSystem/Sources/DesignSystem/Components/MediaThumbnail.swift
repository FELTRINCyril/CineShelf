import SwiftUI

// MARK: - Chargement d'image — injecté, jamais fait ici
//
// DesignSystem ne connaît ni le réseau, ni le cache, ni le disque de l'app.
// L'hôte fournit une closure asynchrone ; le package ne fournit qu'un stub.

public struct ImageLoader: Sendable {
    public typealias Load = @Sendable (URL) async throws -> Image

    private let load: Load
    public init(_ load: @escaping Load) { self.load = load }

    public func callAsFunction(_ url: URL) async throws -> Image { try await load(url) }

    /// Stub : n'aboutit jamais, laisse le placeholder en place. Défaut des previews.
    public static let stub = ImageLoader { _ in
        try await Task.sleep(for: .seconds(3600))
        throw CancellationError()
    }

    /// Stub différé : résout un aplat de couleur après un délai — utile pour
    /// vérifier la transition sans réseau.
    public static func stubbed(after delay: Duration = .milliseconds(600)) -> ImageLoader {
        ImageLoader { _ in
            try await Task.sleep(for: delay)
            return Image(systemName: Icon.titles)
        }
    }
}

extension EnvironmentValues {
    @Entry public var imageLoader: ImageLoader = .stub
}

extension View {
    public func imageLoader(_ loader: ImageLoader) -> some View {
        environment(\.imageLoader, loader)
    }
}

// MARK: - MediaThumbnail
//
// blurhash → vignette locale → image, sans saut de mise en page :
// le cadre est posé par l'aspect AVANT tout chargement.

public struct MediaThumbnail: View {
    @Environment(\.imageLoader) private var loader
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let url: URL?
    private let blurHash: String?
    private let aspect: CGFloat
    private let radius: CGFloat
    private let fallbackSymbol: String
    private let label: String?
    private let crop: MediaCropDisplay

    @State private var phase: Phase = .placeholder

    private enum Phase: Equatable {
        case placeholder
        case loaded(Image)
        case failed

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.placeholder, .placeholder), (.failed, .failed): true
            case (.loaded, .loaded): true
            default: false
            }
        }
    }

    public init(
        url: URL?,
        blurHash: String? = nil,
        aspect: CGFloat = Ratio.poster,
        radius: CGFloat = Radius.lg,
        fallbackSymbol: String = Icon.titles,
        label: String? = nil,
        crop: MediaCropDisplay = .neutral
    ) {
        self.url = url
        self.blurHash = blurHash
        self.aspect = aspect
        self.radius = radius
        self.fallbackSymbol = fallbackSymbol
        self.label = label
        self.crop = crop
    }

    public init(_ model: MediaThumbnailModel, radius: CGFloat = Radius.lg) {
        self.init(
            url: model.imageURL, blurHash: model.blurHash, aspect: model.aspect,
            radius: radius, label: model.caption, crop: model.crop)
    }

    /// L'image, positionnée selon son recadrage.
    ///
    /// **Sans `sourceAspect`, on retombe sur `scaledToFill`** — le remplissage centré
    /// d'avant `L4`. C'est le cas d'un média dont les dimensions ne sont pas
    /// enregistrées et des aperçus du catalogue : moins fidèle au recadrage choisi,
    /// mais jamais cassé.
    ///
    /// Avec, le calcul reproduit exactement `CropGeometry.sourceRect` : l'image est
    /// posée à sa taille « couvrir », multipliée par le zoom, puis décalée du jeu
    /// restant au prorata de `focus`. C'est la même arithmétique, écrite une fois en
    /// pixels source et une fois en points.
    ///
    /// > **Leur accord est vérifié, pas espéré.**
    /// > `CropRenderingAgreementTests.bothImplementationsAgree` recopie ces quatre
    /// > lignes et affirme qu'elles désignent le même morceau d'image que
    /// > `CropGeometry.sourceRect`, sur un balayage de positions, de zooms et de
    /// > ratios. Modifier ce corps sans modifier l'autre casse ce test.
    @ViewBuilder
    private func cropped(_ image: Image) -> some View {
        if let sourceAspect = crop.sourceAspect, sourceAspect > 0 {
            GeometryReader { proxy in
                let box = proxy.size
                let cover = max(box.width / sourceAspect, box.height)
                let rendered = CGSize(width: cover * sourceAspect * crop.zoom, height: cover * crop.zoom)
                let slack = CGSize(
                    width: max(0, rendered.width - box.width),
                    height: max(0, rendered.height - box.height))

                image
                    .resizable()
                    .frame(width: rendered.width, height: rendered.height)
                    .offset(x: -slack.width * crop.focus.x, y: -slack.height * crop.focus.y)
            }
        } else {
            image
                .resizable()
                .scaledToFill()
        }
    }

    public var body: some View {
        placeholderLayer
            .overlay {
                if case .loaded(let image) = phase {
                    cropped(image)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .dsClip(radius)
            // Le liseré tient le bord des jaquettes sombres sur le canevas presque noir.
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.mediaRing, lineWidth: 1)
            }
            .dsAnimation(Motion.base, value: phase)
            .task(id: url) { await load() }
            .accessibilityElement()
            .accessibilityLabel(label ?? "Image")
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var placeholderLayer: some View {
        ZStack {
            Color.mediaPlaceholder
            if let blurHash, let gradient = BlurHashPreview.gradient(from: blurHash) {
                gradient
            } else if phase == .failed || url == nil {
                Image(systemName: fallbackSymbol)
                    .font(.system(.title2))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.textTertiary)
            }
        }
    }

    private func load() async {
        guard let url else {
            phase = .failed
            return
        }
        phase = .placeholder
        do {
            let image = try await loader(url)
            guard !Task.isCancelled else { return }
            phase = .loaded(image)
        } catch is CancellationError {
            // Vue disparue ou URL changée : on ne touche à rien.
        } catch {
            phase = .failed
        }
    }
}

/// Approximation légère d'un blurhash : dégradé à partir des composantes moyennes.
/// À remplacer par un vrai décodeur si le besoin se confirme — l'API ne bouge pas.
enum BlurHashPreview {
    static func gradient(from hash: String) -> LinearGradient? {
        guard hash.count >= 6 else { return nil }
        let seed = hash.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let base = Color(
            hue: Double(seed % 360) / 360,
            saturation: 0.10,
            brightness: 0.18
        )
        return LinearGradient(
            colors: [base.opacity(0.9), base.opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview {
    HStack(spacing: Space.lg) {
        MediaThumbnail(url: nil, aspect: Ratio.poster).frame(width: 148)
        MediaThumbnail(url: URL(string: "https://example.com/a.jpg"), blurHash: "L6PZfSjE.A", aspect: Ratio.poster)
            .frame(width: 148)
    }
    .padding()
    .background(.bgCanvas)
}
