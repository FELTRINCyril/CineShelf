import SwiftUI

// MARK: - I8 · La date à précision variable
//
// **Trois crans — année, mois, jour — et c'est une fonctionnalité du modèle, pas un confort de
// saisie.** `docs/02` la porte en champ dédié, et le §6 du handoff l'écrit noir sur blanc :
// « date à précision variable (**trois crans : année, mois, jour**) ».
//
// La raison est dans les données : un film sorti « en 1974 » n'a pas une date inconnue, il a
// une **date à l'année**. Enregistrer le 1er janvier 1974 et l'afficher comme tel serait
// inventer une précision que personne n'a saisie — et la trier, la filtrer et l'exporter comme
// si elle était vraie.
//
// **Ce composant ne connaît pas `Date`**, et c'est délibéré : il rend trois champs et une
// précision. La conversion vers le modèle appartient à l'écran, qui seul sait dans quel fuseau
// et sous quelle forme la ranger — `TitleQuery.living(sortName:year:)` a déjà payé le prix
// d'un fuseau mal choisi.

/// La précision d'une date saisie.
///
/// **`DateFieldPrecision` et non `DatePrecision`, et le compilateur l'a imposé.** Le modèle
/// porte déjà un `DatePrecision` — il est **persisté**, dans `Title.releasePrecisionRaw` —, et
/// `CineShelfCore` n'a pas le droit d'importer `DesignSystem` ni l'inverse : le double est donc
/// inévitable, comme `CardLayout` / `DisplayLayout`. Ce qui ne l'est pas, c'est le même nom :
/// un fichier qui importe les deux paquets ne compile plus, et le message — « ambiguous use of
/// `year` » — ne nomme ni l'un ni l'autre. `TitleEditor` a cessé de compiler à la seconde où
/// ce type est né.
///
/// Les `rawValue` doivent rester accordés, sinon la précision saisie ne se relit pas. C'est
/// `DisplayVocabularyTests` qui l'affirme, seul endroit du dépôt qui voie les deux paquets.
public enum DateFieldPrecision: String, CaseIterable, Identifiable, Sendable, Codable {
    case year, month, day

    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .year: "Année"
        case .month: "Mois"
        case .day: "Jour"
        }
    }

    /// Combien de champs la précision demande. C'est ce que la vue lit, et ça se teste.
    public var fieldCount: Int {
        switch self {
        case .year: 1
        case .month: 2
        case .day: 3
        }
    }
}

/// Ce qu'une date à précision variable porte réellement.
public struct PrecisionDate: Equatable, Sendable {
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var precision: DateFieldPrecision

    public init(year: Int? = nil, month: Int? = nil, day: Int? = nil, precision: DateFieldPrecision = .year) {
        self.year = year
        self.month = month
        self.day = day
        self.precision = precision
    }

    /// Les bornes de chaque cran. **Le jour n'est pas borné au mois** : 31 partout.
    ///
    /// Un 31 février saisi doit être **refusé par l'écran**, avec le message que le bloc `11b`
    /// demande — pas rendu impossible à taper. Un champ qui refuse la frappe ne dit pas
    /// pourquoi, et c'est ce que l'anatomie d'erreur existe pour éviter.
    public static let yearBounds = 1_870...2_100
    public static let monthBounds = 1...12
    public static let dayBounds = 1...31

    /// La date est-elle complète pour sa précision ?
    public var isComplete: Bool {
        switch precision {
        case .year: year != nil
        case .month: year != nil && month != nil
        case .day: year != nil && month != nil && day != nil
        }
    }
}

/// Trois champs et un sélecteur de précision, sur une ligne.
public struct PrecisionDateRow: View {
    private let label: LocalizedStringKey
    @Binding private var date: PrecisionDate
    private let error: FieldError?

    public init(_ label: LocalizedStringKey, date: Binding<PrecisionDate>, error: FieldError? = nil) {
        self.label = label
        _date = date
        self.error = error
    }

    public var body: some View {
        FieldShell(label, error: error) {
            HStack(spacing: Space.s2) {
                part($date.year, prompt: "Année", width: 56)
                if date.precision != .year {
                    part($date.month, prompt: "Mois", width: 44)
                }
                if date.precision == .day {
                    part($date.day, prompt: "Jour", width: 44)
                }
                Spacer(minLength: Space.s2)
                precisionMenu
            }
        }
    }

    private func part(_ value: Binding<Int?>, prompt: LocalizedStringKey, width: CGFloat) -> some View {
        TextField(prompt, value: value, format: .number.grouping(.never))
            .textFieldStyle(.plain)
            .font(Typo.numeric)
            .foregroundStyle(Color.textPrimary)
            .frame(width: width)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
    }

    /// **Changer de précision n'efface rien.** Repasser de « jour » à « année » garde le mois
    /// et le jour saisis : l'utilisateur qui se ravise deux fois ne doit pas retaper. Ce qui
    /// est *enregistré* est décidé par l'écran, à partir de `precision`.
    private var precisionMenu: some View {
        Menu {
            ForEach(DateFieldPrecision.allCases) { precision in
                Button(
                    action: { date.precision = precision },
                    label: { Text(precision.label) })
            }
        } label: {
            HStack(spacing: Space.s1) {
                Text(date.precision.label)
                    .font(Typo.micro)
                    .foregroundStyle(Color.textTertiary)
                Image(systemName: Icon.navigateForward)
                    .font(Typo.micro)
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(90))
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

#Preview("Date à précision variable · les trois crans") {
    @Previewable @State var year = PrecisionDate(year: 1974, precision: .year)
    @Previewable @State var month = PrecisionDate(year: 2021, month: 9, precision: .month)
    @Previewable @State var day = PrecisionDate(year: 2023, month: 7, day: 21, precision: .day)

    return VStack(alignment: .leading, spacing: Space.s4) {
        PrecisionDateRow("Sortie · année", date: $year)
        PrecisionDateRow("Sortie · mois", date: $month)
        PrecisionDateRow("Sortie · jour", date: $day)
        PrecisionDateRow(
            "Sortie refusée", date: .constant(PrecisionDate(year: 2023, month: 2, day: 31, precision: .day)),
            error: FieldError("Février 2023 compte 28 jours."))
    }
    .padding(Space.s6)
    .background(Color.bgCanvas)
}
