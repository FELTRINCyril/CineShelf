import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V5b · La fiche collection
//
// Planche 3 bloc `4f` : couverture, puis les titres du rayon. Son en-tête relève « Rayon ·
// réalisateur · Denis Villeneuve · 9 titres · 2009 — 2024 · 7 vus · ★ 4,4 en moyenne ».
//
// **Les statistiques du rayon se calculent à l'affichage.** Elles ne sont stockées nulle part,
// et c'est correct : ce sont des lectures du contenu, qui changent à chaque titre ajouté. Les
// dénormaliser exigerait de les recalculer à chaque écriture — et un champ de plus dans un
// schéma fermé.
//
// **La couverture est celle qu'on a choisie, sinon une mosaïque calculée.** `L6` — la
// génération d'un `MediaAsset` de mosaïque — est reportée en v1.1 ; le repli calculé par
// `CollectionTile` est le design retenu, pas un pis-aller, et il n'écrit aucun asset.

struct CollectionDetailView: View {
    let collectionID: UUID

    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext

    @Query private var collections: [TitleCollection]

    @State private var isRenaming = false
    @State private var draftName = ""

    init(collectionID: UUID) {
        self.collectionID = collectionID
        _collections = Query(filter: CollectionQuery.withID(collectionID))
    }

    private var collection: TitleCollection? { collections.first }

    var body: some View {
        ScreenScroll {
            if let collection {
                content(for: collection)
            } else {
                StateView(
                    .empty(
                        symbol: Icon.collections,
                        title: "Ce rayon n'existe plus.",
                        message: "Il a peut-être été supprimé depuis un autre appareil."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.bgCanvas)
        .preferredColorScheme(.dark)
        .navigationTitle(collection?.name ?? "Rayon")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Renommer le rayon", isPresented: $isRenaming) {
            TextField("Nom", text: $draftName)
            Button("Annuler", role: .cancel) {}
            Button("Renommer") { rename() }
        }
    }

    private func content(for collection: TitleCollection) -> some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            header(for: collection)
            titles(of: collection)
        }
        .padding(.top, TopNavigationBar.height + Space.s5)
        .padding(.bottom, Space.s7)
    }

    // MARK: L'en-tête

    private func header(for collection: TitleCollection) -> some View {
        HStack(alignment: .top, spacing: Space.s6) {
            CollectionTile(CollectionTileModel(collection), scale: .xl)
            details(for: collection)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
    }

    private func details(for collection: TitleCollection) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Rayon")
                .labelStyle()
                .foregroundStyle(Color.accent)

            Text(collection.name)
                .title1Style()
                .foregroundStyle(Color.textPrimary)

            let stats = statistics(of: collection)
            if !stats.isEmpty {
                Text(stats.joined(separator: " · "))
                    .metaStyle()
                    .foregroundStyle(Color.textSecondary)
            }

            if let summary = collection.summary, !summary.isEmpty {
                Text(summary)
                    .bodyStyle()
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.top, Space.s2)
            }

            HStack(spacing: Space.s3) {
                Button("Renommer") {
                    draftName = collection.name
                    isRenaming = true
                }
                .buttonStyle(ActionButtonStyle(rank: .primary))
            }
            .padding(.top, Space.s3)
        }
    }

    /// « 9 titres · 2009 — 2024 · 7 vus · ★ 4,4 en moyenne » — bloc `4f`.
    ///
    /// **Chaque chiffre omet ce qu'il ne peut pas couvrir**, comme les statistiques de `L18` :
    /// la moyenne ne compte que les titres notés, et l'intervalle d'années que ceux qui ont une
    /// date. Un titre sans note n'est pas un zéro, et un titre sans date n'est pas l'an zéro.
    private func statistics(of collection: TitleCollection) -> [String] {
        let titles = (collection.titles ?? []).filter { $0.deletedAt == nil }
        guard !titles.isEmpty else { return [] }

        var parts = [titles.count == 1 ? "1 titre" : "\(titles.count) titres"]

        let years = titles.compactMap(\.releaseDate).map {
            Calendar.current.component(.year, from: $0)
        }
        if let first = years.min(), let last = years.max() {
            parts.append(first == last ? "\(first)" : "\(first) — \(last)")
        }

        let watched = titles.count { title in
            guard let profileID = session.current?.id else { return false }
            return title.flags?.contains { $0.profile?.id == profileID && $0.isWatched } ?? false
        }
        if watched > 0 { parts.append("\(watched) vus") }

        let rated = titles.compactMap(\.rating)
        if !rated.isEmpty {
            let average = rated.reduce(0, +) / Double(rated.count)
            // Sur 5, comme partout où une étoile est dessinée — la note du catalogue est sur
            // 10, et `TitleFormat.fiveStarRating` divise déjà par deux.
            let stars = TitleFormat.fiveStarRating(average) ?? 0
            parts.append("★ \(stars.formatted(.number.precision(.fractionLength(0...1)))) en moyenne")
        }

        return parts
    }

    // MARK: Les titres du rayon

    @ViewBuilder
    private func titles(of collection: TitleCollection) -> some View {
        let hidesPrivate = appLock.scope(for: session.current).hidesPrivateContent
        let members = (collection.titles ?? [])
            .filter { $0.deletedAt == nil && !(hidesPrivate && $0.isPrivate) }
            .sorted { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }

        if members.isEmpty {
            EmptyState(
                title: "Ce rayon est vide",
                message: "Ajoute des titres à ce rayon depuis leur fiche ou l'éditeur.",
                primary: .init("Voir les titres") { navigation.section = .titles }
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Les titres du rayon")
                    .title2Style()
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, Breakpoint.macStandard.screenMargin)

                AdaptiveTileGrid(
                    members.map { PosterCardModel($0, flag: flag(for: $0)) },
                    cardWidth: PosterScale.l.width
                ) { card in
                    PosterTile(card, layout: .portrait, scale: .l) {
                        if let id = UUID(uuidString: card.id) {
                            navigation.open(
                                .title(id), within: members.map { AppRoute.title($0.id) })
                        }
                    }
                }
            }
        }
    }

    private func flag(for title: Title) -> TitleFlag? {
        guard let profileID = session.current?.id else { return nil }
        return title.flags?.first { $0.profile?.id == profileID }
    }

    private func rename() {
        guard let collection else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        CollectionRepository(context: modelContext).update(collection) { $0.name = trimmed }
    }
}
