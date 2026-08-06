import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V6 · L'édition en masse, dans l'inspecteur
//
// Planche 5, bloc `7b`. **Ce n'est pas un écran** : c'est la même colonne de droite que le
// bloc `7a`, dont le contenu change quand la sélection dépasse une ligne.
//
// **« Seuls les champs modifiés sont appliqués. Les autres gardent leur valeur d'origine. »**
// Le prototype l'écrit sous le formulaire, et c'est la règle qui décide de toute la forme :
// chaque champ part à « ne pas toucher », et il faut un geste explicite pour qu'il entre dans
// la mutation. Un formulaire pré-rempli avec les valeurs de la première ligne écraserait les
// quatre autres au premier « Appliquer ».
//
// **Une mutation à la fois, et c'est une contrainte de `L10`, pas un choix d'écran.**
// `BulkEditor.apply` prend **une** mutation et écrit **un** diff : c'est ce qui rend le lot
// annulable d'un bloc par `L20`. Appliquer trois champs d'un coup produirait trois lots, donc
// trois annulations séparées — et un utilisateur qui en défait deux sur trois se retrouve dans
// un état que personne n'a voulu. L'écran applique donc champ par champ, et le dit.

struct BulkEditPanel: View {
    let entity: ConsoleEntity
    let selection: Set<UUID>
    let onApplied: (UUID, Int) -> Void
    let onRefused: (String) -> Void

    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var rating: Double?
    @State private var runtime: Double?
    @State private var genreNames: [String] = []
    @State private var isPrivate: Bool?
    @State private var isArchived: Bool?

    @Query(filter: GenreQuery.living, sort: \Genre.name) private var genres: [Genre]

