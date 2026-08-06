import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V4 · L'éditeur de personne
//
// **Le premier écran écrit avec les champs de `I7`–`I9`.** `TitleEditor` porte encore
// l'ancienne direction — il est le dernier fichier de `Features/Titles` dans la liste
// d'exclusion `no_legacy_design_system` —, donc `PrecisionDateRow`, `TokenFieldRow` et
// `ValidationSummary` n'avaient jusqu'ici **aucun appelant de production**. Les composants
// existaient, leur planche du catalogue passait, et rien ne les avait branchés sur un modèle.
//
// **Ce que le branchement a révélé** : aucune conversion `PrecisionDate` ↔ `Date` n'existait.
// Elle est écrite ici, dans l'app, parce qu'elle traduit entre un modèle et un composant —
// `DesignSystem` ne connaît pas `Person`, et `CineShelfCore` ne connaît pas `PrecisionDate`.
//
// **Le refus suit le bloc `11c`** : rien n'est fermé, rien n'est perdu, aucune valeur remise à
// zéro. Le récapitulatif se pose en tête du formulaire — dans le contenu, pas en notification.

struct PersonEditor: View {
    let person: Person

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: GenreQuery.living, sort: \Genre.name) private var genres: [Genre]

    @State private var draft: Draft
    @State private var hasAttemptedSave = false

    init(person: Person) {
        self.person = person
        _draft = State(initialValue: Draft(person))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    if hasAttemptedSave, !refusals.isEmpty {
                        ValidationSummary(
                            "Corrige ces champs pour enregistrer",
                            fields: refusals.map { refusal in
                                .init(id: refusal.id, label: refusal.label) {}
                            })
                    }

                    TextFieldRow(
                        "Prénom", text: $draft.firstName, prompt: "Cillian",
                        error: error(for: "firstName"))
                    TextFieldRow("Nom", text: $draft.lastName, prompt: "Murphy")

                    PrecisionDateRow(
                        "Naissance", date: $draft.birth, error: error(for: "birth"))
                    PrecisionDateRow("Décès", date: $draft.death, error: error(for: "death"))

                    TextAreaRow("Biographie", text: $draft.bio)

                    TokenFieldRow(
                        "Rôles", values: $draft.roleLabels,
                        suggestions: roleSuggestions,
                        error: error(for: "roles"))

                    TokenFieldRow(
                        "Genres", values: $draft.genreNames,
                        suggestions: genreSuggestions,
                        createLabel: { typed in "Créer le genre « \(typed) »" })

                    ToggleRow(
                        "Privé", note: "Masqué des profils invités et de Spotlight",
                        isOn: $draft.isPrivate)
                    ToggleRow("Archivé", isOn: $draft.isArchived)
                }
                .padding(Space.s5)
            }
            .background(Color.bgCanvas)
            .navigationTitle(person.displayName.isEmpty ? "Nouvelle personne" : "Modifier")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        // Le bloc `11c` : « Enregistrer devient inerte jusqu'à correction du
                        // dernier champ » — mais **seulement après une tentative**. Un bouton
                        // gris à l'ouverture d'un formulaire vierge n'apprend rien.
                        .disabled(hasAttemptedSave && !refusals.isEmpty)
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    // MARK: Le brouillon
    //
    // **On édite une copie, pas l'objet.** Écrire directement dans le `Person` rendrait
    // « Annuler » impossible : SwiftData a déjà la valeur, et la feuille fermée par
    // glissement l'aurait gardée.

    private struct Draft {
        var firstName: String
        var lastName: String
        var birth: PrecisionDate
        var death: PrecisionDate
        var bio: String
        var roleLabels: [String]
        var genreNames: [String]
        var isPrivate: Bool
        var isArchived: Bool

        init(_ person: Person) {
            firstName = person.firstName
            lastName = person.lastName
            birth = PrecisionDate(person.birthDate)
            death = PrecisionDate(person.deathDate)
            bio = person.bio ?? ""
            roleLabels = [PersonRole.actor, .director, .writer, .crew, .social]
                .filter(person.roles.contains)
                .map(PersonFormat.label(for:))
            genreNames = (person.genres ?? [])
                .filter { $0.deletedAt == nil }
                .map(\.name)
                .sorted()
            isPrivate = person.isPrivate
            isArchived = person.isArchived
        }
    }

    // MARK: Le refus

    private struct Refusal {
        let id: String
        let label: LocalizedStringKey
        let guidance: LocalizedStringKey
    }

    /// Ce qui empêche d'enregistrer. **Le message dit quoi faire, jamais ce qui est faux** —
    /// c'est la règle du bloc `11a`.
    private var refusals: [Refusal] {
        var found: [Refusal] = []
        let named = !(draft.firstName + draft.lastName)
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !named {
            found.append(
                .init(
                    id: "firstName", label: "Prénom",
                    guidance: "Donne au moins un prénom ou un nom."))
        }
        if !draft.birth.isEmptyDate, !draft.birth.isValidCalendarDate {
            found.append(
                .init(id: "birth", label: "Naissance", guidance: "Cette date n'existe pas."))
        }
        if !draft.death.isEmptyDate, !draft.death.isValidCalendarDate {
            found.append(
                .init(id: "death", label: "Décès", guidance: "Cette date n'existe pas."))
        }
        // Un décès avant la naissance : le seul contrôle croisé, et il attrape une inversion
        // de saisie que chaque champ pris isolément trouve parfaitement valide.
        if let birth = draft.birth.date, let death = draft.death.date, death < birth {
            found.append(
                .init(
                    id: "death", label: "Décès",
                    guidance: "Le décès ne peut pas précéder la naissance."))
        }
        if draft.roleLabels.isEmpty {
            found.append(
                .init(id: "roles", label: "Rôles", guidance: "Choisis au moins un rôle."))
        }
        return found
    }

    private func error(for id: String) -> FieldError? {
        guard hasAttemptedSave, let refusal = refusals.first(where: { $0.id == id }) else {
            return nil
        }
        return FieldError(refusal.guidance)
    }

    // MARK: Suggestions

    private var roleSuggestions: [String] {
        [PersonRole.actor, .director, .writer, .crew, .social].map(PersonFormat.label(for:))
    }

    /// Les genres ciblant les personnes, et **eux seuls**.
    ///
    /// L'arbitrage tranché point 2 : la frappe qui correspond à un `nameKey` connu doit dire
    /// « genre existant » et non « créer ». C'est ce que fait `TokenFieldRow` en proposant
    /// d'abord ses suggestions — la création n'apparaît que si rien ne correspond.
    private var genreSuggestions: [String] {
        genres.filter { $0.target == .person && !$0.isArchived }.map(\.name)
    }

    // MARK: L'enregistrement

    private func save() {
        hasAttemptedSave = true
        guard refusals.isEmpty else { return }
        guard let library = person.library else { return }

        // **Les genres se résolvent avant l'écriture.** `findOrCreate` peut en créer, donc le
        // faire au milieu de la mutation mélangerait deux écritures dans une seule entrée de
        // journal — « personne modifiée » masquerait « genre créé ».
        let genreRepository = GenreRepository(context: modelContext)
        let resolved = draft.genreNames.compactMap {
            try? genreRepository.findOrCreate(name: $0, target: .person, in: library)
        }

        let repository = PersonRepository(context: modelContext)
        repository.update(person, journal: .perEntity) { person in
            person.firstName = draft.firstName
            person.lastName = draft.lastName
            person.birthDate = draft.birth.date
            person.deathDate = draft.death.date
            person.bio = draft.bio.isEmpty ? nil : draft.bio
            person.roles = Set(draft.roleLabels.compactMap(role(named:)))
            person.isPrivate = draft.isPrivate
            // Le bloc `8b` : « archivé désactivé tant que le titre est privé ». La même règle
            // vaut ici — un contenu privé est déjà hors des listes.
            person.isArchived = draft.isPrivate ? false : draft.isArchived
        }

        // **Les genres passent par le mutateur de relation**, jamais par `person.genres` :
        // écrire la relation depuis une vue rendrait `filterKeys` faux en silence, et la règle
        // `no_relation_write_outside_core` le refuse à la compilation.
        //
        // `.batched` et non `.perEntity` : l'écriture ci-dessus a déjà journalisé cette
        // modification. Deux entrées pour un seul « Enregistrer » diraient une histoire fausse
        // dans le fil de `V5b`.
        repository.setGenres(resolved, on: person, journal: .batched)

        dismiss()
    }

    private func role(named label: String) -> PersonRole? {
        [PersonRole.actor, .director, .writer, .crew, .social]
            .first { PersonFormat.label(for: $0) == label }
    }
}

