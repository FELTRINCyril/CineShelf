import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// L'éditeur d'un titre — feuille sur iOS, contenu de l'inspecteur sur Mac.
///
/// Écrit dans un brouillon local, pas directement dans le `@Model` : une saisie
/// en cours ne doit pas partir sur iCloud à chaque frappe, et « Annuler » doit
/// pouvoir annuler. La validation part au `TitleRepository`, qui rafraîchit les
/// dérivés — `docs/04` §3.
struct TitleEditor: View {
    let title: Title

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Draft
    @State private var isInspector: Bool

    init(title: Title, isInspector: Bool = false) {
        self.title = title
        _draft = State(initialValue: Draft(title))
        _isInspector = State(initialValue: isInspector)
    }

    var body: some View {
        if isInspector {
            form
        } else {
            NavigationStack {
                form
                    .navigationTitle(title.name.isEmpty ? "Nouveau titre" : "Modifier")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annuler") { cancel() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Enregistrer") { save() }
                                .disabled(!draft.isValid)
                        }
                    }
            }
            #if os(macOS)
                .frame(minWidth: 460, minHeight: 520)
            #endif
        }
    }

    private var form: some View {
        Form {
            Section("Identité") {
                FieldRow("Titre", validation: draft.nameValidation) {
                    TextField("Titre", text: $draft.name)
                }
                FieldRow("Titre original") {
                    TextField("Titre original", text: $draft.originalName)
                }
                Picker("Type", selection: $draft.kind) {
                    ForEach(TitleKind.allCases, id: \.self) { kind in
                        Text(kindLabel(kind)).tag(kind)
                    }
                }
            }

            Section("Détails") {
                FieldRow("Année") {
                    TextField("Année", value: $draft.year, format: .number.grouping(.never))
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                }
                FieldRow("Durée (minutes)") {
                    TextField("Durée", value: $draft.runtimeMinutes, format: .number)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                }
                FieldRow("Note sur 10", validation: draft.ratingValidation) {
                    TextField("Note", value: $draft.rating, format: .number.precision(.fractionLength(0...1)))
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                }
            }

            Section("Résumé") {
                TextField("Résumé", text: $draft.summary, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Toggle("Privé", isOn: $draft.isPrivate)
                Toggle("Archivé", isOn: $draft.isArchived)
            }

            if isInspector {
                Section {
                    Button("Enregistrer") { save() }
                        .disabled(!draft.isValid)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Enregistrement

    private func save() {
        TitleRepository(context: modelContext).update(title) { draft.apply(to: $0) }
        if !isInspector { dismiss() }
    }

    /// Un titre créé puis abandonné n'a rien à faire dans la bibliothèque : on
    /// le met à la corbeille plutôt que de laisser une fiche sans nom.
    private func cancel() {
        if title.name.isEmpty {
            TitleRepository(context: modelContext).softDelete(title)
        }
        dismiss()
    }

    private func kindLabel(_ kind: TitleKind) -> String {
        switch kind {
        case .movie: "Film"
        case .series: "Série"
        case .documentary: "Documentaire"
        case .short: "Court métrage"
        case .other: "Autre"
        }
    }
}

// MARK: - Brouillon

extension TitleEditor {

    /// L'état de saisie, détaché du modèle.
    struct Draft {
        var name: String
        var originalName: String
        var summary: String
        var kind: TitleKind
        var year: Int?
        var runtimeMinutes: Int?
        var rating: Double?
        var isPrivate: Bool
        var isArchived: Bool

        /// La date d'origine et sa précision, conservées telles quelles.
        ///
        /// L'éditeur ne saisit qu'une année : réécrire `releaseDate` à chaque
        /// enregistrement dégraderait au 1er janvier une date connue au jour
        /// près, et cela pour une modification qui ne la concerne même pas.
        private let originalReleaseDate: Date?
        private let originalPrecision: String

        init(_ title: Title) {
            originalReleaseDate = title.releaseDate
            originalPrecision = title.releasePrecisionRaw
            name = title.name
            originalName = title.originalName ?? ""
            summary = title.summary ?? ""
            kind = title.kind
            year = title.releaseYear
            runtimeMinutes = title.runtimeMinutes
            rating = title.rating
            isPrivate = title.isPrivate
            isArchived = title.isArchived
        }

        var nameValidation: FieldValidation? {
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .error("Un titre ne peut pas être vide.") : nil
        }

        var ratingValidation: FieldValidation? {
            guard let rating else { return nil }
            return (0...10).contains(rating) ? nil : .error("La note va de 0 à 10.")
        }

        var isValid: Bool { nameValidation == nil && ratingValidation == nil }

        func apply(to title: Title) {
            title.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            title.originalName = originalName.isEmpty ? nil : originalName
            title.summary = summary.isEmpty ? nil : summary
            title.kindRaw = kind.rawValue
            title.runtimeMinutes = runtimeMinutes
            title.rating = rating
            title.isPrivate = isPrivate
            title.isArchived = isArchived

            applyReleaseDate(to: title)
        }

        /// N'écrit la date que si l'année a réellement changé.
        private func applyReleaseDate(to title: Title) {
            let originalYear = Calendar(identifier: .gregorian)
                .dateComponents([.year], from: originalReleaseDate ?? .distantPast).year

            guard year != (originalReleaseDate == nil ? nil : originalYear) else {
                // Année inchangée : on remet la date d'origine intacte, jour et
                // précision compris.
                title.releaseDate = originalReleaseDate
                title.releasePrecisionRaw = originalPrecision
                return
            }

            guard let year else {
                title.releaseDate = nil
                title.releasePrecisionRaw = DatePrecision.year.rawValue
                return
            }

            // Nouvelle année saisie : on la range au 1er janvier et on note que
            // la précision s'arrête là, plutôt que d'inventer un jour.
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            title.releaseDate = Calendar(identifier: .gregorian).date(from: components)
            title.releasePrecisionRaw = DatePrecision.year.rawValue
        }
    }
}
