import CineShelfCore
import DesignSystem
import MediaKit
import SwiftData
import SwiftUI

// MARK: - V3 · La requête, la maçonnerie, et le premier appelant du préchargement
//
// **C'est ici que `L5` trouve son foyer**, quatre sessions après avoir été livrée. La chaîne
// complète : `MasonryGrid` signale l'index qui entre à l'écran → `PrefetchScheduler` en déduit
// une frontière et un ordre → `MediaEnvironment.prefetch` le passe au cache. Aucun maillon
// n'est neuf ; ce qui manquait était le premier.

struct GalleryMasonry: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(MediaEnvironment.self) private var media
    @Environment(\.modelContext) private var modelContext

    @Query private var assets: [MediaAsset]

    private let filter: GalleryFilter
    private let isSelecting: Bool
    @Binding private var selection: Set<UUID>

    /// Les identifiants retenus par le filtre de source, ou `nil` quand il n'y a rien à
    /// restreindre.
    ///
    /// **`nil` n'est pas « pas encore calculé », c'est « aucune restriction »**, et la
    /// distinction évite un défaut de premier affichage : un état « en attente » ferait
    /// clignoter l'écran vide à chaque changement de filtre. Le filtre inactif — le cas par
    /// défaut — ne déclenche donc **aucun** `fetch`, ce qui est aussi ce qui tient l'écart de
    /// `L1 bis` à distance : la différence d'ensembles des orphelins charge tous les
    /// identifiants de médias, et elle ne se paie que quand on la demande.
    @State private var restriction: Set<UUID>?
    @State private var scheduler = PrefetchScheduler()
    @State private var viewerIndex: Int?
    @State private var croppedAsset: MediaAsset?

    init(
        filter: GalleryFilter,
        hidingPrivate: Bool,
        isSelecting: Bool,
        selection: Binding<Set<UUID>>
    ) {
        self.filter = filter
        self.isSelecting = isSelecting
        _selection = selection
        _assets = Query(
            filter: MediaQuery.galleryAssets(hidingPrivate: hidingPrivate),
            sort: [SortDescriptor(\MediaAsset.createdAt, order: .reverse)])
    }

    var body: some View {
        Group {
            if ordered.isEmpty {
                emptyState.frame(maxWidth: .infinity, minHeight: 320)
            } else {
                content
            }
        }
        .task(id: filter) { await resolveRestriction() }
        .mediaViewer(index: $viewerIndex, assets: ordered) { croppedAsset = $0 }
        .sheet(item: $croppedAsset) { asset in
            // Les images de galerie n'étaient recadrables par aucun écran — écart inscrit
            // depuis `V2 bis`, faute d'un écran qui les liste. Le voici. Les **deux** cadres,
            // comme sur la fiche : une image de galerie peut servir de jaquette ou de bandeau.
            CropEditor(asset: asset, contexts: [.hero, .card])
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if isSelecting {
                GallerySelectionBar(assets: selectedAssets) { selection = [] }
            }
            MasonryGrid(
                ordered,
                cardWidth: PosterScale.l.width,
                aspect: GalleryFormat.aspect(of:),
                onAppear: prefetch(around:)
            ) { asset in
                GalleryThumb(
                    GalleryFormat.thumbnail(
                        for: asset, preset: .card, caption: GalleryFormat.caption(of: asset)),
                    isSelected: selection.contains(asset.id)
                ) {
                    open(asset)
                }
                .contextMenu { menu(for: asset) }
            }
        }
    }

    // MARK: L'ordre

    /// Les médias retenus, dans l'ordre d'affichage.
    ///
    /// Le calcul est dans `GalleryOrder`, hors de la vue : c'est lui qui décide, et il se teste.
    private var ordered: [MediaAsset] {
        GalleryOrder.arrange(assets, restrictedTo: restriction, filter: filter)
    }

    private var selectedAssets: [MediaAsset] {
        ordered.filter { selection.contains($0.id) }
    }

    /// Résout la source en identifiants, et **seulement quand le filtre est actif**.
    ///
    /// `GalleryQuery.assetIDs` fait jusqu'à cinq `fetch`, dont deux complets pour la branche
    /// « orphelin ». C'est le prix documenté de cette branche — un orphelin est l'**absence**
    /// d'une ligne, et une absence ne s'exprime pas par un prédicat sur la table qui n'a pas la
    /// ligne. Ne l'appeler que sur demande est ce qui garde l'écran par défaut gratuit.
    private func resolveRestriction() async {
        guard filter.isActive else {
            restriction = nil
            return
        }
        restriction = try? GalleryQuery.assetIDs(matching: filter, in: modelContext)
    }

    // MARK: Le préchargement

    /// L'index qui vient d'entrer à l'écran.
    ///
    /// **Tout ce que cette méthode fait est de transmettre.** La frontière, le cran et la
    /// différence avec l'ordre précédent sont dans `PrefetchScheduler`, hors de la vue — et
    /// c'est ce qui permet de tester l'agrégation entre colonnes, que la maçonnerie rend
    /// désordonnée par construction.
    private func prefetch(around index: Int) {
        let items = ordered
        guard let order = scheduler.advance(appeared: index, count: items.count) else { return }
        media.prefetch(order.prefetch.map { items[$0].id }, context: .card)
        media.cancelPrefetch(order.cancel.map { items[$0].id }, context: .card)
    }

    // MARK: Gestes

    /// Ouvrir, ou sélectionner : le mode décide.
    ///
    /// Bloc `6f` — en mode sélection, un appui coche au lieu d'ouvrir. Sans ce partage, il
    /// faudrait viser une pastille de 24 pt, ce qui est sous la cible de 44.
    private func open(_ asset: MediaAsset) {
        guard !isSelecting else {
            if selection.contains(asset.id) {
                selection.remove(asset.id)
            } else {
                selection.insert(asset.id)
            }
            return
        }
        viewerIndex = ordered.firstIndex { $0.id == asset.id }
    }

    @ViewBuilder
    private func menu(for asset: MediaAsset) -> some View {
        Button("Ouvrir") { viewerIndex = ordered.firstIndex { $0.id == asset.id } }
        Button("Recadrer") { croppedAsset = asset }
        Divider()
        if let flags {
            Button(flags.isFavorite(asset) ? "Retirer des favoris" : "Ajouter aux favoris") {
                flags.toggleFavorite(asset)
            }
        }
        Button(asset.isPrivate ? "Rendre visible" : "Marquer privée") {
            MediaRepository(context: modelContext).update(asset) { $0.isPrivate.toggle() }
        }
        Button("Archiver") {
            MediaRepository(context: modelContext).update(asset) { $0.isArchived = true }
        }
        Divider()
        Button("Mettre à la corbeille", role: .destructive) {
            MediaRepository(context: modelContext).softDelete(asset)
        }
    }

    private var flags: FlagRepository? {
        session.current.map { FlagRepository(context: modelContext, profile: $0) }
    }

    // MARK: Les deux états vides
    //
    // Deux, et c'est la règle de `I10` : « Ta bibliothèque n'a aucune image » et « le filtre ne
    // laisse rien passer » demandent deux messages et deux actions. Un composant à `case`
    // fermés ne savait pas exprimer le second, puisque le package ignore qu'un filtre existe.

    @ViewBuilder private var emptyState: some View {
        if filter.isActive {
            EmptyState(
                title: "Aucune image ne correspond",
                message: "Les sources retenues ne laissent rien passer. Reviens à « Toutes » pour voir large.",
                primary: .init("Toutes les sources") { navigation.galleryFilter.sources = [] },
                hint: "\(assets.count) images au total")
        } else {
            EmptyState(
                title: "Aucune image pour l'instant",
                message: """
                    Les images arrivent par les fiches : dépose un fichier sur un titre, \
                    ou colle depuis le presse-papiers.
                    """,
                hint: "⌘V sur une fiche")
        }
    }
}