// MARK: - La conversion qui manquait

extension PrecisionDate {

    /// Depuis une `Date` du modèle, au cran « jour ».
    ///
    /// **Une date de naissance n'a pas de précision variable dans notre schéma** : `Person`
    /// porte un `Date?` nu, là où `Title` porte une `datePrecision`. Le composant sait rendre
    /// les trois crans ; ici il n'en sert qu'un, et forcer le cran plutôt que d'inventer un
    /// champ est la bonne moitié du compromis — le schéma est fermé.
    init(_ date: Date?) {
        guard let date else {
            self.init(precision: .day)
            return
        }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year, month: parts.month, day: parts.day, precision: .day)
    }

    /// Vers une `Date`, ou `nil` si la saisie est incomplète ou impossible.
    ///
    /// **`Calendar.date(from:)` ne suffit pas** : il *reporte* un 31 février au 3 mars au lieu
    /// de refuser. On revalide donc les composantes obtenues contre celles saisies — c'est ce
    /// qui distingue « date inexistante » de « date valide », et le bloc `11b` demande un
    /// message pour le premier cas.
    var date: Date? {
        guard let year, let month, let day else { return nil }
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        guard let candidate = Calendar.current.date(from: parts) else { return nil }
        let round = Calendar.current.dateComponents([.year, .month, .day], from: candidate)
        guard round.year == year, round.month == month, round.day == day else { return nil }
        return candidate
    }

    /// Aucun champ saisi — l'utilisateur n'a pas renseigné la date, ce qui est permis.
    var isEmptyDate: Bool { year == nil && month == nil && day == nil }

    /// La saisie désigne-t-elle un jour qui existe ?
    var isValidCalendarDate: Bool { date != nil }
}
