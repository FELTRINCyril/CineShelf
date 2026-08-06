import SwiftUI

// MARK: - I5 · Le jeton de filtre
//
// Relevé sur la planche 5 bloc `7d` — la rangée « Titres · Personnes · Collections · Casting »
// du sélecteur d'entité :
//
//     actif   : padding:7px 11px; background:oklch(0.8 0.14 66); color:oklch(0.14 0 0);
//               font:600 11px 'Archivo Narrow'; letter-spacing:0.08em; text-transform:uppercase
//     inactif : padding:7px 11px; background:oklch(1 0 0 / 0.1);  color:oklch(0.86 0 0);
//               font:400 11px …
//
// **Ce n'est pas `StateBadge`, et la distinction n'est pas cosmétique.** Un badge *dit* un
// état ; un jeton *se clique* et bascule. Deux conséquences que le badge ne peut pas porter :
// la cible de 44 pt, et la croix de retrait. `V0 bis` et `V3` ont tous deux rendu leurs
// filtres en `StateBadge` faute de ce composant, en inscrivant l'écart — c'est ce lot qui le
// ferme.
//
// **La croix, et quand elle apparaît.** Le bloc `4a` de la planche 3 écrit « Drame ✕ · Note ≥ 4
// ✕ » : un jeton **actif** porte de quoi se retirer. Le bloc `7d`, lui, est un sélecteur
// exclusif — on ne retire pas « Titres », on choisit « Personnes » — donc pas de croix. Le
// jeton prend donc `onRemove` en option : la présence de la croix est une propriété de
// l'usage, pas du jeton.
//
// **Une seule graisse au lieu de deux, et c'est un écart assumé.** Le prototype met l'actif en
// 600 et l'inactif en 400 ; le système n'a **pas** d'Archivo Narrow 400 — les faces
// enregistrées sont `ArchivoNarrow-SemiBold` et `ArchivoNarrow-Bold`. Ajouter une face pour un
// écart de graisse sur un jeton de 11 pt coûterait un fichier de police embarqué et une entrée
// de plus dans le registre. Les deux états restent distincts par le **fond** et par la
// **couleur du texte**, qui sont les deux signaux forts. Inscrit.

/// Un filtre qu'on active, désactive, et parfois retire.
public struct FilterChip: View {
    private let label: LocalizedStringKey
    private let isOn: Bool
    private let action: () -> Void
    private let onRemove: (() -> Void)?

    @Environment(\.density) private var density

    /// - Parameters:
    ///   - label: le texte du jeton. **Fourni par l'écran** : le package ne sait pas ce qu'on
    ///     filtre, et un `enum` de cas ici serait la faute que `EmptyState` a corrigée.
    ///   - isOn: le jeton est-il retenu.
    ///   - onRemove: `nil` n'affiche aucune croix — le cas d'un sélecteur exclusif (`7d`).
    ///   - action: la bascule.
    public init(
        _ label: LocalizedStringKey,
        isOn: Bool,
        onRemove: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isOn = isOn
        self.onRemove = onRemove
        self.action = action
    }

    public var body: some View {
        HStack(spacing: Space.s2) {
            Text(label)
                .font(Typo.action)
                .textCase(.uppercase)
                .kerning(0.08 * Typo.Size.action)
            if let onRemove, isOn {
                Button(action: onRemove) {
                    Image(systemName: Icon.close)
                        .font(Typo.micro)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer le filtre")
            }
        }
        .foregroundStyle(isOn ? Color.accentOnAccent : Color.textPrimary)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        // **La cible de 44 pt est posée autour, pas dedans.** Le jeton rendu fait 25 pt de
        // haut ; l'agrandir à 44 le déformerait. Le `frame` étend la zone cliquable sans
        // toucher au dessin — c'est la règle d'accessibilité du projet, tenue sans trahir le
        // relevé.
        .frame(minHeight: Space.minHitTarget)
        .background(alignment: .center) { fill }
        .contentShape(.rect)
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// Le fond ne prend **que la hauteur du jeton**, pas celle de la cible tactile.
    private var fill: some View {
        (isOn ? Color.accent : Color.bgFill)
            .frame(height: verticalPadding * 2 + Typo.Size.action + 2)
    }

    private var horizontalPadding: CGFloat { density == .dense ? 11 : 13 }
    private var verticalPadding: CGFloat { density == .dense ? 7 : 8 }
}

// MARK: - Previews

#Preview("Jeton de filtre · les quatre formes") {
    VStack(alignment: .leading, spacing: Space.s5) {
        ForEach([Density.dense, .roomy], id: \.self) { density in
            HStack(spacing: Space.s2) {
                FilterChip("Titres", isOn: true) {}
                FilterChip("Personnes", isOn: false) {}
                FilterChip("Drame", isOn: true, onRemove: {}, action: {})
                FilterChip("Note ≥ 4", isOn: true, onRemove: {}, action: {})
            }
            .environment(\.density, density)
        }
    }
    .padding(Space.s6)
    .background(Color.bgCanvas)
}
