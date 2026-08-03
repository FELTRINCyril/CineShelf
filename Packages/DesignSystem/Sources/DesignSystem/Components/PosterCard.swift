import SwiftUI

// MARK: - PosterCard
//
// Image + badges + titre + méta. Survol Mac (élévation + actions rapides),
// contextMenu, `matchedTransitionSource` pour la transition zoom vers la fiche.

public struct PosterCardActions: Sendable {
    public var toggleFavorite: (@Sendable @MainActor () -> Void)?
    public var toggleWatchlist: (@Sendable @MainActor () -> Void)?
    public var toggleWatched: (@Sendable @MainActor () -> Void)?
    public var edit: (@Sendable @MainActor () -> Void)?
    public var crop: (@Sendable @MainActor () -> Void)?
    public var archive: (@Sendable @MainActor () -> Void)?
    public var delete: (@Sendable @MainActor () -> Void)?

    public init(
        toggleFavorite: (@Sendable @MainActor () -> Void)? = nil,
        toggleWatchlist: (@Sendable @MainActor () -> Void)? = nil,
        toggleWatched: (@Sendable @MainActor () -> Void)? = nil,
        edit: (@Sendable @MainActor () -> Void)? = nil,
        crop: (@Sendable @MainActor () -> Void)? = nil,
        archive: (@Sendable @MainActor () -> Void)? = nil,
        delete: (@Sendable @MainActor () -> Void)? = nil
    ) {
        self.toggleFavorite = toggleFavorite
        self.toggleWatchlist = toggleWatchlist
        self.toggleWatched = toggleWatched
        self.edit = edit
        self.crop = crop
        self.archive = archive
        self.delete = delete
    }
}

