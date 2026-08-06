import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V5a · L'accueil
//
// Relevé sur la planche 1 bloc `2a` (l'écran de la direction retenue) et la planche 2 bloc
// `3a`, qui en donne l'état défilé avec ses trois rails.
//
// **Le hero est l'élément le plus visible de toute la direction.** Image bord à bord sur
// 100 % de la hauteur, **trois** voiles superposés — dégradé vers le haut, dégradé vers la
// droite, trame horizontale à 1,4 % —, barre de navigation transparente par-dessus, et le
// premier rail qui n'affleure qu'en bas de cadre.
//
// Les rails du bloc `3a` défilé : « Ajoutés cette semaine », un par **genre épinglé**
// (« Mes genres · Drame »), puis « Ma liste · à voir ». C'est la réponse aux genres
// épinglés que `V0` avait laissés sans point d'accès : ils ne sont pas une entrée de
// navigation, ils sont la **configuration de l'accueil**.

struct HomeView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(NavigationModel.self) private var navigation

    @Query(sort: \Title.createdAt, order: .reverse) private var titles: [Title]
    @Query(filter: GenreQuery.pinned, sort: \Genre.pinIndex) private var pinnedGenres: [Genre]
    // Les collections manuelles : `L18` leur donne un rayon, avant ceux des genres.
    @Query(sort: \TitleCollection.sortName) private var collections: [TitleCollection]

    var body: some View {
        // `day: .now` et non un minuit calculé ici : `HomeSelection` ramène lui-même
        // l'instant à son jour local, et le faire deux fois donnerait deux définitions du
        // « jour » — celle de la vue et celle du service — qui divergeraient au premier
        // changement d'avis. Voir `HomeSelection.dayIndex(_:modulo:)`.
        let selection = HomeSelection(
            titles: titles,
            pinnedGenres: pinnedGenres,
            collections: collections,
            profileID: session.current?.id,
            hidingPrivate: appLock.scope(for: session.current).hidesPrivateContent,
            libraryID: session.current?.library?.id,
            day: .now
        )
        let byID = Dictionary(titles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        VStack(alignment: .leading, spacing: Space.s6) {
            if let heroID = selection.heroID, let hero = byID[heroID] {
                heroBand(for: hero)
            }
            ForEach(selection.rails) { rail in
                let railTitles = rail.titleIDs.compactMap { byID[$0] }
                TileRail(LocalizedStringKey(rail.label)) {
                    ForEach(railTitles, id: \.persistentModelID) { title in
                        PosterTile(card(for: title), scale: .xl) {
                            navigation.section = .titles
                            navigation.open(
                                .title(title.id),
                                within: railTitles.map { AppRoute.title($0.id) })
                        }
                    }
                }
            }
        }
        .padding(.bottom, Space.s7)
    }

    // MARK: Le hero

    private func heroBand(for title: Title) -> some View {
        ZStack(alignment: .bottomLeading) {
            MediaFill(
                imageURL: AssetURL.backdrop(for: title) ?? AssetURL.poster(for: title),
                blurHash: (TitleFormat.backdropAsset(of: title)
                    ?? TitleFormat.primaryAsset(of: title))?.blurHash,
                crop: CropDisplay.of(
                    TitleFormat.backdropAsset(of: title) ?? TitleFormat.primaryAsset(of: title),
                    in: TitleFormat.backdropAsset(of: title) == nil ? .card : .hero),
                targetAspect: CardLayout.landscape.aspectRatio,
                background: Color.bgSurface
            )
            .blur(radius: 22)
            .scaleEffect(1.25)
            .overlay { veils }
            .clipped()

            heroText(for: title)
                .padding(.horizontal, Breakpoint.macStandard.screenMargin)
                .padding(.bottom, Space.s8)
        }
        // 100 % de la hauteur **moins** de quoi laisser le premier rail affleurer : le
        // prototype pose le rail à 806 sur 900, et c'est le seul signal qu'il y a autre
        // chose sous le hero.
        .containerRelativeFrame(.vertical) { height, _ in max(360, height - 150) }
        .clipped()
    }

    /// Les trois voiles du prototype. Ce sont des dégradés **posés sur une image**, donc
    /// explicitement autorisés (§4.1) — la règle « zéro translucidité » ne vaut que pour
    /// les surfaces opaques. La trame est la troisième, et c'est celle qu'on oublie.
    private var veils: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.bgCanvas, Color.bgCanvas.opacity(0.92),
                    Color.bgCanvas.opacity(0.35), Color.bgCanvas.opacity(0.1)
                ],
                startPoint: .bottom, endPoint: .top)
            LinearGradient(
                colors: [Color.bgCanvas.opacity(0.88), Color.bgCanvas.opacity(0.4), .clear],
                startPoint: .leading, endPoint: .trailing)
            scanlines
        }
    }

    /// `repeating-linear-gradient(0deg, oklch(1 0 0 / 0.014) 0 1px, transparent 1px 3px)` —
    /// une ligne claire tous les 3 pt, à 1,4 % d'opacité. Invisible isolément, et c'est ce
    /// qui donne au hero son grain de projection.
    private var scanlines: some View {
        GeometryReader { proxy in
            let count = Int(proxy.size.height / 3)
            VStack(spacing: 2) {
                ForEach(0..<max(0, count), id: \.self) { _ in
                    Color.textPrimary.opacity(0.014).frame(height: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func heroText(for title: Title) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if let collection = title.collection?.name {
                Text("Collection · \(collection)")
                    .labelStyle()
                    .foregroundStyle(Color.accent)
            }

            Text(title.name)
                .displayStyle()
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: Space.s3) {
                if let meta = TitleFormat.meta(for: title) {
                    Text(meta).labelStyle().foregroundStyle(Color.textSecondary)
                }
                if let rating = title.rating {
                    RatingBar(TitleFormat.fiveStarRating(rating), scale: .compact)
                    Text(TitleFormat.ratingText(rating) ?? "")
                        .font(Typo.numeric)
                        .foregroundStyle(Color.accent)
                }
            }

            if let summary = title.summary, !summary.isEmpty {
                Text(summary)
                    .bodyStyle()
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: 640, alignment: .leading)
            }

            Button {
                navigation.section = .titles
                navigation.open(.title(title.id))
            } label: {
                Text("Ouvrir la fiche")
                    .actionStyle()
                    .foregroundStyle(Color.accentOnAccent)
                    .padding(.horizontal, Space.s5)
                    .frame(minHeight: Space.minHitTarget)
                    .background(Color.textPrimary)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, Space.s1)
        }
    }

    private func card(for title: Title) -> PosterCardModel {
        PosterCardModel(title, flag: flag(for: title))
    }

    private func flag(for title: Title) -> TitleFlag? {
        guard let profileID = session.current?.id else { return nil }
        return title.flags?.first { $0.profile?.id == profileID }
    }
}
