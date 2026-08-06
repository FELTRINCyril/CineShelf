import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V5b · Le fil d'activité
//
// Planche 3 bloc `5e` : « Fil · 1 402 événements · 30 jours conservés · Types ▾ · Profils ▾ »,
// puis des groupes « Aujourd'hui » et « Hier ». **C'est un journal daté, pas un flux social**,
// et le §6 du handoff le dit explicitement.
//
// **Une liste, pas une grille.** Le lot 2 de la planche 3 l'écrit : « Signets et Fil sont des
// listes — pas de grille d'affiches là où l'objet n'est pas une affiche. »
//
// **`ActivityEntry` a attendu quinze prompts son premier lecteur** (`ActivityFeed`, à `L18`) et
// deux de plus son premier écran. Ce fichier est cet écran.
//
// **Trois choses du bloc `5e` ne sont pas rendues :**
//
// 1. **« Annuler » sur chaque ligne.** C'est `L20` — annulation de l'édition en masse et de la
//    fusion — qui est la tâche 19 du palier et n'est pas faite. `ActivityItem.isUndoable`
//    existe déjà et dit *laquelle* serait annulable ; ce qui manque est l'exécuteur. La ligne
//    est donc rendue **sans le bouton**, jamais avec un bouton inerte : un bouton qui ne fait
//    rien d'utile apprend à ne pas croire l'interface, et c'est la décision déjà prise pour
//    les actions de `SyncStatus`.
// 2. **« Profils ▾ ».** `ActivityFilter` ne porte pas de profil, et `ActivityEntry` non plus —
//    le schéma est fermé. Le filtre par type est rendu, celui par profil ne peut pas l'être.
// 3. **« 1 402 événements ».** Le compte total demanderait un `fetchCount` sur tout le
//    journal, alors que l'écran lit une fenêtre. L'en-tête annonce donc ce qu'il montre.