    var body: some View {
        ScreenScroll {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(headline)
                    .headlineStyle()
                    .foregroundStyle(Color.textPrimary)

                switch entity {
                case .titles: titleFields
                case .people: personFields
                }

                Text("Seuls les champs modifiés sont appliqués. Les autres gardent leur valeur d'origine.")
                    .metaStyle()
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, Space.s2)
            }
        }
    }

    private var headline: String {
        selection.count == 1 ? "1 ligne" : "\(selection.count) lignes"
    }

    // MARK: Les champs des titres

    @ViewBuilder
    private var titleFields: some View {
        // **« valeurs multiples · ne pas toucher »** est l'état de repos, pas une option : un
        // champ qui n'a pas été touché n'entre pas dans la mutation.
        pendingRow("Note", isSet: rating != nil) {
            NumberFieldRow("Note", value: $rating, bounds: 0...10)
        } apply: {
            apply(.setRating(rating ?? 0))
        }

        pendingRow("Durée", isSet: runtime != nil) {
            // **`Double?` côté champ, `Int` côté modèle**, et la conversion est explicite :
            // `NumberFieldRow` est le champ numérique unique du système, et `runtimeMinutes`
            // est un entier. Arrondir plutôt que tronquer — saisir « 155,6 » doit donner 156,
            // pas 155.
            NumberFieldRow("Durée (min)", value: $runtime)
        } apply: {
            apply(.setRuntime(Int((runtime ?? 0).rounded())))
        }

        pendingRow("Genres · ajouter à toutes", isSet: !genreNames.isEmpty) {
            TokenFieldRow(
                "Genres", values: $genreNames,
                suggestions: genres.filter { $0.target == .title }.map(\.name))
        } apply: {
            apply(TitleBulkMutation.addGenres(resolvedGenreIDs(target: .title)))
        }

        toggleRow("Privé", value: $isPrivate) { apply(TitleBulkMutation.setPrivate($0)) }
        toggleRow("Archivé", value: $isArchived) { apply(TitleBulkMutation.setArchived($0)) }
    }

    @ViewBuilder
    private var personFields: some View {
        pendingRow("Genres · ajouter à toutes", isSet: !genreNames.isEmpty) {
            TokenFieldRow(
                "Genres", values: $genreNames,
                suggestions: genres.filter { $0.target == .person }.map(\.name))
        } apply: {
            apply(PersonBulkMutation.addGenres(resolvedGenreIDs(target: .person)))
        }

        toggleRow("Privé", value: $isPrivate) { apply(PersonBulkMutation.setPrivate($0)) }
        toggleRow("Archivé", value: $isArchived) { apply(PersonBulkMutation.setArchived($0)) }
    }

    // MARK: La forme d'un champ en attente

    /// Un champ, et le bouton qui l'applique **à lui seul**.
    ///
    /// Le bouton est inerte tant que le champ n'a pas été renseigné : appliquer « rien » à
    /// cinq lignes est un lot vide qui encombrerait le fil sans rien changer.
    @ViewBuilder
    private func pendingRow(
        _ label: String,
        isSet: Bool,
        @ViewBuilder field: () -> some View,
        apply: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(label)
                .labelStyle()
                .foregroundStyle(Color.textTertiary)
            field()
            Button("Appliquer aux \(selection.count)", action: apply)
                .buttonStyle(ActionButtonStyle(rank: .secondary))
                .disabled(!isSet)
        }
    }

    /// Une bascule à **trois** états : ne pas toucher, poser vrai, poser faux.
    ///
    /// **Un `Bool?` et non un `Bool`.** Une bascule à deux états n'a pas de position « ne pas
    /// toucher » : elle affiche forcément vrai ou faux, donc « Appliquer » écrirait toujours
    /// quelque chose — et un utilisateur qui ne voulait changer que la note passerait
    /// silencieusement cinq titres en « non privé ».
    @ViewBuilder
    private func toggleRow(
        _ label: String, value: Binding<Bool?>, apply: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: Space.s3) {
            Text(label)
                .calloutStyle()
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: Space.s3)
            Button("Oui") { apply(true) }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
            Button("Non") { apply(false) }
                .buttonStyle(ActionButtonStyle(rank: .secondary))
        }
        .frame(minHeight: Space.minHitTarget)
    }

    // MARK: L'application

    private func resolvedGenreIDs(target: GenreTarget) -> [UUID] {
        guard let library = session.current?.library else { return [] }
        let repository = GenreRepository(context: modelContext)
        return genreNames.compactMap {
            try? repository.findOrCreate(name: $0, target: target, in: library).id
        }
    }

    private func apply(_ mutation: TitleBulkMutation) {
        run { editor in
            try editor.apply(mutation, toTitles: Array(selection), summary: summary(for: mutation))
        }
    }

    private func apply(_ mutation: PersonBulkMutation) {
        run { editor in
            try editor.apply(mutation, toPeople: Array(selection), summary: summary(for: mutation))
        }
    }

    /// **Le résumé est fourni par l'écran**, et `BulkEditor` l'exige : lui seul connaît le
    /// libellé de la valeur choisie dans son interface. C'est cette ligne que le fil affichera,
    /// et que l'annulation reprendra en « Annulé : … ».
    private func summary(for mutation: TitleBulkMutation) -> String {
        "\(selection.count) titres · \(mutation.field)"
    }

    private func summary(for mutation: PersonBulkMutation) -> String {
        "\(selection.count) personnes · \(mutation.field)"
    }

    private func run(_ body: (BulkEditor) throws -> BulkEditOutcome) {
        do {
            let outcome = try body(BulkEditor(isolatedContext: modelContext))
            switch outcome {
            case .applied(let count, let activityID):
                onApplied(activityID, count)
                reset()
            case .refused(let refusals):
                onRefused(BulkEditPanel.refusalMessage(refusals))
            }
        } catch {
            onRefused("La modification a échoué.")
        }
    }

    /// Les champs repartent à « ne pas toucher » après application : les laisser remplis
    /// inviterait à recliquer « Appliquer », donc à créer un second lot identique.
    private func reset() {
        rating = nil
        runtime = nil
        genreNames = []
        isPrivate = nil
        isArchived = nil
    }

    static func refusalMessage(_ refusals: [BulkRefusal]) -> String {
        let count = refusals.count
        let lines = count == 1 ? "1 ligne" : "\(count) lignes"
        return "Refusé sur \(lines). Rien n'a été modifié."
    }
}
