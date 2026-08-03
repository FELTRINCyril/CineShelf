import SwiftUI

// MARK: - CatalogGrid
//
// `LazyVGrid` piloté par `CardMetrics` — la virtualisation est native.
// Au-delà de `.accessibility1`, bascule automatique en liste : c'est le vrai
// test « userfriendly », pas une grille illisible à AX5.

public struct CatalogGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let items: [PosterCardModel]
    private let setting: CardDisplaySetting
    private let namespace: Namespace.ID?
    private let actions: (PosterCardModel) -> PosterCardActions
    private let onOpen: ((PosterCardModel) -> Void)?

    public init(
        items: [PosterCardModel],
        setting: CardDisplaySetting = .default,
        in namespace: Namespace.ID? = nil,
        actions: @escaping (PosterCardModel) -> PosterCardActions = { _ in .init() },
        onOpen: ((PosterCardModel) -> Void)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.namespace = namespace
        self.actions = actions
        self.onOpen = onOpen
    }

    private var metrics: CardMetrics { setting.metrics }
    private var usesList: Bool { dynamicTypeSize.isAccessibilitySize }

    public var body: some View {
        Group {
            if usesList {
                list
            } else {
                grid
            }
        }
        .dsAnimation(Motion.base, value: usesList)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Catalogue, \(items.count) éléments")
    }

    private var grid: some View {
        LazyVGrid(columns: metrics.gridColumns, alignment: .leading, spacing: metrics.spacing) {
            ForEach(items) { item in
                PosterCard(item, metrics: metrics, actions: actions(item), in: namespace) { onOpen?(item) }
            }
        }
    }

    private var list: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                CatalogRow(model: item, namespace: namespace, actions: actions(item)) { onOpen?(item) }
                if item.id != items.last?.id {
                    Divider().overlay(Color.borderSubtle)
                }
            }
        }
    }
}

/// Ligne de repli aux tailles d'accessibilité : vignette bornée, texte libre de grandir.
struct CatalogRow: View {
    let model: PosterCardModel
    let namespace: Namespace.ID?
    let actions: PosterCardActions
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: Space.md) {
                MediaThumbnail(
                    url: model.imageURL, blurHash: model.blurHash,
                    aspect: Ratio.poster, radius: Radius.md, label: model.title
                )
                .frame(width: 56)

                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(model.title)
                        .font(Typo.cardTitle)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let meta = model.meta {
                        Text(meta)
                            .font(Typo.cardMeta)
                            .monospacedDigit()
                            .foregroundStyle(.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Space.sm)

                if model.isFavorite {
                    Image(systemName: Icon.favorite.on)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.accentText)
                        .accessibilityLabel("Favori")
                }
            }
            .padding(.vertical, Space.md)
            .frame(minHeight: Space.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.accessibilityDescription)
    }
}

#Preview("Grille") {
    ScrollView {
        CatalogGrid(items: PosterCardModel.samples).padding(Space.xl)
    }
    .background(.bgCanvas)
}

#Preview("AX5 — bascule en liste") {
    ScrollView {
        CatalogGrid(items: PosterCardModel.samples).padding(Space.xl)
    }
    .background(.bgCanvas)
    .environment(\.dynamicTypeSize, .accessibility5)
}
