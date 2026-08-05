import SwiftUI

// MARK: - I10 · Le bandeau
//
// Relevé sur la **planche 7, bloc `9c`** — « Interruptions · bandeau d'abord, écran plein en
// dernier recours ». Sa légende porte la règle, et c'est elle qui décide de tout :
//
// > Bandeaux · **posés sous la barre, le contenu reste utilisable**
//
//     <div style="width:1280px;display:flex;align-items:center;gap:16px;padding:14px 24px;
//                 background: {{ b.bg }}">
//       <span style="width:8px;height:8px;border-radius:50%;background: {{ b.dot }}">
//       <span style="font:600 11px/1 'Archivo Narrow';letter-spacing:0.16em;
//                    text-transform:uppercase;color: {{ b.dot }}">{{ b.kind }}</span>
//       …texte, action, ✕
//
// **Ni modal, ni alerte, ni toast qui recouvre.** Un bandeau pleine largeur, sans rayon et
// sans bordure, qui pousse le contenu au lieu de le masquer. Le seul écran plein que la
// planche autorise est le verrouillage biométrique, et il appartient à `V7`.
//
// **La pastille est ronde, et ce n'est pas une entorse à la direction.** Le motif de
// `CLAUDE.md` est « rien de photographique et rectangulaire n'a de coin arrondi » : un point
// de 8 pt n'est ni l'un ni l'autre. C'est la même raison qui rend les personnes circulaires.
//
// **Les quatre tons du bloc tombent sur les jetons existants**, ce qui n'était pas garanti :
//
// | Bandeau du bloc | Fond relevé | Ton |
// |---|---|---|
// | Hors ligne | `oklch(0.24 0 0)` | neutre |
// | Synchronisation | accent à 12 % | `accent` |
// | Quota iCloud | danger à 13 % | `danger` |
// | Import terminé | success à 11 % | `success` |
//
// Aucun jeton neuf : les trois teintés sont leur couleur à faible opacité, et le neutre est
// `bg/fill`. C'est la même palette que `StateBadge`, et la cohérence est voulue — un badge
// « 417 en erreur » et un bandeau de quota parlent de la même chose.

/// Une interruption qui laisse le contenu utilisable.
public struct Banner: View {

    /// Le ton, qui porte le sens et la couleur.
    ///
    /// Nommé par **ce qu'il dit**, pas par sa couleur : `danger` et non `red`. Une teinte se
    /// renégocie, un sens non — et c'est ce qui permet à l'apparence claire de rendre autre
    /// chose sans que l'appelant change.
    public enum Tone: Sendable, CaseIterable {
        case neutral, accent, success, danger

        /// La couleur de la pastille et du libellé de genre.
        var mark: Color {
            switch self {
            case .neutral: .textSecondary
            case .accent: .accent
            case .success: .success
            case .danger: .danger
            }
        }

        /// Le fond : la teinte à faible opacité, ou `bg/fill` pour le neutre.
        ///
        /// Les opacités du bloc — 12, 13 et 11 % — sont ramenées à **12 %** pour les trois.
        /// Elles divergent d'un bandeau à l'autre sans qu'aucune règle ne l'explique : c'est
        /// la définition d'une mesure jamais contrôlée, donc le jeton gagne. L'écart d'un
        /// centième n'est de toute façon pas perceptible.
        var background: AnyShapeStyle {
            switch self {
            case .neutral: AnyShapeStyle(Color.bgFill)
            default: AnyShapeStyle(mark.opacity(Self.tintOpacity))
            }
        }

        static let tintOpacity: Double = 0.12
    }

    /// L'action facultative en bout de bandeau.
    public struct BannerAction {
        let label: LocalizedStringKey
        let perform: () -> Void

        public init(_ label: LocalizedStringKey, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    private let kind: LocalizedStringKey
    private let text: LocalizedStringKey
    private let tone: Tone
    private let action: BannerAction?
    private let dismiss: (() -> Void)?

    /// - Parameters:
    ///   - kind: le genre, en capitales — « Hors ligne », « Synchronisation ».
    ///   - text: la phrase complète. Le bloc en écrit toujours une, jamais un fragment.
    ///   - tone: le ton.
    ///   - action: le chemin proposé, s'il en existe un.
    ///   - dismiss: `nil` rend le bandeau **non renvoyable**, et c'est un choix de
    ///     l'appelant : « hors ligne » ne se referme pas d'un clic, la connexion revient ou
    ///     non. Le bloc montre la croix sur les quatre, mais un bandeau qui décrit un état
    ///     persistant reviendrait aussitôt — donc le rendre renvoyable serait mentir.
    public init(
        kind: LocalizedStringKey,
        text: LocalizedStringKey,
        tone: Tone = .neutral,
        action: BannerAction? = nil,
        dismiss: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.text = text
        self.tone = tone
        self.action = action
        self.dismiss = dismiss
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
            Circle()
                .fill(tone.mark)
                .frame(width: Self.dotSide, height: Self.dotSide)
                .accessibilityHidden(true)
            Text(kind)
                .font(Typo.label)
                .textCase(.uppercase)
                .tracking(Typo.Tracking.label)
                .foregroundStyle(tone.mark)
                .fixedSize()
            Text(text)
                .font(Typo.callout)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(tone.mark)
                    .frame(minHeight: Space.minHitTarget)
                    .fixedSize()
            }
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: Icon.close)
                        .font(Typo.callout)
                        .frame(width: Space.minHitTarget, height: Space.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.textSecondary)
                .accessibilityLabel("Fermer")
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.vertical, Space.s3 + 2)
        .frame(maxWidth: .infinity)
        .background(tone.background)
        .accessibilityElement(children: .combine)
    }

    /// 8 pt, la pastille du bloc.
    static let dotSide: CGFloat = 8
}

// MARK: - Previews

#Preview("Bandeaux · les quatre tons") {
    VStack(spacing: 0) {
        Banner(
            kind: "Hors ligne",
            text: "Tu es hors ligne. La collection reste consultable ; 3 modifications partiront à la reconnexion.",
            action: .init("Voir les modifications") {})
        Banner(
            kind: "Synchronisation",
            text: "Synchronisation iCloud en cours — 312 titres sur 1 284.",
            tone: .accent,
            action: .init("Détails") {})
        Banner(
            kind: "Quota iCloud",
            text: "Quota iCloud dépassé : 5 Go sur 5 Go. Les nouvelles images ne sont plus synchronisées.",
            tone: .danger,
            action: .init("Gérer le stockage") {},
            dismiss: {})
        Banner(
            kind: "Import",
            text: "Import terminé : 908 titres créés, 18 fusionnés, 26 en attente de correction.",
            tone: .success,
            action: .init("Corriger maintenant") {},
            dismiss: {})
    }
    .background(Color.bgCanvas)
}