struct ActivityFeedView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var days: [ActivityDay] = []
    @State private var filter = ActivityFilter()
    @State private var cursor: Date?
    @State private var hasMore = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            ScreenHeader(section: .activity, count: countLabel) { actions }

            if days.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                ForEach(days) { day in
                    section(for: day)
                }
                loadMore
            }
        }
        .padding(.bottom, Space.s7)
        // `id: filter` : changer de filtre repart de la première page, sinon le curseur
        // hérité de la lecture précédente sauterait le début du journal.
        .task(id: filter) { await reload() }
    }

    /// Ce que l'écran montre, et **seulement** ça.
    ///
    /// « 47 événements · 30 jours conservés » plutôt que le total du journal : la fenêtre en
    /// rend cent au plus, et annoncer un total qu'on n'a pas compté serait un chiffre inventé.
    private var countLabel: String {
        let shown = days.reduce(0) { $0 + $1.entries.count }
        let events = shown == 1 ? "1 événement" : "\(shown) événements"
        return "\(events) · 30 jours conservés"
    }

    // MARK: Les actions — « Types ▾ » du bloc `5e`

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: Space.s5) {
            typeMenu
            if filter.isActive {
                Button("Tout effacer") { filter = ActivityFilter() }
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textTertiary)
                    .frame(minHeight: Space.minHitTarget)
            }
        }
    }

    private var typeMenu: some View {
        Menu {
            ForEach(ActivityEntityType.allCases, id: \.self) { type in
                Button {
                    toggle(type)
                } label: {
                    Label(
                        type.pluralLabel,
                        systemImage: filter.entityTypes.contains(type) ? "checkmark" : "")
                }
            }
        } label: {
            Text(filter.isActive ? "Types · actifs" : "Types")
                .actionStyle()
                .foregroundStyle(filter.isActive ? Color.accent : Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minHeight: Space.minHitTarget)
    }

    private func toggle(_ type: ActivityEntityType) {
        var types = filter.entityTypes
        if types.contains(type) { types.remove(type) } else { types.insert(type) }
        filter = ActivityFilter(actions: filter.actions, entityTypes: types)
    }

    // MARK: Un jour

    private func section(for day: ActivityDay) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(dayLabel(day.id))
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
                .padding(.top, Space.s3)

            ForEach(day.entries) { item in
                row(item)
            }
        }
        .padding(.horizontal, Breakpoint.macStandard.screenMargin)
    }

    /// Une ligne : l'heure, le verbe, l'objet.
    ///
    /// **`summary` est figé à l'écriture, jamais résolu à la lecture** — c'est ce qui rend
    /// lisible l'entrée d'un titre supprimé, c'est-à-dire précisément ce qu'on vient consulter
    /// après une suppression.
    private func row(_ item: ActivityItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Text(item.date.formatted(.dateTime.hour().minute()))
                .numericStyle()
                .foregroundStyle(Color.textTertiary)
                .frame(width: 56, alignment: .leading)

            Text(item.actionLabel)
                .calloutStyle()
                .foregroundStyle(Color.textSecondary)
                .frame(width: 150, alignment: .leading)

            Text(item.summary)
                .calloutStyle()
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // **Pas un `StateBadge`.** Ses quatre tons — sur image, accent, succès, danger —
            // portent tous un sens d'état, et « Titre » n'en est pas un : c'est une
            // catégorie. Un jeton accentué sur chaque ligne peindrait le fil entier en ambre.
            Text(item.entityLabel)
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
                .frame(width: 90, alignment: .trailing)
        }
        .frame(minHeight: Space.minHitTarget)
    }

    /// « Aujourd'hui », « Hier », puis la date.
    ///
    /// **Le jour est celui de l'utilisateur.** `ActivityFeed.group` regroupe déjà en calendrier
    /// local, et l'étiquette doit dire la même chose que le regroupement — sans quoi une entrée
    /// tomberait sous « Hier » un jour où elle est d'aujourd'hui.
    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    // MARK: États et pagination

    private var emptyState: some View {
        EmptyState(
            title: filter.isActive ? "Aucun événement de ce type" : "Rien à signaler",
            message: filter.isActive
                ? "Aucune entrée des trente derniers jours ne correspond à ces types."
                : "Le fil montre ce que tu as fait à ta collection. Il se remplira tout seul.",
            primary: filter.isActive
                ? .init("Effacer les types") { filter = ActivityFilter() } : nil
        )
    }

    /// **La pagination est un curseur de date, pas un décalage.** Un `offset` se décale dès
    /// qu'une entrée s'écrit entre deux pages, et le fil saute une ligne — sur un journal qui
    /// s'écrit en continu, ce n'est pas un cas rare, c'est le cas.
    @ViewBuilder
    private var loadMore: some View {
        if hasMore {
            Button("Charger les événements plus anciens") {
                Task { await appendPage() }
            }
            .buttonStyle(ActionButtonStyle(rank: .secondary))
            .padding(.horizontal, Breakpoint.macStandard.screenMargin)
            .padding(.top, Space.s4)
        }
    }

    private func reload() async {
        cursor = nil
        hasMore = true
        days = (try? ActivityFeed.days(matching: filter, in: modelContext)) ?? []
        advanceCursor(from: days)
    }

    private func appendPage() async {
        guard let cursor else {
            hasMore = false
            return
        }
        let page = (try? ActivityFeed.days(matching: filter, before: cursor, in: modelContext)) ?? []
        guard !page.isEmpty else {
            hasMore = false
            return
        }
        merge(page)
        advanceCursor(from: page)
    }

    /// Recolle la page à la précédente **sans dupliquer le jour de jointure**.
    ///
    /// Une page se termine presque toujours au milieu d'un jour : sans cette fusion, « Hier »
    /// apparaîtrait deux fois, avec ses entrées coupées en deux paquets.
    private func merge(_ page: [ActivityDay]) {
        var merged = days
        for day in page {
            if let index = merged.firstIndex(where: { $0.id == day.id }) {
                merged[index] = ActivityDay(
                    id: day.id, entries: merged[index].entries + day.entries)
            } else {
                merged.append(day)
            }
        }
        days = merged
    }

    /// Le curseur est la date de la **dernière entrée rendue**, et `ActivityFeed.days` ne rend
    /// que ce qui lui est antérieur — donc aucune entrée n'est vue deux fois.
    private func advanceCursor(from page: [ActivityDay]) {
        cursor = page.last?.entries.last?.date
        // Une fenêtre filtrée peut rendre moins que `limit` sans que le journal soit épuisé :
        // le filtre s'applique après le `fetch`. Tant qu'un curseur existe, on propose la
        // suite plutôt que de conclure à tort que c'est fini.
        if cursor == nil { hasMore = false }
    }

}
