import DesignSystem
import SwiftUI

// MARK: - V0 · L'indicateur de synchronisation
//
// Relevé sur la planche 2 bloc `3a`, « Indicateur de synchronisation — quatre états » :
//
//     <span style="width:7px;height:7px;border-radius:50%;
//                  background:oklch(0.72 0.17 145)"></span> À jour · il y a 2 min
//     … Synchronisation · 312 sur 1 284
//     … Hors ligne · modifications en attente
//     … Quota iCloud dépassé · gérer
//
// **La pastille est le seul rond de toute l'interface, et c'est assumé** : elle fait 7 pt,
// elle n'est pas une surface, et le prototype la dessine ainsi aux quatre états. Ce n'est
// pas le liseré arrondi de la direction `1a` — c'est un point de statut, la même
// convention que la pastille de notification du système.
//
// **L'état réel viendra de `L17`**, qui n'est pas faite : les quatre cas existent dans
// `SyncState` (`DesignSystem`) mais rien ne les alimente. La barre affiche donc `.upToDate`
// tant que `L17` n'a pas branché le conteneur CloudKit. C'est un état par défaut honnête —
// il n'invente pas une synchronisation en cours — et l'écart est déjà inscrit.

struct SyncIndicator: View {
    /// L'état affiché. Constant jusqu'à `L17` : voir l'en-tête.
    var state: SyncState = .upToDate(.distantPast)

    var body: some View {
        HStack(spacing: Space.s2) {
            dot
            Text(label)
                .font(Typo.micro)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .frame(minHeight: Space.minHitTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Synchronisation : \(label)")
    }

    private var dot: some View {
        Circle()
            .fill(tint)
            .frame(width: 7, height: 7)
    }

    private var tint: Color {
        switch state {
        case .upToDate: .success
        case .syncing: .accent
        case .offline: .textTertiary
        case .failed: .danger
        }
    }

    private var label: String {
        switch state {
        case .upToDate: "À jour"
        case .syncing(let fraction):
            if let fraction { "Synchronisation · \(Int(fraction * 100)) %" } else { "Synchronisation" }
        case .offline: "Hors ligne"
        case .failed(let reason): reason
        }
    }
}

#Preview("Les quatre états") {
    VStack(alignment: .leading, spacing: Space.s3) {
        SyncIndicator(state: .upToDate(.distantPast))
        SyncIndicator(state: .syncing(0.24))
        SyncIndicator(state: .offline)
        SyncIndicator(state: .failed("Quota iCloud dépassé"))
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
