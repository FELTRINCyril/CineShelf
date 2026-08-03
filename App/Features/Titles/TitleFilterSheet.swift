import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Les filtres de la liste des titres — `docs/03` §4.
///
/// `FilterBar` du design system est purement catégoriel : des jetons oui/non.
/// Il ne sait pas exprimer une plage numérique, une tranche de durée ni une
/// bascule « archivés ». Plutôt que d'élargir un composant partagé pour un seul
/// appelant, cette feuille est écrite ici, avec les mêmes tokens.
struct TitleFilterSheet: View {
    @Binding var filter: TitleFilter

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TitleCollection.name) private var collections: [TitleCollection]
    @Query(filter: GenreQuery.living, sort: \Genre.name)
    private var genres: [Genre]

    var body: some View {
        NavigationStack {
            Form {
                Section("Durée") {
                    Picker("Tranche", selection: $filter.runtimeBand) {
                        Text("Toutes").tag(RuntimeBand?.none)
                        ForEach(RuntimeBand.allCases) { band in
                            Text(band.label).tag(RuntimeBand?.some(band))
                        }
                    }

                    // Les bornes libres restent visibles mais inactives quand une
                    // tranche est choisie : c'est plus clair que de les cacher,
                    // qui laisserait croire qu'elles n'existent pas.
                    minuteField("Minimum", value: $filter.minimumRuntime)
                    minuteField("Maximum", value: $filter.maximumRuntime)
                }

                Section("Note") {
                    ratingField("Au moins", value: $filter.minimumRating)
                    ratingField("Au plus", value: $filter.maximumRating)
                    Text("Sur 10, comme la note du catalogue.")
                        .font(Typo.caption)
                        .foregroundStyle(.textTertiary)
                }

                Section("Classement") {
                    Picker("Collection", selection: $filter.collectionID) {
                        Text("Toutes").tag(UUID?.none)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(UUID?.some(collection.id))
                        }
                    }

                    Picker("Genre", selection: $filter.genreID) {
                        Text("Tous").tag(UUID?.none)
                        ForEach(titleGenres) { genre in
                            Text(genre.name).tag(UUID?.some(genre.id))
                        }
                    }
                }

                Section {
                    Toggle("Afficher les titres archivés", isOn: $filter.showsArchived)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Filtres")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tout effacer") { filter.clear() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    /// Les genres ciblant les titres : `Genre` sert aussi aux personnes et aux
    /// signets, les mélanger ici n'aurait aucun sens.
    private var titleGenres: [Genre] {
        // La corbeille est déjà écartée par le `@Query` ; reste l'archivage,
        // qui masque sans supprimer.
        genres.filter { genre in
            guard genre.target == .title, !genre.isArchived else { return false }
            #if DEBUG
                // Le marqueur des données de démonstration n'est pas un genre.
                if genre.name == DemoCatalog.markerGenreName { return false }
            #endif
            return true
        }
    }

    private func minuteField(_ label: String, value: Binding<Int?>) -> some View {
        LabeledContent(label) {
            TextField(
                "—",
                value: value,
                format: .number.precision(.fractionLength(0))
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 96)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
        }
        .disabled(filter.runtimeBand != nil)
    }

    private func ratingField(_ label: String, value: Binding<Double?>) -> some View {
        LabeledContent(label) {
            TextField("—", value: value, format: .number.precision(.fractionLength(0...1)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 96)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
        }
    }
}
