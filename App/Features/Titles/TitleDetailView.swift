import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V0 bis · La fiche titre
//
// Relevée sur la planche 3 bloc `4b` : bande de hero de 520 pt, affiche de 210 pt posée
// dessus à gauche, colonne d'informations à côté, puis casting, galerie et liens.
//
// **Le hero est l'affiche floutée quand il n'y a pas d'image large, et c'est le design qui
// le dit.** Le prototype pose la *même source* aux deux endroits — `heroB.u` en fond flouté
// et en affiche nette — et le §11 le confirme : « Images larges de hero : aucune n'existe.
// Les prototypes utilisent l'affiche agrandie et floutée. » Le §3 ajoute que l'app doit
// consommer un vrai emplacement paysage. Les deux se concilient en une règle : `backdrop`
// s'il existe, repli sur la jaquette sinon. Ça referme l'écart connu « sans média backdrop,
// la fiche n'affiche aucun hero ».
//
// **Le recadrage par contexte est exercé ici pour de vrai** — `CropContext.hero` sur le
// backdrop, `.detail` sur l'affiche. Sur les données de `DemoCatalog`, qui n'ont aucun
// backdrop, c'est le repli qui rend : l'affiche 2:3 remplit une bande 16:9, donc perd son
// haut et son bas — invisible sous un flou de 22 pt et un agrandissement de 1,28.

struct TitleDetailView: View {
    let titleID: UUID

    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query private var titles: [Title]

    @State private var isEditorPresented = false

    init(titleID: UUID) {
        self.titleID = titleID
        _titles = Query(filter: TitleQuery.withID(titleID))
    }

