import SwiftUI

// MARK: - I9 · Le multi-sélecteur avec création à la volée, et la couleur de profil
//
// Relevés sur la planche 6 bloc `8a` :
//
//     conteneur : background:oklch(1 0 0 / 0.08); padding:8px; gap:6px; flex-wrap:wrap
//     jeton retenu : padding:5px 8px; background:oklch(0.8 0.14 66 / 0.22); color: ambre clair
//     jeton libre  : padding:5px 8px; background:oklch(1 0 0 / 0.09)
//
// **« Créer » ou « genre existant », et c'est un arbitrage déjà tranché** (« Arbitrages
// tranchés », point 2) : quand la frappe correspond à un `nameKey` connu, le menu propose
// « genre existant » et non « créer ». Le composant ne connaît pas les `nameKey` — c'est du
// domaine — donc l'écran lui passe la liste des suggestions **déjà résolue**, et le libellé de
// l'action de création. Une closure `onCreate` optionnelle : `nil` interdit la création, ce
// qui est le cas d'une liste fermée.
//
// **Le jeton du multi-sélecteur n'est pas `FilterChip`.** Ils se ressemblent — un fond, un
// texte, une croix — et ils ne font pas la même chose : `FilterChip` **bascule** un filtre et
// vit dans une barre, celui-ci **retire** une valeur d'un champ et vit dans un formulaire. Le
// relevé les sépare aussi : 5 × 8 ici, 7 × 11 là, et deux fonds différents. Les fusionner
// aurait donné un composant à deux modes, c'est-à-dire deux composants dans un.

/// Un champ à valeurs multiples, avec suggestion et création à la volée.
public struct TokenFieldRow: View {
    private let label: LocalizedStringKey
    @Binding private var values: [String]
    private let suggestions: [String]
    private let createLabel: ((String) -> LocalizedStringKey)?
    private let error: FieldError?

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    /// - Parameters:
    ///   - label: le libellé du champ.
    ///   - values: les valeurs retenues, dans l'ordre d'ajout.
    ///   - suggestions: ce que la frappe propose, **déjà filtré par l'écran**. Le package ne
    ///     sait pas replier un nom ni interroger un magasin.
    ///   - createLabel: le libellé de l'action de création, construit depuis la frappe —
    ///     « Créer « Néo-noir » ». `nil` interdit la création.
    ///   - error: le refus à afficher, s'il y en a un.
    public init(
        _ label: LocalizedStringKey,
        values: Binding<[String]>,
        suggestions: [String] = [],
        createLabel: ((String) -> LocalizedStringKey)? = nil,
        error: FieldError? = nil
    ) {
        self.label = label
        _values = values
        self.suggestions = suggestions
        self.createLabel = createLabel
        self.error = error
    }

    public var body: some View {
        FieldShell(label, isFocused: isFocused, error: error) {
            VStack(alignment: .leading, spacing: Space.s2) {
                tokens
                TextField("Ajouter…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(Typo.callout)
                    .foregroundStyle(Color.textPrimary)
                    .focused($isFocused)
                    .onSubmit { commit(draft) }
                if isFocused, !draft.isEmpty {
                    proposals
                }
            }
            .padding(.vertical, Space.s2)
        }
    }

    @ViewBuilder private var tokens: some View {
        if !values.isEmpty {
            // `WrappingHStack` n'existe pas dans SwiftUI ; `FlowLayout` non plus avant iOS 16
            // sans le composer soi-même. `Layout` le ferait proprement, mais ce champ porte
            // rarement plus de six valeurs : un `HStack` qui déborde serait faux, un `VStack`
            // de lignes calculées serait de l'arithmétique dans une vue. La grille adaptative
            // fait le retour à la ligne sans qu'on calcule rien.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: Space.s2, alignment: .leading)],
                alignment: .leading, spacing: Space.s2
            ) {
                ForEach(values, id: \.self) { value in
                    token(value)
                }
            }
        }
    }

