import CineShelfCore
import DesignSystem
import SwiftUI

// MARK: - V10 · La corbeille
//
// **`TrashService` était écrit, testé, et sans le moindre appelant.** C'est le miroir exact du
// défaut inverse — une capacité lue et jamais écrite — qu'on a vu trois fois : ici la donnée
// s'écrit (`deletedAt`), la logique de relecture existe, et **rien ne la montre**. Une corbeille
// qu'on ne peut pas ouvrir n'est pas une corbeille, c'est une suppression différée de trente
// jours.
//
// Le prototype `7g` n'en dessine que la ligne d'entrée — « Corbeille · purge automatique après
// 30 jours · 41 éléments ». La liste elle-même n'est pas dessinée : elle suit le registre de la
// console (bloc `7a`), lignes denses et compte à rebours en tête, plutôt que d'inventer un
// troisième registre.

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Prévient l'appelant qu'un compte a changé, pour qu'il rafraîchisse sa ligne.
    let onChange: () -> Void

    @State private var items: [TrashedItem] = []
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            header
            if items.isEmpty {
                EmptyState(
                    title: "La corbeille est vide",
                    message: """
                        Ce que tu supprimes reste ici \(MaintenanceService.retentionDays) jours \
                        avant de disparaître définitivement.
                        """)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.s2) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                }
            }
            if let failure {
                Text(failure).calloutStyle().foregroundStyle(Color.danger)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s5)
        .frame(minWidth: 520, minHeight: 420)
        .task { reload() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text("Corbeille")
                .title2Style()
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .metaStyle()
                .foregroundStyle(Color.textTertiary)
            Spacer(minLength: Space.s4)
            Button("Fermer") { dismiss() }
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Space.minHitTarget)
        }
    }

    private var subtitle: String {
        let expired = items.filter(\.isExpired).count
        let base = "purge automatique après \(MaintenanceService.retentionDays) jours"
        guard expired > 0 else { return base }
        // **Les expirés se disent**, parce qu'ils partiront au prochain entretien : les taire
        // laisserait croire à un sursis que le compte à rebours ne donne plus.
        return base + " · \(expired) en sursis dépassé"
    }

    private func row(_ item: TrashedItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Text(label(for: item.entity))
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
                .frame(width: 92, alignment: .leading)
            Text(item.label)
                .calloutStyle()
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(countdown(item))
                .numericStyle()
                .foregroundStyle(item.isExpired ? Color.danger : Color.textTertiary)
            Button("Restaurer") { restore(item) }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
        }
        .frame(minHeight: Space.minHitTarget)
    }

    /// Le compte à rebours, **négatif compris**.
    ///
    /// Un élément expiré n'est supprimé qu'au prochain passage de la maintenance : afficher
    /// « 0 jour » ferait croire à un sursis qui n'existe pas.
    private func countdown(_ item: TrashedItem) -> String {
        item.isExpired
            ? "expiré"
            : "\(item.daysRemaining) j"
    }

    /// Le nom du type, en français. **Dans l'écran et non dans `CineShelfCore`** : le paquet
    /// n'écrit pas de texte d'interface.
    private func label(for entity: ActivityEntityType) -> String {
        switch entity {
        case .title: "Titre"
        case .person: "Personne"
        case .collection: "Collection"
        case .genre: "Genre"
        case .savedLink: "Lien"
        case .media: "Média"
        default: "Élément"
        }
    }

    private func reload() {
        items = (try? TrashService(context: modelContext).items()) ?? []
    }

    private func restore(_ item: TrashedItem) {
        failure = nil
        do {
            let restored = try TrashService(context: modelContext).restore(item)
            try modelContext.save()
            if !restored {
                // Le cas est réel : la liste est affichée, la maintenance passe, on clique.
                failure = "Cet élément a déjà été supprimé définitivement."
            }
            reload()
            onChange()
        } catch {
            failure = "La restauration a échoué."
        }
    }
}
