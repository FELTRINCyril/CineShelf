import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V3 · L'écran de galerie
//
// Relevé sur la planche 4 (blocs `6a` à `6f`) et l'addendum 2 bloc `13c`.
//
// **Découpé en deux comme la grille des titres, et pour la même raison** : un `@Query` à
// prédicat dynamique ne se réévalue qu'à la reconstruction de la vue qui le déclare. Cette
// vue porte l'en-tête, les filtres et la sélection ; `GalleryMasonry` porte la requête.
//
// **Ce que la galerie ne fait pas comme la grille.** Elle ne recadre pas et n'impose aucun
// cadre : c'est le seul écran où les ratios se mélangent réellement (§6), donc le seul qui
// exige des colonnes indépendantes. Une image y est montrée **entière**, à sa proportion
// propre — sans quoi l'éditeur de recadrage montrerait autre chose que ce qu'on a cliqué.

struct GalleryView: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock

    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            ScreenHeader(section: .gallery) { actions }
            filterRow
            GalleryMasonry(
                filter: navigation.galleryFilter,
                hidingPrivate: appLock.scope(for: session.current).hidesPrivateContent,
                isSelecting: isSelecting,
                selection: $selection
            )
        }
        // La galerie est une surface de visionnage : **forcée en sombre**, quelle que soit
        // l'apparence système. C'est l'arbitrage 1 du handoff — « accueil, fiches et galerie
        // forcés en sombre, apparence claire pour les écrans de gestion » — et c'était un
        // écart inscrit : les quatre apparences existaient, aucun écran ne posait celle-ci.
        .preferredColorScheme(.dark)
    }

    // MARK: Les actions de l'en-tête — bloc `13c` : Sélectionner · Affichage
    //
    // **« Affichage » n'a pas de menu ici, et c'est un manque du design, pas un oubli.** Le
    // bloc `13c` montre un « Portrait · Medium ▾ » dans la barre de la galerie, mais la
    // matrice se règle par **contexte**, et le jeu des huit contextes de la v1 — celui qui
    // fait foi, `L1 bis` l'a tranché — n'en contient aucun pour la galerie. Il n'y a donc nulle
    // part où mémoriser ce réglage, et « portrait » n'a de toute façon aucun sens en maçonnerie,
    // où le ratio est celui de l'image. Écart inscrit.

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: Space.s5) {
            shuffleButton
            selectionToggle
        }
    }

    /// Le mélange, et **c'est une graine qu'on pose, pas un tri qu'on lance**.
    ///
    /// `L1 bis` a livré `GalleryFilter.shuffleSeed` avec cette exigence : le même ordre tant
    /// qu'on ne rafraîchit pas. Un mélange retiré d'un `random` à chaque évaluation de vue
    /// réordonnerait la grille à chaque défilement — une image changerait de place pendant
    /// qu'on la regarde. Le bouton **remplace** la graine ; c'est le seul geste qui rejoue
    /// l'ordre, et la graine est persistée avec le filtre.
    private var shuffleButton: some View {
        Menu {
            Button("Mélanger") { navigation.galleryFilter.shuffleSeed = UInt64.random(in: .min ... .max) }
            if navigation.galleryFilter.shuffleSeed != nil {
                Button("Ordre chronologique") { navigation.galleryFilter.shuffleSeed = nil }
            }
        } label: {
            Text(navigation.galleryFilter.shuffleSeed == nil ? "Ordre" : "Ordre · mélangé")
                .actionStyle()
                .foregroundStyle(
                    navigation.galleryFilter.shuffleSeed == nil ? Color.textSecondary : Color.accent)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    private var selectionToggle: some View {
        Button(isSelecting ? "Terminé" : "Sélectionner") {
            isSelecting.toggle()
            if !isSelecting { selection = [] }
        }
        .buttonStyle(.plain)
        .actionStyle()
        .foregroundStyle(isSelecting ? Color.accent : Color.textSecondary)
        .frame(minHeight: Space.minHitTarget)
    }

    // MARK: La rangée de filtres — bloc `13c`
    //
    // **Les jetons du prototype sont « Toutes · Affiches · Jaquettes · Plans · Sans titre »,
    // et ce ne sont pas ceux-là.** Ils filtrent par *nature d'image* ; ce que la logique sait
    // filtrer, c'est la **source** — titre, personne, collection, orphelin —, et c'est ce que
    // `L1 bis` a écrit et mesuré. Les deux ne se recouvrent qu'en un point : « Sans titre »
    // est bien l'orphelin. Filtrer par `MediaSlot` serait un autre filtre, à écrire ; l'écart
    // est inscrit plutôt que deviné.
    //
    // **Rendus en `StateBadge` et non en jeton interactif** : le jeton de filtre avec sa croix
    // est un composant de `I5`, palier 3. En écrire une version ici la ferait exister en
    // double le jour où `I5` arrive — c'est la décision déjà prise par `V0 bis` pour la rangée
    // de filtres des titres.

    private var filterRow: some View {
        HStack(spacing: Space.s2) {
            Button("Toutes") { navigation.galleryFilter.sources = [] }
                .buttonStyle(.plain)
                .frame(minHeight: Space.minHitTarget)
                .foregroundStyle(
                    navigation.galleryFilter.isActive ? Color.textTertiary : Color.accent
                )
                .actionStyle()

            ForEach(MediaSource.allCases) { source in
                sourceChip(source)
            }

            Spacer(minLength: Space.s4)

            if isSelecting {
                Text("\(selection.count) sélectionnée(s)")
                    .labelStyle()
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
    }

    private func sourceChip(_ source: MediaSource) -> some View {
        Button {
            toggle(source)
        } label: {
            StateBadge(
                LocalizedStringKey(GalleryFormat.label(for: source)),
                // `.onImage` pour l'état éteint : c'est le jeton `chip.onImage`, celui des
                // jetons non retenus du bloc `13c`. `StateBadge` n'a pas de ton « neutre » et
                // n'en a pas besoin — quatre tons, tous sémantiques.
                tone: isOn(source) ? .accent : .onImage)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Space.minHitTarget)
    }

    /// Une source est « allumée » quand le filtre la retient explicitement.
    ///
    /// Filtre vide vaut « toutes » (`L1 bis`), donc **aucun** jeton n'est allumé au repos : ce
    /// n'est pas la même chose que « les quatre sont cochés », et l'afficher ainsi ferait
    /// croire qu'un filtre est actif alors qu'il n'y en a pas.
    private func isOn(_ source: MediaSource) -> Bool {
        navigation.galleryFilter.sources.contains(source)
    }

    /// Décocher la dernière source **ne vide pas l'écran** : elle repasse à « toutes ».
    ///
    /// C'est le piège que `L1 bis` a nommé en écrivant « vide vaut toutes » : l'utilisateur
    /// décoche la dernière case et l'écran se vide sans qu'aucun message l'explique. Ici,
    /// retirer la dernière source revient à ne plus filtrer.
    private func toggle(_ source: MediaSource) {
        var sources = navigation.galleryFilter.sources
        if sources.contains(source) {
            sources.remove(source)
        } else {
            sources.insert(source)
        }
        navigation.galleryFilter.sources = sources.count == MediaSource.allCases.count ? [] : sources
    }
}

#Preview("Galerie") {
    NavigationStack {
        GalleryView()
    }
}
