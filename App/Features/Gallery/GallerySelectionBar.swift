import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V3 · La barre d'actions de la sélection multiple — bloc `6f`
//
// Relevée sur la planche 4 :
//
//     <div style="height:78px;background:oklch(0.16 0 0);display:flex;align-items:center;
//                 gap:26px;padding:0 36px">
//       <span>6 images · 18,4 Mo</span>  … ♥ Favori · Rattacher à… · Exporter ·
//       Marquer privées · Archiver   <span style="background:oklch(0.42 0.16 27)">Corbeille</span>
//
// **Deux écarts au bloc, tous deux assumés et inscrits.**
//
// 1. **Elle est posée sous l'en-tête, pas en bas de fenêtre.** Le prototype l'épingle au bas
//    du cadre ; l'écran, lui, est un *contenu* de la `ScrollView` que le chrome possède
//    (décision de `V0`). Rien ne s'épingle au bas de la fenêtre depuis l'intérieur d'un
//    contenu défilant, et ouvrir une seconde `ScrollView` serait pire que l'écart. Le jour
//    où le chrome proposera un emplacement bas, la barre y déménagera sans changer d'un mot.
//
// 2. **« Rattacher à… » et « Exporter » ne sont pas rendues.** La première demande un
//    sélecteur d'entité, qui est un composant de `I9` (palier 3) ; la seconde appartient à
//    l'export, qui est `V8`. Un bouton qui ne fait rien est pire qu'un bouton absent : il
//    apprend à ne pas croire l'interface. Les quatre autres actions sont réelles.
//
// **L'action destructrice est à part**, elle : c'est la seule chose que le bloc met à droite,
// détachée du groupe, sur un fond `danger`. Ce n'est pas décoratif — c'est ce qui empêche de
// la cliquer en visant « Archiver ».

struct GallerySelectionBar: View {
    let assets: [MediaAsset]
    let onClear: () -> Void

    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: Space.s5) {
            Text(GalleryFormat.selectionSummary(assets))
                .font(Typo.micro)
                .foregroundStyle(Color.textTertiary)

            Spacer(minLength: Space.s4)

            favoriteButton
            action("Marquer privées") { $0.isPrivate = true }
            action("Archiver") { $0.isArchived = true }

            Button("Mettre à la corbeille", role: .destructive) {
                let repository = MediaRepository(context: modelContext)
                for asset in assets { repository.softDelete(asset) }
                onClear()
            }
            .buttonStyle(.plain)
            .actionStyle()
            .foregroundStyle(Color.accentOnAccent)
            .padding(.horizontal, Space.s3)
            .frame(minHeight: Space.minHitTarget)
            .background(Color.danger)
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
        .frame(minHeight: 78)
        .background(Color.bgSurface)
        .disabled(assets.isEmpty)
    }

    /// Le favori **ne passe pas par `MediaRepository.update`**, et c'est une distinction de
    /// modèle, pas un détail : « favori » est un `MediaFlag`, donc une donnée **par profil**,
    /// alors que `isPrivate` et `isArchived` appartiennent au média. Les mêler aurait écrit le
    /// goût d'un profil dans une propriété que tous les profils partagent.
    ///
    /// **Tout ou rien** : si un seul des médias sélectionnés n'est pas favori, l'action les
    /// ajoute tous. Sans cette règle, une bascule individuelle sur une sélection mixte
    /// inverserait chaque état et n'aurait aucun effet lisible.
    private var favoriteButton: some View {
        Button(allFavorite ? "Retirer des favoris" : "Favori") {
            guard let flags else { return }
            let target = !allFavorite
            for asset in assets where flags.isFavorite(asset) != target {
                flags.toggleFavorite(asset)
            }
        }
        .buttonStyle(.plain)
        .actionStyle()
        .foregroundStyle(Color.accent)
        .frame(minHeight: Space.minHitTarget)
        .disabled(flags == nil)
    }

    private var allFavorite: Bool {
        guard let flags, !assets.isEmpty else { return false }
        return assets.allSatisfy { flags.isFavorite($0) }
    }

    /// Une action de masse, appliquée média par média à travers le repository.
    ///
    /// **Jamais une écriture directe** : `MediaRepository.update` horodate et inscrit l'entrée
    /// du fil d'activité. Une boucle qui écrirait `asset.isPrivate` à la main perdrait les deux,
    /// et rien ne le signalerait.
    private func action(
        _ label: LocalizedStringKey, tinted: Bool = false, _ change: @escaping (MediaAsset) -> Void
    ) -> some View {
        Button(label) {
            let repository = MediaRepository(context: modelContext)
            for asset in assets {
                repository.update(asset) { change($0) }
            }
        }
        .buttonStyle(.plain)
        .actionStyle()
        .foregroundStyle(tinted ? Color.accent : Color.textPrimary)
        .frame(minHeight: Space.minHitTarget)
    }

    private var flags: FlagRepository? {
        session.current.map { FlagRepository(context: modelContext, profile: $0) }
    }
}
