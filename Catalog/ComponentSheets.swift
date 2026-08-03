import DesignSystem
import SwiftUI

// Planches des composants : chaque composant dans tous ses états.
// Reprises telles quelles de la livraison Claude Design.

struct StateViewSheet: View {
    var body: some View {
        Sheet("StateView", note: "Trois cas, un seul composant.") {
            VStack(spacing: Space.section) {
                StateView(.noTitles) {}.dsElevation(.surface)
                StateView(.loading) { CatalogGrid(items: Array(PosterCardModel.samples.prefix(4))) }
                StateView(.syncFailed) {}.dsElevation(.surface)
            }
        }
    }
}

struct FieldRowSheet: View {
    @State private var title = "Stalker"

    var body: some View {
        Sheet("FieldRow") {
            VStack(alignment: .leading, spacing: Space.md) {
                FieldRow("Titre") { TextField("Titre", text: $title) }
                FieldValueRow("Année", value: "1979")
                FieldValueRow("Durée", value: "2 h 41", validation: .info("Importée depuis le fichier."))
                FieldRow("Note", validation: .warning("Note hors barème (0–5).")) {
                    TextField("Note", text: .constant("6"))
                }
                FieldRow("Titre original", validation: .error("Ce champ ne peut pas être vide.")) {
                    TextField("Titre original", text: .constant(""))
                }
            }
            .padding(Space.panelPadding)
            .dsElevation(.surface)
        }
    }
}

struct FilterBarSheet: View {
    @State private var sort = SortOption.samples[0]
    @State private var ascending = false
    @State private var tokens = FilterToken.samples
    @State private var display = CardDisplaySetting.default

    var body: some View {
        Sheet("FilterBar · DisplayMenu") {
            VStack(alignment: .leading, spacing: Space.lg) {
                FilterBar(
                    sort: $sort, ascending: $ascending, tokens: $tokens,
                    groups: [.init(id: "genres", label: "Genres", options: FilterToken.samples)])
                DisplayMenu(setting: $display, context: .titles)
            }
        }
    }
}

struct ThumbnailSheet: View {
    var body: some View {
        Sheet("MediaThumbnail", note: "Placeholder → blurhash → image, sans saut de mise en page.") {
            HStack(alignment: .top, spacing: Space.lg) {
                labeled("Placeholder") { MediaThumbnail(url: nil).frame(width: 148) }
                labeled("Blurhash") {
                    MediaThumbnail(url: URL(string: "https://x/a.jpg"), blurHash: "L6PZfSjE.A").frame(width: 148)
                }
                labeled("Chargée") {
                    MediaThumbnail(url: URL(string: "https://x/b.jpg")).frame(width: 148)
                        .imageLoader(.stubbed())
                }
            }
        }
    }

    private func labeled<V: View>(_ text: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            content()
            Text(text).font(Typo.cardMeta).foregroundStyle(.textTertiary)
        }
    }
}

struct PosterCardSheet: View {
    @Namespace private var namespace

    var body: some View {
        Sheet(
            "PosterCard", note: "Trois tailles, deux dispositions, tous les badges. Survol et menu contextuel sur Mac."
        ) {
            VStack(alignment: .leading, spacing: Space.section) {
                ForEach(CardLayout.allCases) { layout in
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text(layout.rawValue).railLabelStyle()
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: Space.lg) {
                                ForEach(CardSize.allCases) { size in
                                    PosterCard(
                                        .sample, metrics: .metrics(layout, size),
                                        actions: fullActions, in: namespace)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("États").railLabelStyle()
                    HStack(alignment: .top, spacing: Space.lg) {
                        ForEach(PosterCardModel.samples.prefix(5)) { model in
                            PosterCard(model, metrics: .portrait(.medium), actions: fullActions, in: namespace)
                        }
                    }
                }
            }
        }
    }

    private var fullActions: PosterCardActions {
        .init(
            toggleFavorite: {}, toggleWatchlist: {}, toggleWatched: {},
            edit: {}, crop: {}, archive: {}, delete: {})
    }
}

struct ShelfRailSheet: View {
    var body: some View {
        Sheet(
            "ShelfRail",
            note: "Libellé, filet, compteur monospace, progression en Ember, flèches au survol sur Mac."
        ) {
            VStack(alignment: .leading, spacing: Space.section) {
                ForEach(ShelfRailModel.samples) { rail in
                    ShelfRail(rail)
                }
            }
        }
    }
}

struct CatalogGridSheet: View {
    @Binding var display: CardDisplaySetting

    var body: some View {
        Sheet("CatalogGrid", note: "Bascule automatique en liste au-delà de .accessibility1.") {
            VStack(alignment: .leading, spacing: Space.lg) {
                DisplayMenu(setting: $display, context: .titles)
                CatalogGrid(items: PosterCardModel.samples, setting: display)
            }
        }
    }
}
