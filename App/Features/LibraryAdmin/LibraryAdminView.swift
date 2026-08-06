import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V6 · La console de gestion
//
// Planche 5, blocs `7a` et `7b`. **Trois colonnes** : la liste des entités à gauche, la table
// au centre, l'inspecteur à droite.
//
// **L'édition en masse n'est pas un écran, c'est l'inspecteur.** Le bloc `7b` montre la même
// colonne de droite que le `7a`, avec « valeurs multiples » là où les lignes divergent. En
// faire une feuille séparée demanderait à l'utilisateur de perdre sa sélection des yeux
// pendant qu'il décide de ce qu'il lui applique.
//
// **Elle ne se livre pas sans `L20`, et `L20` est faite** : une sélection mal cliquée peut
// détruire une heure de saisie, et le seul recours acceptable est de pouvoir défaire. Le
// bandeau d'annulation est donc posé ici, pas remis à plus tard.
//
// **Ce qui est hors périmètre v1, et pourquoi** — « `V6` au-delà d'une `Table` brute » est
// reporté : colonnes réordonnables, édition en ligne, mise en forme conditionnelle. Reste ce
// que la fiche garde : une `Table` par entité, le tri par colonne, la sélection multiple.

struct LibraryAdminView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(AppLock.self) private var appLock
    @Environment(\.modelContext) private var modelContext

    @State private var entity: ConsoleEntity = .titles
    @State private var selection: Set<UUID> = []
    @State private var search = ""
    @State private var undoable: UUID?
    @State private var banner: String?

    var body: some View {
        HStack(spacing: 0) {
            entityList
            Divider().overlay(Color.separatorLine)
            table
            Divider().overlay(Color.separatorLine)
            inspector
        }
        .background(Color.bgInset)
        .overlay(alignment: .bottom) { undoBanner }
    }

    private var scope: PrivacyScope { appLock.scope(for: session.current) }

    // MARK: La colonne des entités — bloc `7a`, « BIBLIOTHÈQUE »

    private var entityList: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Bibliothèque")
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, Space.s2)

            ForEach(ConsoleEntity.allCases) { candidate in
                Button {
                    entity = candidate
                    selection = []
                } label: {
                    HStack(spacing: Space.s2) {
                        Text(candidate.label)
                            .calloutStyle()
                            .foregroundStyle(
                                candidate == entity ? Color.accent : Color.textSecondary)
                        Spacer(minLength: Space.s3)
                        CountBadge(count(of: candidate))
                    }
                    .frame(minHeight: Space.minHitTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s4)
        .frame(width: 220, alignment: .leading)
    }

    // MARK: La table

    private var table: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            header
            ConsoleTable(
                entity: entity, scope: scope, libraryID: session.current?.library?.id,
                search: search, selection: $selection)
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Text(entity.label)
                .title2Style()
                .foregroundStyle(Color.textPrimary)
            Text(selectionLabel)
                .numericStyle()
                .foregroundStyle(Color.textTertiary)
            Spacer(minLength: Space.s4)
            TextField("Filtrer les lignes…", text: $search)
                .textFieldStyle(.plain)
                .font(Typo.callout)
                .frame(maxWidth: 260)
        }
    }

    /// « 1 284 lignes · 1 sélectionnée » — bloc `7a`.
    private var selectionLabel: String {
        let total = count(of: entity)
        let lines = total == 1 ? "1 ligne" : "\(total) lignes"
        guard !selection.isEmpty else { return lines }
        let picked = selection.count == 1 ? "1 sélectionnée" : "\(selection.count) sélectionnées"
        return "\(lines) · \(picked)"
    }

    // MARK: L'inspecteur — un seul, deux visages

    /// **Le même emplacement pour une ligne et pour un lot.** Ce qui change est le contenu du
    /// formulaire, pas sa place : c'est ce que les blocs `7a` et `7b` montrent, et c'est ce qui
    /// permet de garder la sélection sous les yeux pendant qu'on décide.
    @ViewBuilder
    private var inspector: some View {
        Group {
            if selection.isEmpty {
                EmptyState(
                    title: "Aucune ligne sélectionnée",
                    message:
                        "Choisis une ligne pour l'éditer, ou plusieurs pour les modifier ensemble."
                )
            } else {
                BulkEditPanel(
                    entity: entity,
                    selection: selection,
                    onApplied: { activityID, count in
                        undoable = activityID
                        banner = count == 1 ? "1 ligne modifiée" : "\(count) lignes modifiées"
                    },
                    onRefused: { banner = $0 })
            }
        }
        .frame(width: 320)
        .padding(Space.s4)
        .background(Color.bgSurface)
    }

    // MARK: Le bandeau d'annulation
    //
    // **Il existe parce que `L20` existe.** Sans exécuteur d'annulation, ce bandeau serait un
    // bouton inerte — la décision déjà prise pour l'« Annuler » du fil et pour les actions
    // absentes de `SyncStatus`.

    @ViewBuilder
    private var undoBanner: some View {
        if let banner {
            HStack(spacing: Space.s4) {
                Text(banner)
                    .calloutStyle()
                    .foregroundStyle(Color.textPrimary)
                if undoable != nil {
                    Button("Annuler", action: undoLastBatch)
                        .buttonStyle(ActionButtonStyle(rank: .secondary))
                }
                Button("Fermer") {
                    self.banner = nil
                    undoable = nil
                }
                .buttonStyle(.plain)
                .actionStyle()
                .foregroundStyle(Color.textTertiary)
                .frame(minHeight: Space.minHitTarget)
            }
            .padding(Space.s4)
            .background(Color.bgRaised)
            .clipShape(.rect(cornerRadius: Radius.m, style: .continuous))
            .padding(Space.s5)
        }
    }

    private func undoLastBatch() {
        guard let activityID = undoable else { return }
        let outcome = try? BulkEditUndoer(context: modelContext).undo(activityID: activityID)
        switch outcome {
        case .undone(let count):
            banner =
                count == 1 ? "1 ligne remise en arrière" : "\(count) lignes remises en arrière"
        case .refused(let refusals):
            // **Le refus se dit.** « Refuser plutôt qu'écraser » ne vaut que si l'utilisateur
            // apprend *pourquoi* : sinon le bouton paraît cassé, et il recommencera.
            banner = ConsoleMessages.refusal(refusals)
        case nil:
            banner = "L'annulation a échoué."
        }
        undoable = nil
    }

    private func count(of entity: ConsoleEntity) -> Int {
        entity.count(in: modelContext, scope: scope, libraryID: session.current?.library?.id)
    }
}

