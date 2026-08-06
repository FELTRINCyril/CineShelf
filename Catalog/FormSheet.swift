import DesignSystem
import SwiftUI

// Les neuf composants de `I7` + `I8` + `I9`, aux deux crans de densité — le même jeu de champs
// en dense et en ample, comme le §6 du handoff le demande.
//
// Ce qu'on vient vérifier ici, et qu'aucun test ne montre :
//
// - que les quatre marques d'erreur y sont **toutes les quatre**, et jamais une cinquième ;
// - qu'un champ **requis vide** reste neutre — c'est la règle du bloc `11a`, et c'est celle
//   qu'on enfreint sans y penser en peignant tout requis en rouge ;
// - qu'un champ valide au repos **ne se signale pas** : ni coche, ni liseré vert ;
// - que la date à précision variable montre un, deux ou trois champs selon son cran ;
// - que la couleur retenue se voit **sans ambre** — la sélection ne peut pas se signaler par
//   une couleur quand la couleur est ce qu'on choisit.

struct FormSheet: View {
    @State private var title = "Dune"
    @State private var summary = "Un duc et son fils héritent d'une planète désertique."
    @State private var rating: Double? = 4.5
    @State private var isPrivate = false
    @State private var kind = Kind.movie
    @State private var released = PrecisionDate(year: 2021, month: 9, precision: .month)
    @State private var genres = ["Drame", "Science-fiction"]
    @State private var colour = ProfileColor.amber

    private enum Kind: String, Identifiable, CaseIterable {
        case movie, series, documentary
        var id: String { rawValue }
        var title: String {
            switch self {
            case .movie: "Film"
            case .series: "Série"
            case .documentary: "Documentaire"
            }
        }
    }

    var body: some View {
        Sheet(
            "Champs de formulaire · I7 · I8 · I9",
            note: """
                Les trois lots ensemble : ils partagent la même anatomie — libellé en \
                capitales, fond `bg.fill`, trait d'accent au focus, quatre marques d'erreur. \
                Rendus aux deux crans, parce que la hauteur de champ en dépend (28 et 38 pt).
                """
        ) {
            VStack(alignment: .leading, spacing: Space.s6) {
                densities
                errors
                dates
                selectors
            }
        }
    }

    private var densities: some View {
        section("Le même jeu, aux deux densités") {
            HStack(alignment: .top, spacing: Space.s5) {
                ForEach([Density.dense, .roomy], id: \.self) { density in
                    VStack(alignment: .leading, spacing: density.formSpacing) {
                        Text(verbatim: density == .dense ? "dense · champ 28" : "ample · champ 38")
                            .font(Typo.micro)
                            .foregroundStyle(.textTertiary)
                        TextFieldRow("Titre", text: $title, isRequired: true)
                        NumberFieldRow("Note", value: $rating, bounds: 0...10)
                        SelectRow(
                            "Type", selection: $kind, options: Kind.allCases, title: \.title)
                        ToggleRow("Privé", note: "Masqué des profils qui filtrent", isOn: $isPrivate)
                    }
                    .environment(\.density, density)
                    .frame(width: 300)
                    .padding(Space.s4)
                    .background(.bgSurface)
                }
            }
        }
    }

    private var errors: some View {
        section("Les quatre cas d'erreur, et les deux non-erreurs") {
            VStack(alignment: .leading, spacing: Space.s4) {
                VStack(alignment: .leading, spacing: Space.s3) {
                    TextFieldRow(
                        "Format invalide", text: .constant("mille neuf cent"),
                        error: FieldError("Utilise quatre chiffres, comme 2021."))
                    TextFieldRow(
                        "Requis vide", text: .constant(""),
                        error: FieldError("Donne un titre : c'est ce qui identifie la fiche."))
                    NumberFieldRow("Hors bornes", value: .constant(99), bounds: 0...10)
                    TextFieldRow(
                        "Valeur refusée", text: .constant("Démonstration"),
                        error: FieldError("Ce nom est réservé aux données de démonstration."))
                    // Les deux qui ne doivent **rien** montrer.
                    TextFieldRow("Requis, encore vide", text: .constant(""), isRequired: true)
                    TextFieldRow("Valide au repos", text: .constant("Nomadland"))
                }
                .frame(width: 380)
                .padding(Space.s4)
                .background(.bgSurface)

                ValidationSummary(
                    "Trois champs à corriger",
                    fields: [
                        .init(id: "1", label: "Titre", focus: {}),
                        .init(id: "2", label: "Année", focus: {}),
                        .init(id: "3", label: "Note", focus: {})
                    ]
                )
                .frame(width: 380)
                BlockNote(.fieldShell)
            }
        }
    }

    private var dates: some View {
        section("Date à précision variable · un, deux ou trois champs") {
            VStack(alignment: .leading, spacing: Space.s3) {
                PrecisionDateRow(
                    "Année seule", date: .constant(PrecisionDate(year: 1974, precision: .year)))
                PrecisionDateRow("Mois", date: $released)
                PrecisionDateRow(
                    "Jour",
                    date: .constant(PrecisionDate(year: 2023, month: 7, day: 21, precision: .day)))
                PrecisionDateRow(
                    "Jour impossible",
                    date: .constant(PrecisionDate(year: 2023, month: 2, day: 31, precision: .day)),
                    error: FieldError("Février 2023 compte 28 jours."))
                BlockNote(.precisionDate)
            }
            .frame(width: 380)
        }
    }

    private var selectors: some View {
        section("Multi-sélecteur et couleur de profil") {
            VStack(alignment: .leading, spacing: Space.s5) {
                TokenFieldRow(
                    "Genres", values: $genres,
                    suggestions: ["Policier", "Poésie"],
                    createLabel: { "Créer « \($0) »" })
                ProfileColorPicker("Couleur du profil", selection: $colour)
                BlockNote(.tokenField)
            }
            .frame(width: 380)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title).font(Typo.title2(.large)).foregroundStyle(.textPrimary)
            content()
        }
    }
}
