import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Les filtres de la liste des personnes — planche 3 bloc `4c`.
///
/// Le bloc en nomme trois : « Réalisation · Interprétation · Tranche d'âge ». Le genre s'y
/// ajoute parce que `PersonFilter` le porte depuis `L2` et que les personnes ont bel et bien
/// des genres — le prototype ne montre que trois jetons, ce qui est une place disponible, pas
/// une liste fermée.
struct PersonFilterSheet: View {
    @Binding var filter: PersonFilter

    @Environment(\.dismiss) private var dismiss

    @Query(filter: GenreQuery.living, sort: \Genre.name) private var genres: [Genre]

    var body: some View {
        NavigationStack {
            Form {
                Section("Rôle") {
                    Picker("Rôle", selection: $filter.role) {
                        Text("Tous").tag(PersonRole?.none)
                        // L'ordre du bloc `4c` : la réalisation d'abord, l'interprétation
                        // ensuite. Pas l'ordre de déclaration de l'énumération, qui commence
                        // par `actor` parce que c'est le rôle par défaut d'une création.
                        ForEach(orderedRoles, id: \.self) { role in
                            Text(label(for: role)).tag(PersonRole?.some(role))
                        }
                    }
                }

                Section("Tranche d'âge") {
                    Picker("Tranche", selection: $filter.ageBand) {
                        Text("Toutes").tag(AgeBand?.none)
                        ForEach(AgeBand.allCases) { band in
                            Text(band.label).tag(AgeBand?.some(band))
                        }
                    }
                    // Ce que la tranche recouvre réellement, et qui n'est pas devinable : un
                    // défunt est classé sur son âge à la mort, pas sur celui qu'il aurait.
                    Text("Les personnes décédées sont classées sur leur âge au décès.")
                        .font(Typo.caption)
                        .foregroundStyle(.textTertiary)
                }

                Section("Genre") {
                    Picker("Genre", selection: $filter.genreID) {
                        Text("Tous").tag(UUID?.none)
                        ForEach(personGenres) { genre in
                            Text(genre.name).tag(UUID?.some(genre.id))
                        }
                    }
                }

                Section {
                    Toggle("Afficher les personnes archivées", isOn: $filter.showsArchived)
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

    /// Les genres ciblant les **personnes**. `Genre` sert aussi aux titres et aux signets :
    /// proposer ceux des titres ici ne filtrerait jamais rien.
    private var personGenres: [Genre] {
        genres.filter { $0.target == .person && !$0.isArchived }
    }

    /// L'ordre du bloc `4c` : la réalisation d'abord, l'interprétation ensuite. Pas l'ordre de
    /// déclaration de l'énumération, qui commence par `actor` parce que c'est le rôle par
    /// défaut d'une création.
    private var orderedRoles: [PersonRole] { [.director, .actor, .writer, .crew, .social] }

    private func label(for role: PersonRole) -> String {
        switch role {
        case .actor: "Interprétation"
        case .director: "Réalisation"
        case .writer: "Écriture"
        case .crew: "Équipe"
        case .social: "Compte"
        }
    }
}
