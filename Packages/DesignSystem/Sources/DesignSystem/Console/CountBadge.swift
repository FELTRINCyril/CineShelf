import SwiftUI

// MARK: - I5 · La pastille de compteur
//
// Relevée sur la planche 5 bloc `7a`, la barre latérale des dix entités :
//
//     <span style="display:flex;justify-content:space-between;…">
//       <span>{{ e.n }}</span>
//       <span style="font:400 11px 'IBM Plex Mono';color:oklch(0.5 0 0)">{{ e.k }}</span>
//
// **Ce n'est pas une pastille, et c'est le relevé qui le dit.** Le lot l'appelle « pastille de
// compteur », mais le bloc ne dessine **aucun fond** : un nombre en mono, en `text.tertiary`,
// poussé à droite. Le nom du lot vient de l'inventaire des composants, écrit avant la
// direction artistique ; la direction « plein cadre » n'a ni pilule, ni badge de compte.
// Dessiner un fond ici serait rattraper un composant que la direction a supprimé — exactement
// ce que la règle de lint `no_legacy_design_system` interdit ailleurs.
//
// **Mono, et ce n'est pas décoratif** : les dix compteurs de la barre latérale sont alignés en
// colonne — 1 284, 3 902, 38, 62, 14 118 — et une police proportionnelle les ferait danser à
// chaque rafraîchissement. `Typo.numeric` porte déjà `monospacedDigit()` pour cette raison ;
// `Typo.meta` est la variante non tabulaire, et c'est celle du relevé (400, 11 pt).

/// Un compte, posé à droite d'une entrée de liste.
public struct CountBadge: View {
    private let count: Int
    private let isProminent: Bool

    /// - Parameters:
    ///   - count: le nombre. Formaté par la locale — 1 284 et non 1284, comme le prototype.
    ///   - isProminent: passe le compte en `text.secondary`. Sert à la ligne courante d'une
    ///     liste, que le relevé ne montre pas mais que la navigation au clavier réclame.
    public init(_ count: Int, isProminent: Bool = false) {
        self.count = count
        self.isProminent = isProminent
    }

    public var body: some View {
        Text(count, format: .number)
            .font(Typo.numeric)
            .foregroundStyle(isProminent ? Color.textSecondary : Color.textTertiary)
            // Les chiffres ne se coupent jamais : « 14 1… » n'est pas un compte, c'est un
            // mensonge. La cellule rétrécit le libellé, jamais le nombre.
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("\(count)")
    }
}

// MARK: - Previews

#Preview("Compteurs alignés") {
    VStack(alignment: .leading, spacing: 0) {
        ForEach(
            [("Titres", 1_284), ("Personnes", 3_902), ("Collections", 38), ("Casting", 14_118)],
            id: \.0
        ) { entry in
            HStack {
                Text(entry.0).font(Typo.callout).foregroundStyle(Color.textSecondary)
                Spacer(minLength: Space.s4)
                CountBadge(entry.1)
            }
            .padding(.horizontal, Space.s4)
            .frame(height: ConsoleMetrics.rowHeight(.dense))
        }
    }
    .frame(width: 206)
    .background(Color.bgSurface)
    .padding(Space.s6)
    .background(Color.bgCanvas)
}
