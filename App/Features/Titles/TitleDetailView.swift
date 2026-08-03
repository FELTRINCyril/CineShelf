import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// La fiche d'un titre — `docs/03` §4.
///
/// Hero 16/9 quand le titre en a un, jaquette 2/3 sinon, puis métadonnées,
/// casting, galerie et liens. Les trois bascules du profil courant écrivent
/// dans `TitleFlag` via `FlagRepository`, jamais directement.
struct TitleDetailView: View {
    let titleID: UUID

    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query private var titles: [Title]

    @State private var isEditorPresented = false

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        /// iPad est « regular » sans être macOS : tester la plateforme le privait
        /// de l'inspecteur que `RegularRootView` monte pourtant pour lui.
        private var usesInspector: Bool { horizontalSizeClass == .regular }
    #else
        private var usesInspector: Bool { true }
    #endif

    init(titleID: UUID) {
        self.titleID = titleID
        _titles = Query(filter: TitleQuery.withID(titleID))
    }

    /// La grille filtre déjà le contenu privé, mais on peut atteindre une fiche
    /// par restauration d'état ou par ⌥↑ : un profil « Invité » ne doit jamais
    /// la voir — `docs/03` §1 bis.
    private var title: Title? {
        guard let found = titles.first else { return nil }
        if found.isPrivate, session.current?.hidesPrivateContent == true { return nil }
        return found
    }