    private func token(_ value: String) -> some View {
        HStack(spacing: Space.s1) {
            Text(value)
                .font(Typo.micro)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Button(
                action: { values.removeAll { $0 == value } },
                label: { Image(systemName: Icon.close).font(Typo.micro) }
            )
            .buttonStyle(.plain)
            .foregroundStyle(Color.textSecondary)
            .accessibilityLabel("Retirer \(value)")
        }
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 5)
        .background(Color.accent.opacity(0.22))
    }

    @ViewBuilder private var proposals: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(4), id: \.self) { suggestion in
                proposal(suggestion, isExisting: true)
            }
            // **« Créer » n'apparaît pas quand la frappe correspond déjà.** C'est l'arbitrage
            // du point 2 : proposer de créer un genre qui existe est la façon la plus directe
            // d'en fabriquer un doublon.
            if let createLabel, !suggestions.contains(where: { $0.caseInsensitiveCompare(draft) == .orderedSame }) {
                Button(
                    action: { commit(draft) },
                    label: {
                        Text(createLabel(draft))
                            .font(Typo.callout)
                            .foregroundStyle(Color.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: Space.minHitTarget)
                    }
                )
                .buttonStyle(.plain)
            }
        }
    }

    private func proposal(_ value: String, isExisting: Bool) -> some View {
        Button(
            action: { commit(value) },
            label: {
                Text(value)
                    .font(Typo.callout)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: Space.minHitTarget)
            }
        )
        .buttonStyle(.plain)
    }

    /// Ajoute une valeur, sans doublon ni blanc.
    private func commit(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            !values.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else {
            draft = ""
            return
        }
        values.append(trimmed)
        draft = ""
    }
}

// MARK: - Le sélecteur de couleur de profil

/// Les couleurs qu'un profil peut prendre. **Liste fermée**, et le §6 l'exige : « jetons de
/// couleur en liste fermée ».
///
/// Trois d'entre elles sont relevées sur la planche 6 — `oklch(0.62 0.14 250)`,
/// `oklch(0.64 0.13 150)`, `oklch(0.66 0.16 15)` —, la quatrième est l'accent du système.
/// **Elles ne sont pas des jetons sémantiques** : ce ne sont pas des rôles de l'interface mais
/// des valeurs qu'un utilisateur choisit et qu'on **persiste**. Les mettre dans le catalogue de
/// couleurs les ferait suivre l'apparence, or la couleur d'un profil doit rester la même en
/// clair et en sombre — c'est ainsi qu'on reconnaît son profil d'un coup d'œil.
public enum ProfileColor: String, CaseIterable, Identifiable, Sendable, Codable {
    case amber, blue, green, red

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .amber: Color.accent
        case .blue: Color(.displayP3, red: 0.31, green: 0.51, blue: 0.87)
        case .green: Color(.displayP3, red: 0.29, green: 0.68, blue: 0.44)
        case .red: Color(.displayP3, red: 0.90, green: 0.40, blue: 0.36)
        }
    }

    public var label: LocalizedStringKey {
        switch self {
        case .amber: "Ambre"
        case .blue: "Bleu"
        case .green: "Vert"
        case .red: "Rouge"
        }
    }
}

/// Les quatre pastilles, dont une retenue.
///
/// Relevé du bloc `8a` : `height:28px`, et la retenue porte `outline:2px solid oklch(0.99)` à
/// `outline-offset:2px` — un liseré **clair**, posé à l'extérieur. Pas d'ambre : la sélection
/// ne peut pas se signaler par une couleur, puisque la couleur est ce qu'on choisit.
public struct ProfileColorPicker: View {
    private let label: LocalizedStringKey
    @Binding private var selection: ProfileColor

    @Environment(\.density) private var density

    public init(_ label: LocalizedStringKey, selection: Binding<ProfileColor>) {
        self.label = label
        _selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(label)
                .font(Typo.label)
                .textCase(.uppercase)
                .kerning(0.2 * Typo.Size.label)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: Space.s3) {
                ForEach(ProfileColor.allCases) { swatch in
                    Button(
                        action: { selection = swatch },
                        label: {
                            swatch.color
                                .frame(width: density.fieldHeight, height: density.fieldHeight)
                                .overlay {
                                    if swatch == selection {
                                        Rectangle()
                                            .strokeBorder(Color.textPrimary, lineWidth: Stroke.emphasis)
                                            .padding(-4)
                                    }
                                }
                                .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
                                .contentShape(.rect)
                        }
                    )
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.label)
                    .accessibilityAddTraits(swatch == selection ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

#Preview("Multi-sélecteur et couleur de profil") {
    @Previewable @State var genres = ["Drame", "Science-fiction"]
    @Previewable @State var colour = ProfileColor.amber

    return VStack(alignment: .leading, spacing: Space.s5) {
        TokenFieldRow(
            "Genres", values: $genres,
            suggestions: ["Policier", "Poésie"],
            createLabel: { "Créer « \($0) »" })
        ProfileColorPicker("Couleur du profil", selection: $colour)
    }
    .padding(Space.s6)
    .frame(width: 360)
    .background(Color.bgCanvas)
}
