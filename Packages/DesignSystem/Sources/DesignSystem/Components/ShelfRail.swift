import SwiftUI

// MARK: - ShelfRail — l'élément signature
//
//   ACTION · 24 titres ──────────────────────  01–08 / 24  ‹ ›
//   ┌────┐ ┌────┐ ┌────┐ …
//   ───────────────────────────────────────────────────────────
//
// Le compteur encode où on en est dans la collection : une information réelle.
// Le segment Ember sous le filet est le seul aplat d'accent qui ne soit pas une action.

public struct ShelfRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let model: ShelfRailModel
    private let metrics: CardMetrics
    private let actions: (PosterCardModel) -> PosterCardActions
    private let namespace: Namespace.ID?
    private let onOpen: ((PosterCardModel) -> Void)?

    @State private var visibleRange: ClosedRange<Int> = 0...0
    @State private var scrolledID: String?
    @State private var isHovering = false

    public init(
        _ model: ShelfRailModel,
        metrics: CardMetrics = .portrait(.medium),
        in namespace: Namespace.ID? = nil,
        actions: @escaping (PosterCardModel) -> PosterCardActions = { _ in .init() },
        onOpen: ((PosterCardModel) -> Void)? = nil
    ) {
        self.model = model
        self.metrics = metrics
        self.namespace = namespace
        self.actions = actions
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            shelf
            baseline
        }
        #if os(macOS)
            .onHover { isHovering = $0 }
        #endif
        .dsAnimation(Motion.base, value: visibleRange)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityLabel)
    }

    // MARK: Libellé · filet · compteur

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Text(model.label)
                    .railLabelStyle()
                    .foregroundStyle(.textPrimary)
                Text("· \(model.totalCount) titres")
                    .font(Typo.railCounter)
                    .foregroundStyle(.textTertiary)
            }
            .fixedSize()
            .accessibilityHidden(true)

            Rectangle()
                .fill(.borderDefault)
                .frame(height: 1)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }

            Text(model.counter(visible: visibleRange))
                .font(Typo.railCounter)
                .foregroundStyle(.textTertiary)
                .fixedSize()
                .contentTransition(.numericText())
                .accessibilityHidden(true)

            #if os(macOS)
                // Les flèches n'apparaissent qu'au survol.
                HStack(spacing: Space.xxs) {
                    arrow("chevron.left", "Élément précédent", step: -1)
                    arrow("chevron.right", "Élément suivant", step: 1)
                }
                .opacity(isHovering ? 1 : 0)
                .animation(reduceMotion ? nil : Motion.quick, value: isHovering)
            #endif
        }
    }

    @ViewBuilder
    private func arrow(_ symbol: String, _ label: String, step: Int) -> some View {
        Button {
            scroll(by: step)
        } label: {
            Image(systemName: symbol)
                .font(.system(.caption2, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.textSecondary)
        .background(.bgSurface, in: .circle)
        .dsBorder(.borderSubtle, radius: 11)
        .accessibilityLabel(label)
    }

    // MARK: Rangée

    private var shelf: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: metrics.spacing) {
                ForEach(model.items) { item in
                    PosterCard(item, metrics: metrics, actions: actions(item), in: namespace) {
                        onOpen?(item)
                    }
                    .id(item.id)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, Space.xxs)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledID, anchor: .leading)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: ClosedRange<Int>.self) { geometry in
            let step = metrics.width + metrics.spacing
            guard step > 0 else { return 0...0 }
            let first = max(0, Int((geometry.contentOffset.x / step).rounded(.down)))
            let count = max(1, Int((geometry.containerSize.width / step).rounded(.down)))
            let last = min(model.items.count - 1, first + count - 1)
            return first...max(first, last)
        } action: { _, new in
            visibleRange = new
        }
    }

    // MARK: Filet bas + progression

    private var baseline: some View {
        GeometryReader { proxy in
            let progress = model.progress(visible: visibleRange)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(.borderSubtle)
                Capsule()
                    .fill(.accentSolid)
                    .frame(width: max(24, width * (progress.upperBound - progress.lowerBound)))
                    .offset(x: width * progress.lowerBound)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    private func scroll(by step: Int) {
        guard !model.items.isEmpty else { return }
        let current = scrolledID.flatMap { id in model.items.firstIndex { $0.id == id } } ?? visibleRange.lowerBound
        let target = min(max(0, current + step), model.items.count - 1)
        withAnimation(reduceMotion ? nil : Motion.base) {
            scrolledID = model.items[target].id
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.section) {
            ForEach(ShelfRailModel.samples) { rail in
                ShelfRail(rail)
            }
        }
        .padding(Space.xl)
    }
    .background(.bgCanvas)
}