    var body: some View {
        Group {
            if let title {
                content(for: title)
            } else {
                StateView(
                    .empty(
                        symbol: Icon.titles,
                        title: "Ce titre n'existe plus.",
                        message: "Il a peut-être été supprimé depuis un autre appareil."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
        .navigationTitle(title?.name ?? "Titre")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            // Balayage horizontal : l'équivalent tactile de ⌥↑ / ⌥↓.
            // `simultaneousGesture` pour ne pas voler le défilement vertical du
            // ScrollView, et seuil élevé pour laisser passer le retour
            // interactif de NavigationStack au bord de l'écran.
            .simultaneousGesture(swipeBetweenTitles)
        #endif
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditorPresented) {
            if let title { TitleEditor(title: title) }
        }
    }

    // MARK: Contenu

    @ViewBuilder
    private func content(for title: Title) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header(for: title)
                metadata(for: title)

                if !TitleFormat.cast(of: title).isEmpty {
                    castSection(for: title)
                }
                if !gallery(of: title).isEmpty {
                    gallerySection(for: title)
                }
                if let links = title.links, !links.isEmpty {
                    linksSection(links)
                }
            }
            .padding(Space.panelPadding)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func header(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            if let backdrop = AssetURL.backdrop(for: title) {
                MediaThumbnail(
                    url: backdrop,
                    blurHash: TitleFormat.backdropAsset(of: title)?.blurHash,
                    aspect: Ratio.backdrop,
                    label: title.name
                )
            }

            HStack(alignment: .top, spacing: Space.lg) {
                MediaThumbnail(
                    url: AssetURL.poster(for: title),
                    blurHash: TitleFormat.primaryAsset(of: title)?.blurHash,
                    aspect: Ratio.poster,
                    label: title.name
                )
                .frame(width: 148)

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(title.name)
                        .font(Typo.pageTitle)
                        .foregroundStyle(.textPrimary)

                    if let original = title.originalName, original != title.name {
                        Text(original)
                            .font(Typo.body)
                            .foregroundStyle(.textSecondary)
                    }

                    if let meta = TitleFormat.meta(for: title) {
                        Text(meta)
                            .font(Typo.cardMeta)
                            .foregroundStyle(.textTertiary)
                    }

                    if let rating = TitleFormat.ratingText(title.rating) {
                        Text(rating)
                            .font(Typo.dataValue)
                            .foregroundStyle(.textPrimary)
                    }

                    flagButtons(for: title)
                }
            }

            if let summary = title.summary, !summary.isEmpty {
                Text(summary)
                    .font(Typo.body)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func flagButtons(for title: Title) -> some View {
        let flag = currentFlag(for: title)

        return HStack(spacing: Space.sm) {
            flagButton("Favori", Icon.favorite, isOn: flag?.isFavorite ?? false) {
                flags?.toggleFavorite(title)
            }
            flagButton("Ma liste", Icon.watchlist, isOn: flag?.isInWatchlist ?? false) {
                flags?.toggleWatchlist(title)
            }
            flagButton("Vu", Icon.watched, isOn: flag?.isWatched ?? false) {
                flags?.toggleWatched(title)
            }
        }
        .padding(.top, Space.xs)
    }

    private func flagButton(
        _ label: String, _ pair: SymbolPair, isOn: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: pair.name(isOn: isOn))
                .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentSolid : .textSecondary)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func metadata(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Informations").railLabelStyle()

            if let year = title.releaseYear {
                FieldValueRow("Sortie", value: String(year))
            }
            if let runtime = TitleFormat.runtime(title.runtimeMinutes) {
                FieldValueRow("Durée", value: runtime)
            }
            FieldValueRow("Type", value: kindLabel(title.kind))

            let genres = TitleFormat.genreNames(of: title)
            if !genres.isEmpty {
                FieldValueRow("Genres", value: genres.joined(separator: ", "))
            }
            if let collection = title.collection {
                FieldValueRow("Collection", value: collection.name)
            }
        }
        .padding(Space.panelPadding)
        .dsElevation(.surface)
    }

    private func castSection(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Distribution").railLabelStyle()

            ForEach(TitleFormat.cast(of: title)) { credit in
                Button {
                    guard let personID = credit.person?.id else { return }
                    navigation.open(.person(personID))
                } label: {
                    HStack(spacing: Space.sm) {
                        Text(credit.person?.displayName ?? "Inconnu")
                            .font(Typo.body)
                            .foregroundStyle(.textPrimary)
                        if let character = credit.characterName, !character.isEmpty {
                            Text(character)
                                .font(Typo.cardMeta)
                                .foregroundStyle(.textTertiary)
                        }
                        Spacer(minLength: 0)
                        Text(roleLabel(credit.role))
                            .font(Typo.cardMeta)
                            .foregroundStyle(.textTertiary)
                    }
                    .frame(minHeight: Space.minHitTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Space.panelPadding)
        .dsElevation(.surface)
    }

    private func gallerySection(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Galerie").railLabelStyle()

            ScrollView(.horizontal) {
                HStack(spacing: Space.md) {
                    ForEach(gallery(of: title), id: \.id) { attachment in
                        if let asset = attachment.asset {
                            MediaThumbnail(
                                url: AssetURL.url(for: asset.id, preset: .card),
                                blurHash: asset.blurHash,
                                aspect: Ratio.poster
                            )
                            .frame(width: 104)
                        }
                    }
                }
            }
        }
    }

    private func linksSection(_ links: [ResourceLink]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Liens").railLabelStyle()

            ForEach(links) { link in
                if let url = URL(string: link.urlString) {
                    Link(destination: url) {
                        Label(linkLabel(link, url: url), systemImage: "link")
                            .frame(minHeight: Space.minHitTarget)
                    }
                }
            }
        }
        .padding(Space.panelPadding)
        .dsElevation(.surface)
    }

    /// `label` est optionnel côté modèle : à défaut, l'hôte parle assez.
    private func linkLabel(_ link: ResourceLink, url: URL) -> String {
        if let label = link.label, !label.isEmpty { return label }
        return url.host() ?? link.urlString
    }

    // MARK: Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                if usesInspector {
                    navigation.isInspectorPresented.toggle()
                } else {
                    isEditorPresented = true
                }
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
        }
    }

    // MARK: Aides

    private func gallery(of title: Title) -> [MediaAttachment] {
        (title.attachments ?? [])
            .filter { $0.slot == .gallery }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private func currentFlag(for title: Title) -> TitleFlag? {
        guard let profileID = session.current?.id else { return nil }
        return title.flags?.first { $0.profile?.id == profileID }
    }

    private var flags: FlagRepository? {
        session.current.map { FlagRepository(context: modelContext, profile: $0) }
    }

    private func kindLabel(_ kind: TitleKind) -> String {
        switch kind {
        case .movie: "Film"
        case .series: "Série"
        case .documentary: "Documentaire"
        case .short: "Court métrage"
        case .other: "Autre"
        }
    }

    private func roleLabel(_ role: CreditRole) -> String {
        switch role {
        case .cast: "Interprète"
        case .director: "Réalisation"
        case .writer: "Scénario"
        case .producer: "Production"
        case .composer: "Musique"
        case .crew: "Équipe"
        }
    }

    #if os(iOS)
        /// Balayage horizontal pour passer au titre voisin, comme ⌥↑ / ⌥↓ sur Mac.
        private var swipeBetweenTitles: some Gesture {
            DragGesture(minimumDistance: 80)
                .onEnded { value in
                    // Deux fois plus horizontal que vertical, et pas amorcé au
                    // bord gauche où le système attend un retour.
                    guard abs(value.translation.width) > abs(value.translation.height) * 2,
                        value.startLocation.x > 40
                    else { return }
                    if value.translation.width < 0 {
                        navigation.goToNext()
                    } else {
                        navigation.goToPrevious()
                    }
                }
        }
    #endif
}