/// Les messages de refus de la console.
///
/// **Hors de la vue pour être testables.** Un refus d'annulation est exactement le genre de
/// texte qu'on écrit une fois et qu'on ne relit jamais ; l'extraire permet d'assener que chaque
/// cause a bien son message, et qu'aucune ne retombe sur un repli vague.
enum ConsoleMessages {

    static func refusal(_ refusals: [UndoRefusal]) -> String {
        guard let first = refusals.first else { return "Annulation impossible." }
        return switch first.reason {
        case .alreadyUndone: "Ce lot a déjà été annulé."
        case .expired: "Ce lot est trop ancien pour être annulé."
        case .entityInTrash: "Une des lignes est à la corbeille. Restaure-la d'abord."
        case .entityNotFound: "Une des lignes n'existe plus."
        case .fieldChangedSince(let field, _, _):
            "Une ligne a été modifiée depuis (\(field)). Rien n'a été touché."
        case .relationChangedSince: "Une relation a changé depuis. Rien n'a été touché."
        case .notUndoable, .entryNotFound, .unsupportedVersion: "Ce lot n'est pas annulable."
        }
    }
}

/// Les entités que la console liste — bloc `7a`, colonne de gauche.
///
/// **Titres et personnes seulement.** Le prototype en montre une dizaine, mais l'édition en
/// masse de `L10` ne couvre que ces deux-là : afficher une entrée « Genres » qui ouvre une
/// table sans inspecteur donnerait une console à moitié morte. Écart inscrit.
enum ConsoleEntity: String, CaseIterable, Identifiable {
    case titles, people

    var id: String { rawValue }

    var label: String {
        switch self {
        case .titles: "Titres"
        case .people: "Personnes"
        }
    }

    @MainActor
    func count(in context: ModelContext, scope: PrivacyScope, libraryID: UUID?) -> Int {
        switch self {
        case .titles:
            let descriptor = FetchDescriptor<Title>(
                predicate: TitleFilter().predicate(
                    hidingPrivate: scope.hidesPrivateContent, libraryID: libraryID))
            return (try? context.fetchCount(descriptor)) ?? 0
        case .people:
            let descriptor = FetchDescriptor<Person>(
                predicate: PersonFilter().predicate(
                    hidingPrivate: scope.hidesPrivateContent, libraryID: libraryID))
            return (try? context.fetchCount(descriptor)) ?? 0
        }
    }
}
