import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V10 · « Synchronisation et données » du bloc `7g`
//
// **L'écran qui donne enfin des appelants à trois choses écrites et jamais lues** : `SyncStatus`
// et sa machine (`L17`), `TrashService` et `MaintenanceService` (`L16`), et le composant
// `Banner` du lot `I10`, qui se validait au catalogue sans qu'aucune vue ne l'affiche.
//
// Le prototype pose trois lignes, et c'est exactement ce qui suit :
//
//     iCloud · 2,4 Go sur 5 Go            48 % · quota bientôt atteint
//     Corbeille                            purge automatique après 30 jours · 41 éléments
//     Maintenance                          détection d'orphelins            [Analyser]
//
// **Ce que cet écran ne peut pas prouver, et qui doit être dit** : la synchronisation réelle
// attend le prompt 21. `SyncStatus` est alimenté ici par ce que l'app **sait** de l'appareil —
// pas par `NSPersistentCloudKitContainer.eventChangedNotification`, qui n'existe pas tant que
// `FeatureFlags.cloudKitEnabled` est faux. L'écran est donc vrai sur ce qu'il montre et muet
// sur ce qu'il ne peut pas encore observer, plutôt que de simuler une progression.

struct SyncAndDataSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var status: SyncStatus = .upToDate(nil)
    @State private var trashCount = 0
    @State private var unreferencedAssets = 0
    @State private var footprint: Int64 = 0
    @State private var isShowingTrash = false
    @State private var lastReport: MaintenanceReport?
    @State private var failure: String?

    var body: some View {
        Section("Synchronisation et données") {
            syncRow
            trashRow
            maintenanceRow
            if let failure {
                Text(failure)
                    .calloutStyle()
                    .foregroundStyle(Color.danger)
            }
        }
        .task { refresh() }
        .sheet(isPresented: $isShowingTrash) {
            TrashView(onChange: refresh)
        }
    }

    // MARK: iCloud

    /// L'état de synchronisation, et **le bandeau seulement quand il demande l'attention**.
    ///
    /// `SyncStatus.needsAttention` décide : « hors ligne » est une information, pas un problème,
    /// et le bloc `9c` réserve le bandeau aux interruptions. Les autres cas se lisent en une
    /// ligne de texte, sans mobiliser un composant fait pour arrêter le regard.
    @ViewBuilder
    private var syncRow: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            LabeledContent("iCloud") {
                Text(StorageFootprint.formatted(footprint))
                    .numericStyle()
                    .foregroundStyle(Color.textSecondary)
            }
            if status.needsAttention {
                Banner(
                    kind: "Synchronisation",
                    text: LocalizedStringKey(status.message),
                    tone: .danger,
                    action: status.actionLabel.map { label in
                        Banner.BannerAction(LocalizedStringKey(label)) { openSystemSettings() }
                    })
            } else {
                Text(status.message)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
            if case .syncing(_, let progress) = status, let progress {
                ProgressTrack(
                    segments: [.init(id: "done", value: Int(progress * 100), role: .done)],
                    total: 100)
            }
        }
    }

    // MARK: La corbeille

    /// « purge automatique après 30 jours · 41 éléments », mot pour mot du prototype.
    ///
    /// **Le compte est réel et non décoratif** : sans lui, un utilisateur qui a supprimé par
    /// erreur ne sait pas qu'il a trente jours pour se raviser — et `deletedAt` n'aurait servi à
    /// rien, ce qui est exactement le défaut que `L16` a passé sa passe à éviter.
    private var trashRow: some View {
        LabeledContent {
            Button("Ouvrir") { isShowingTrash = true }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
                .disabled(trashCount == 0)
        } label: {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Corbeille")
                Text(trashSubtitle)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var trashSubtitle: String {
        let count =
            trashCount == 0
            ? "aucun élément"
            : "\(trashCount) élément\(trashCount == 1 ? "" : "s")"
        return "purge automatique après \(MaintenanceService.retentionDays) jours · \(count)"
    }

    // MARK: La maintenance

    /// « détection d'orphelins », et **« Analyser » lance la passe pour de vrai**.
    ///
    /// Le prototype dit aussi « déduplication par empreinte » ; elle n'est pas rendue, parce que
    /// `MaintenanceService` ne la fait pas — `MediaRepository.findOrCreate` dédoublonne à
    /// l'import, par `checksum`, et aucune passe ne rattrape les doublons déjà en base. Le dire
    /// vaut mieux qu'un libellé qui promet un travail qui n'a pas lieu.
    private var maintenanceRow: some View {
        LabeledContent {
            Button("Analyser") { analyse() }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
        } label: {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Maintenance")
                Text(maintenanceSubtitle)
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var maintenanceSubtitle: String {
        guard let lastReport else {
            return unreferencedAssets == 0
                ? "détection d'orphelins"
                : "détection d'orphelins · \(unreferencedAssets) médias sans rattachement"
        }
        if lastReport.isEmpty {
            return unreferencedAssets == 0
                ? "rien à réparer"
                : "rien à réparer · \(unreferencedAssets) médias sans rattachement"
        }
        // **Ce qui a été fait, chiffré.** Une passe d'entretien qui dit « terminé » sans dire ce
        // qu'elle a touché est une passe qu'on ne peut pas relire — et celle-ci supprime.
        var parts: [String] = []
        if lastReport.purgedCount > 0 { parts.append("\(lastReport.purgedCount) purgés") }
        if lastReport.orphanAttachmentsRemoved > 0 {
            parts.append("\(lastReport.orphanAttachmentsRemoved) rattachements orphelins")
        }
        if lastReport.multiOwnerAttachmentsRepaired > 0 {
            parts.append("\(lastReport.multiOwnerAttachmentsRepaired) réparés")
        }
        if lastReport.headlessCreditsRemoved > 0 {
            parts.append("\(lastReport.headlessCreditsRemoved) crédits sans personne")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Les actions

    private func refresh() {
        let trash = TrashService(context: modelContext)
        trashCount = (try? trash.items().count) ?? 0
        footprint = StorageFootprint.total(of: StorageFootprint.appLocations())
        // La lecture seule de la passe : elle compte sans rien modifier, donc l'ouvrir sur un
        // écran de réglages est sans conséquence.
        unreferencedAssets = (try? MaintenanceService(context: modelContext).survey()) ?? 0
    }

    private func analyse() {
        failure = nil
        do {
            lastReport = try MaintenanceService(context: modelContext).run()
            refresh()
        } catch {
            failure = "L'analyse n'a pas pu se terminer. Rien n'a été modifié."
        }
    }

    /// Ouvre les réglages du système. **Le seul chemin que l'app puisse offrir** : ni le compte
    /// iCloud ni le quota ne se règlent depuis un bac à sable.
    private func openSystemSettings() {
        #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #else
            if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
                NSWorkspace.shared.open(url)
            }
        #endif
    }
}