public struct PosterCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let model: PosterCardModel
    private let metrics: CardMetrics
    private let actions: PosterCardActions
    private let transitionNamespace: Namespace.ID?
    private let onOpen: (() -> Void)?

    @State private var isHovering = false
    @State private var confirmDelete = false

    public init(
        _ model: PosterCardModel,
        metrics: CardMetrics = .portrait(.medium),
        actions: PosterCardActions = .init(),
        in namespace: Namespace.ID? = nil,
        onOpen: (() -> Void)? = nil
    ) {
        self.model = model
        self.metrics = metrics
        self.actions = actions
        self.transitionNamespace = namespace
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            poster
            caption
        }
        .frame(width: metrics.width, alignment: .leading)
        .opacity(model.isArchived ? 0.55 : 1)
        .contentShape(.rect(cornerRadius: metrics.radius, style: .continuous))
        .onTapGesture { onOpen?() }
        #if os(macOS)
            .onHover { hovering in isHovering = hovering }
        #endif
        .dsAnimation(Motion.quick, value: isHovering)
        .contextMenu { contextMenuContent }
        .confirmationDialog("Supprimer « \(model.title) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { actions.delete?() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Ouvrir la fiche")
    }

    // MARK: Jaquette

    private var poster: some View {
        MediaThumbnail(
            url: model.imageURL,
            blurHash: model.blurHash,
            aspect: metrics.aspect,
            radius: metrics.radius,
            fallbackSymbol: model.kind == .person ? Icon.people : Icon.titles,
            label: model.title
        )
        .overlay(alignment: .topTrailing) { badges }
        .overlay(alignment: .bottom) { hoverActions }
        .modifier(TransitionSource(id: model.id, namespace: transitionNamespace))
        #if os(macOS)
            .dsShadow(isHovering ? Elevation.media : Elevation.card)
            .scaleEffect(isHovering && !reduceMotion ? 1.02 : 1)
        #endif
    }

    @ViewBuilder
    private var badges: some View {
        let items: [Badge] = [
            model.isFavorite ? Badge(Icon.favorite.on, .accentText, "Favori") : nil,
            model.isInWatchlist ? Badge(Icon.watchlist.on, .textPrimary, "Watchlist") : nil,
            model.isPrivate ? Badge(Icon.isPrivate, .statePrivate, "Privé") : nil,
            model.isArchived ? Badge(Icon.archived, .stateArchived, "Archivé") : nil
        ].compactMap { $0 }

        if !items.isEmpty {
            HStack(spacing: Space.xxs) {
                ForEach(items) { badge in
                    Image(systemName: badge.symbol)
                        .font(.system(.caption2, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(badge.tint)
                        .padding(Space.xs)
                        .background(.thinMaterial, in: .rect(cornerRadius: Radius.xs, style: .continuous))
                        .accessibilityLabel(badge.label)
                }
            }
            .padding(Space.sm)
        }
    }

    /// Une pastille d'état sur la jaquette. Un type plutôt qu'un tuple : à trois
    /// membres, `.0` / `.1` / `.2` ne se lisent plus.
    private struct Badge: Identifiable {
        let symbol: String
        let tint: Color
        let label: String

        var id: String { label }

        init(_ symbol: String, _ tint: Color, _ label: String) {
            self.symbol = symbol
            self.tint = tint
            self.label = label
        }
    }

    /// Actions rapides au survol — Mac uniquement, jamais sur iOS.
    @ViewBuilder
    private var hoverActions: some View {
        #if os(macOS)
            if isHovering {
                HStack(spacing: Space.xs) {
                    quickAction(
                        Icon.favorite.name(isOn: model.isFavorite), "Favori", model.isFavorite, actions.toggleFavorite)
                    quickAction(
                        Icon.watchlist.name(isOn: model.isInWatchlist), "Watchlist", model.isInWatchlist,
                        actions.toggleWatchlist)
                    quickAction(Icon.watched.name(isOn: model.isWatched), "Vu", model.isWatched, actions.toggleWatched)
                    quickAction(Icon.crop, "Recadrer", false, actions.crop)
                }
                .padding(Space.xs)
                .background(.regularMaterial, in: .capsule)
                .padding(Space.sm)
                .transition(.opacity)
            }
        #endif
    }

    @ViewBuilder
    private func quickAction(
        _ symbol: String, _ label: String, _ isOn: Bool, _ action: (@MainActor () -> Void)?
    ) -> some View {
        if let action {
            Button {
                action()
            } label: {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(.caption))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isOn ? Color.accentText : .textPrimary)
            .dsSymbolReplace(value: isOn)
            .help(label)
            .accessibilityLabel(label)
        }
    }

    // MARK: Légende

    private var caption: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(model.title)
                .font(Typo.cardTitle)
                .foregroundStyle(.textPrimary)
                .lineLimit(metrics.titleLineLimit)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if metrics.showsMeta {
                HStack(spacing: Space.xs) {
                    if let meta = model.meta {
                        Text(meta)
                            .font(Typo.cardMeta)
                            .monospacedDigit()
                            .foregroundStyle(.textTertiary)
                            .lineLimit(1)
                    }
                    if let rating = model.rating {
                        Image(systemName: Icon.rating.name(fill: rating / 5))
                            .font(.system(.caption2))
                            .foregroundStyle(.textTertiary)
                            .accessibilityHidden(true)
                        Text(rating.formatted(.number.precision(.fractionLength(0...1))))
                            .font(Typo.cardMeta)
                            .monospacedDigit()
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: Menu contextuel

    @ViewBuilder
    private var contextMenuContent: some View {
        if let toggleFavorite = actions.toggleFavorite {
            Button(
                model.isFavorite ? "Retirer des favoris" : "Favori",
                systemImage: Icon.favorite.name(isOn: model.isFavorite)
            ) { toggleFavorite() }
        }
        if let toggleWatchlist = actions.toggleWatchlist {
            Button(
                model.isInWatchlist ? "Retirer de la watchlist" : "Watchlist",
                systemImage: Icon.watchlist.name(isOn: model.isInWatchlist)
            ) { toggleWatchlist() }
        }
        if let toggleWatched = actions.toggleWatched {
            Button(
                model.isWatched ? "Marquer comme non vu" : "Marquer comme vu",
                systemImage: Icon.watched.name(isOn: model.isWatched)
            ) { toggleWatched() }
        }
        Divider()
        if let edit = actions.edit { Button("Modifier", systemImage: "pencil") { edit() } }
        if let crop = actions.crop { Button("Recadrer", systemImage: Icon.crop) { crop() } }
        if let archive = actions.archive {
            Button(model.isArchived ? "Désarchiver" : "Archiver", systemImage: Icon.archived) { archive() }
        }
        if actions.delete != nil {
            Divider()
            // Destructif : jamais un bouton plein, toujours une confirmation.
            Button("Supprimer…", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
    }
}

/// `matchedTransitionSource` seulement si un namespace est fourni.
private struct TransitionSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

#Preview {
    ScrollView {
        HStack(alignment: .top, spacing: Space.lg) {
            ForEach(CardSize.allCases, id: \.self) { size in
                PosterCard(.sample, metrics: .portrait(size), actions: .init(toggleFavorite: {}, delete: {}))
            }
        }
        .padding()
    }
    .background(.bgCanvas)
}
