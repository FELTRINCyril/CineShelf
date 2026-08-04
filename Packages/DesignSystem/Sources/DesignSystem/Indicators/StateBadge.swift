import SwiftUI

// MARK: - I6 · Le badge d'état
//
// Relevé sur la planche 3 bloc `4a` (le jeton de filtre actif, en ambre plein), la
// planche 7 bloc `9d` (« PRIVÉ », posé en bas d'une vignette masquée) et la tuile de
// `I2`, qui portait jusqu'ici sa propre version privée :
//
//     <span style="padding:7px 12px;background:oklch(0.8 0.14 66);
//                  color:oklch(0.14 0 0);font:600 11px/1 'Archivo Narrow';
//                  letter-spacing:0.1em;text-transform:uppercase">Drame ✕</span>
//
// **Ce lot rend public ce que `I2` avait inliné**, et ce n'est pas un polissage du lot
// précédent : `PosterTile.stateBadge` était une vue privée en attendant que `I6` livre
// le composant. Elle disparaît au profit de celui-ci, qui rend exactement la même chose.
//
// Deux relevés qui ne se devinent pas :
//
// 1. **Le fond n'est jamais un aplat de surface.** Sur une affiche, c'est `chip.onImage`
//    — `bg.canvas` à 82 % — parce que le badge doit rester lisible sur une image claire
//    comme sur une sombre. La règle « zéro translucidité » du système ne vaut que pour
//    les surfaces opaques ; sur une image, les voiles sont explicitement autorisés (§4.1).
// 2. **Le texte d'un badge teinté est `accent.onAccent`, pas `text.primary`.** Le
//    prototype pose du `oklch(0.14 0 0)` sur l'ambre : un texte clair sur l'ambre ne
//    passerait pas le contraste, et c'est précisément le rôle de ce jeton.

/// Un jeton d'état court, en capitales : « Vu », « Archivé », « Privé », « Drame ✕ ».
public struct StateBadge: View {
    private let text: LocalizedStringKey
    private let symbol: String?
    private let tone: Tone

    /// La teinte du badge. Chacune est relevée, aucune n'est inventée.
    public enum Tone: Sendable, CaseIterable {
        /// Sur une affiche, fond `chip.onImage`. Le cas de loin le plus fréquent.
        case onImage
        /// Ambre plein : un filtre actif, l'élément courant. Texte `accent.onAccent`.
        case accent
        /// Vert plein : une ligne validée, une synchronisation terminée.
        case success
        /// Rouge plein : un refus, une ligne en erreur.
        case danger

        var background: Color {
            switch self {
            case .onImage: Color.chipOnImage
            case .accent: Color.accent
            case .success: Color.success
            case .danger: Color.danger
            }
        }

        var foreground: Color {
            switch self {
            // Les trois teintes pleines portent un texte sombre : c'est ce que
            // `accent.onAccent` existe pour dire, et le prototype le fait pour les trois.
            case .onImage: Color.textPrimary
            case .accent, .success, .danger: Color.accentOnAccent
            }
        }
    }

    public init(_ text: LocalizedStringKey, symbol: String? = nil, tone: Tone = .onImage) {
        self.text = text
        self.symbol = symbol
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: Space.s1) {
            if let symbol {
                Image(systemName: symbol)
                    // `hierarchical` quand le symbole accompagne du texte (§8).
                    .symbolRenderingMode(.hierarchical)
            }
            Text(text)
        }
        .labelStyle()
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, Space.s2)
        .padding(.vertical, Space.s1)
        .background(tone.background)
        // Aucun rayon : `radius.xs` est pour les jetons **cliquables** de formulaire, et
        // un badge d'état ne se clique pas. Le jeton de filtre, lui, appartient à `I5`.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Badges · les quatre teintes") {
    VStack(alignment: .leading, spacing: Space.s3) {
        HStack(spacing: Space.s2) {
            StateBadge("Vu")
            StateBadge("Archivé")
            StateBadge("Privé", symbol: Icon.isPrivate)
        }
        HStack(spacing: Space.s2) {
            StateBadge("Drame", tone: .accent)
            StateBadge("771 prêtes", tone: .success)
            StateBadge("417 en erreur", tone: .danger)
        }
    }
    .padding(Space.s5)
    .background(Color.bgCanvas)
}