    /// La grille filtre déjà le contenu privé, mais on peut atteindre une fiche par
    /// restauration d'état ou par ⌥↑ : un profil « Invité » ne doit jamais la voir.
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.bgCanvas)
        .navigationTitle(title?.name ?? "Titre")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .simultaneousGesture(swipeBetweenTitles)
        #endif
        .sheet(isPresented: $isEditorPresented) {
            if let title { TitleEditor(title: title) }
        }
    }

    @ViewBuilder
    private func content(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            hero(for: title)
            cast(of: title)
            HStack(alignment: .top, spacing: Space.s6) {
                gallery(of: title)
                links(of: title)
            }
            .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        }
    }

    // MARK: Le hero

    private func hero(for title: Title) -> some View {
        let backdrop = TitleFormat.backdropAsset(of: title)
        let poster = TitleFormat.primaryAsset(of: title)

        return ZStack(alignment: .bottomLeading) {
            MediaFill(
                imageURL: AssetURL.backdrop(for: title) ?? AssetURL.poster(for: title),
                crop: CropDisplay.of(backdrop ?? poster, in: backdrop == nil ? .card : .hero),
                targetAspect: CardLayout.landscape.aspectRatio,
                background: Color.bgSurface
            )
            .blur(radius: 22)
            .scaleEffect(1.28)
            .overlay { veils }
            .clipped()

            heroContent(for: title)
                .padding(.horizontal, Breakpoint.macStandard.screenMargin)
                .padding(.bottom, Space.s6)
        }
        .frame(height: 520)
        .clipped()
    }

    /// Les deux voiles du prototype : un vers le bas et un vers la droite. Ce sont des
    /// dégradés **posés sur une image**, donc explicitement autorisés (§4.1) — la règle
    /// « zéro translucidité » ne vaut que pour les surfaces opaques.
    private var veils: some View {
        ZStack {
            LinearGradient(
                colors: [Color.bgCanvas, Color.bgCanvas.opacity(0.78), Color.bgCanvas.opacity(0.22)],
                startPoint: .bottom, endPoint: .top)
            LinearGradient(
                colors: [Color.bgCanvas.opacity(0.86), Color.bgCanvas.opacity(0.34), .clear],
                startPoint: .leading, endPoint: .trailing)
        }
    }

    @ViewBuilder
    private func heroContent(for title: Title) -> some View {
        HStack(alignment: .bottom, spacing: Space.s6) {
            PosterTile(PosterCardModel(title, flag: currentFlag(for: title)), scale: .xl)

            VStack(alignment: .leading, spacing: Space.s3) {
                Text(surtitle(for: title))
                    .labelStyle()
                    .foregroundStyle(Color.accent)

                Text(title.name)
                    .displayStyle()
                    .foregroundStyle(Color.textPrimary)

                metadata(for: title)

                if let summary = title.summary, !summary.isEmpty {
                    Text(summary)
                        .bodyStyle()
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: 600, alignment: .leading)
                }

                actions(for: title)
            }
        }
    }

    /// La ligne de métadonnées : année, durée, genres, note.
    ///
    /// **La note y porte sa valeur numérique**, contrairement au prototype qui n'y met que
    /// cinq étoiles. C'est la lacune inscrite à `I6` : 8,4 et 8,0 donnent quatre étoiles et
    /// deviennent indistinguables. Le nombre est la forme que le design utilise lui-même
    /// ailleurs (« ★ 4,5 », bloc `4a`), donc rien n'est inventé — seulement remis là où son
    /// absence coûtait une décimale.
    @ViewBuilder
    private func metadata(for title: Title) -> some View {
        HStack(spacing: Space.s3) {
            ForEach(metadataParts(of: title), id: \.self) { part in
                Text(part)
                    .labelStyle()
                    .foregroundStyle(Color.textSecondary)
            }
            if let rating = title.rating {
                HStack(spacing: Space.s2) {
                    RatingBar(TitleFormat.fiveStarRating(rating), scale: .compact)
                    Text(TitleFormat.ratingText(rating) ?? "")
                        .font(Typo.numeric)
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    private func metadataParts(of title: Title) -> [String] {
        var parts: [String] = []
        if let year = title.releaseYear { parts.append(String(year)) }
        if let runtime = TitleFormat.runtime(title.runtimeMinutes) { parts.append(runtime) }
        let genres = TitleFormat.genreNames(of: title)
        if !genres.isEmpty { parts.append(genres.joined(separator: " · ")) }
        return parts
    }

    private func surtitle(for title: Title) -> String {
        var parts = [kindLabel(title.kind)]
        if let collection = title.collection?.name { parts.append(collection) }
        return parts.joined(separator: " · ")
    }

    /// Les quatre actions du prototype. La première est pleine et blanche, les trois autres
    /// en `fill.onImage` — le seul remplissage autorisé sur une image.
    @ViewBuilder
    private func actions(for title: Title) -> some View {
        let flag = currentFlag(for: title)

        HStack(spacing: Space.s2) {
            heroButton(
                flag?.isWatched == true ? "Marquer non vu" : "Marquer vu",
                isPrimary: true
            ) { flags?.toggleWatched(title) }

            heroButton(flag?.isInWatchlist == true ? "Retirer de ma liste" : "Ma liste") {
                flags?.toggleWatchlist(title)
            }

            heroButton(flag?.isFavorite == true ? "Retirer des favoris" : "Favori") {
                flags?.toggleFavorite(title)
            }

            heroButton("Modifier") { isEditorPresented = true }
        }
        .padding(.top, Space.s1)
    }

    private func heroButton(
        _ label: String, isPrimary: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .actionStyle()
                .foregroundStyle(isPrimary ? Color.accentOnAccent : Color.textPrimary)
                .padding(.horizontal, Space.s5)
                .frame(minHeight: Space.minHitTarget)
                .background(isPrimary ? Color.textPrimary : Color.fillOnImage)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Casting, galerie, liens

    @ViewBuilder
    private func cast(of title: Title) -> some View {
        let credits = TitleFormat.cast(of: title)
        if !credits.isEmpty {
            TileRail("Casting") {
                ForEach(credits, id: \.persistentModelID) { credit in
                    castTile(for: credit)
                }
            }
        }
    }

    @ViewBuilder
    private func castTile(for credit: Credit) -> some View {
        if let person = credit.person {
            PersonTile(
                PosterCardModel(
                    id: person.id.uuidString,
                    title: person.displayName,
                    kind: .person,
                    meta: roleLabel(credit.role)
                ),
                scale: .m
            ) {
                navigation.open(.person(person.id))
            }
        }
    }

    @ViewBuilder
    private func gallery(of title: Title) -> some View {
        let images = galleryAttachments(of: title)
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Galerie · \(images.count) images")
                    .labelStyle()
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: Space.s3) {
                    ForEach(Array(images.prefix(5)), id: \.persistentModelID) { attachment in
                        PosterTile(
                            PosterCardModel(
                                id: attachment.id.uuidString,
                                title: title.name,
                                imageURL: attachment.asset.map { AssetURL.url(for: $0.id, preset: .card) },
                                crop: CropDisplay.of(attachment.asset, in: .card)
                            ),
                            layout: .landscape,
                            scale: .l
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func links(of title: Title) -> some View {
        if let resources = title.links, !resources.isEmpty {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Liens")
                    .labelStyle()
                    .foregroundStyle(Color.textPrimary)
                ForEach(resources, id: \.persistentModelID) { link in
                    if let url = URL(string: link.urlString) {
                        Link(destination: url) {
                            Text(link.label ?? link.urlString)
                                .calloutStyle()
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                                .frame(minHeight: Space.minHitTarget, alignment: .leading)
                        }
                    }
                }
            }
            .frame(width: 300, alignment: .leading)
        }
    }

    // MARK: Aides

    private func galleryAttachments(of title: Title) -> [MediaAttachment] {
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
                    // Deux fois plus horizontal que vertical, et pas amorcé au bord gauche
                    // où le système attend un retour.
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
