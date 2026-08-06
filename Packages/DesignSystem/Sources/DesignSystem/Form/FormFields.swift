import SwiftUI

// MARK: - I7 · Texte, zone de texte, nombre — et I8 · sélecteur, interrupteur
//
// Relevés sur la planche 6, blocs `8a` et `8b`. Les cinq partagent `FieldShell` : ce fichier
// ne porte que ce qui les distingue, c'est-à-dire **la saisie**, jamais la présentation.
//
// **Les chiffres sont en mono, le texte ne l'est pas**, et c'est relevé, pas décoré : le bloc
// `8a` met `IBM Plex Mono` sur l'année et la durée, `Archivo Narrow` sur le titre. La raison
// est la même que pour les compteurs de la console — un chiffre qui change de largeur en
// cours de frappe fait danser le champ.

/// Un champ de texte d'une ligne.
public struct TextFieldRow: View {
    private let label: LocalizedStringKey
    private let prompt: LocalizedStringKey
    @Binding private var text: String
    private let isRequired: Bool
    private let error: FieldError?

    @FocusState private var isFocused: Bool

    public init(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        prompt: LocalizedStringKey = "",
        isRequired: Bool = false,
        error: FieldError? = nil
    ) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.isRequired = isRequired
        self.error = error
    }

    public var body: some View {
        FieldShell(label, isRequired: isRequired, isFocused: isFocused, error: error) {
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .focused($isFocused)
        }
    }
}

/// Une zone de texte. Hauteur relevée : 74 pt en dense (bloc `8a`).
public struct TextAreaRow: View {
    private let label: LocalizedStringKey
    @Binding private var text: String
    private let error: FieldError?

    @FocusState private var isFocused: Bool
    @Environment(\.density) private var density

    public init(
        _ label: LocalizedStringKey, text: Binding<String>, error: FieldError? = nil
    ) {
        self.label = label
        _text = text
        self.error = error
    }

    public var body: some View {
        FieldShell(label, isFocused: isFocused, error: error) {
            TextEditor(text: $text)
                .font(Typo.body)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(height: density == .dense ? 74 : 96)
        }
    }
}

/// Un champ numérique. **Toujours en mono**, et borné par l'appelant.
///
/// `bounds` n'est pas décoratif : le bloc `11b` compte « hors bornes » parmi ses quatre cas
/// d'erreur, et il précise que celui-là se signale **immédiatement**, pas à la sortie du
/// champ. Le champ ne décide donc pas du message, mais il sait quand il est hors bornes.
public struct NumberFieldRow: View {
    private let label: LocalizedStringKey
    @Binding private var value: Double?
    private let bounds: ClosedRange<Double>?
    private let error: FieldError?

    @FocusState private var isFocused: Bool

    public init(
        _ label: LocalizedStringKey,
        value: Binding<Double?>,
        bounds: ClosedRange<Double>? = nil,
        error: FieldError? = nil
    ) {
        self.label = label
        _value = value
        self.bounds = bounds
        self.error = error
    }

    /// L'erreur affichée : celle de l'appelant, ou le dépassement de bornes que le champ voit
    /// lui-même. **L'appelant gagne** — il en sait plus que le champ.
    private var effectiveError: FieldError? {
        if let error { return error }
        guard let bounds, let value, !bounds.contains(value) else { return nil }
        return FieldError("Entre une valeur entre \(Int(bounds.lowerBound)) et \(Int(bounds.upperBound)).")
    }

    public var body: some View {
        FieldShell(label, isFocused: isFocused, error: effectiveError) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(Typo.numeric)
                .foregroundStyle(Color.textPrimary)
                .focused($isFocused)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
        }
    }
}

/// Un sélecteur à liste fermée. Bloc `8a` : le champ, la valeur, un chevron à droite.
///
/// **Un `Menu` et non un `Picker`**, et c'est le relevé qui tranche : un `Picker` de style
/// automatique rend un contrôle système — bordé, arrondi, gris — dans une direction qui n'a ni
/// bordure ni rayon. Le menu porte le dessin du champ et garde le comportement natif.
public struct SelectRow<Value: Hashable & Identifiable>: View {
    private let label: LocalizedStringKey
    @Binding private var selection: Value
    private let options: [Value]
    private let title: (Value) -> String
    private let error: FieldError?

    public init(
        _ label: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        title: @escaping (Value) -> String,
        error: FieldError? = nil
    ) {
        self.label = label
        _selection = selection
        self.options = options
        self.title = title
        self.error = error
    }

    public var body: some View {
        FieldShell(label, error: error) {
            Menu {
                ForEach(options) { option in
                    Button(title(option)) { selection = option }
                }
            } label: {
                HStack {
                    Text(title(selection))
                        .font(Typo.callout)
                        .foregroundStyle(Color.textPrimary)
                    Spacer(minLength: Space.s2)
                    Image(systemName: Icon.navigateForward)
                        .font(Typo.micro)
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(90))
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }
}

/// Un interrupteur, et son libellé **à gauche** — le bloc `8a` ne met jamais le libellé
/// au-dessus pour une bascule : elle tient sur une ligne.
public struct ToggleRow: View {
    private let label: LocalizedStringKey
    private let note: LocalizedStringKey?
    @Binding private var isOn: Bool

    public init(_ label: LocalizedStringKey, note: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.label = label
        self.note = note
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(label)
                    .font(Typo.callout)
                    .foregroundStyle(Color.textPrimary)
                if let note {
                    Text(note)
                        .font(Typo.micro)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Color.accent)
        .frame(minHeight: Space.minHitTarget)
    }
}

// MARK: - Previews

#Preview("Champs · dense et ample") {
    @Previewable @State var title = "Dune"
    @Previewable @State var summary = "Un duc et son fils héritent d'une planète désertique."
    @Previewable @State var rating: Double? = 4.5
    @Previewable @State var isPrivate = false

    return ScrollView {
        VStack(alignment: .leading, spacing: Space.s6) {
            ForEach([Density.dense, .roomy], id: \.self) { density in
                VStack(alignment: .leading, spacing: density.formSpacing) {
                    TextFieldRow("Titre", text: $title, isRequired: true)
                    TextAreaRow("Synopsis", text: $summary)
                    NumberFieldRow("Note", value: $rating, bounds: 0...10)
                    NumberFieldRow(
                        "Note hors bornes", value: .constant(99), bounds: 0...10)
                    TextFieldRow(
                        "Année", text: .constant("mille"),
                        error: FieldError("Utilise quatre chiffres, comme 2021."))
                    ToggleRow("Privé", note: "Masqué des profils qui filtrent le privé", isOn: $isPrivate)
                }
                .environment(\.density, density)
                .padding(Space.s4)
                .background(Color.bgSurface)
            }
        }
        .padding(Space.s6)
    }
    .background(Color.bgCanvas)
}
