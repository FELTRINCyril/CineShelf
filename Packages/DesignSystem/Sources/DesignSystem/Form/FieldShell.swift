import SwiftUI

// MARK: - I7 · I8 · I9 — l'anatomie commune d'un champ
//
// Relevée sur la planche 6 bloc `8a` (dense) et `8b` (ample) :
//
//     libellé : font:600 9px 'Archivo Narrow'; letter-spacing:0.2em; uppercase; oklch(0.6)
//     champ   : background:oklch(1 0 0 / 0.08); padding:9px 11px; font:400 13px
//     focus   : border-bottom:2px solid oklch(0.8 0.14 66)
//     erreur  : background:oklch(0.7 0.19 35 / 0.12); border-bottom:2px solid oklch(0.7 0.19 35)
//
// **Les trois lots `I7`, `I8` et `I9` sont livrés ensemble, et c'est ce fichier qui le
// justifie.** Neuf composants, une seule anatomie : le même libellé, le même fond, le même
// trait de focus, les mêmes quatre marques d'erreur. Les livrer séparément aurait fait écrire
// cette coquille trois fois, ou pire — deux fois et demie, avec une divergence au milieu.
//
// **Les quatre marques d'erreur, et jamais plus** (addendum 1 bloc `11a`) : libellé en
// `danger`, trait en `danger`, triangle **dans** le champ, message en `micro` **sous** le
// champ. Aucun fond coloré au-delà du voile — « le système n'a pas de teinte d'état ».
//
// **Le message dit quoi faire, jamais ce qui est faux.** C'est la règle du bloc, et elle est
// tenue par la signature : `FieldError` ne prend pas de « raison », il prend une consigne.
//
// **Le récapitulatif de refus n'est pas un bandeau.** Le bloc `11c` le pose « dans le contenu,
// pas en notification » : réutiliser `Banner` de `I10` serait le poser en interruption, donc
// exactement ce que le bloc écarte. C'est la seule chose que `I9` partage avec `I10`, et c'est
// pour ne pas la partager.

/// Ce qu'un champ signale quand il refuse une valeur.
///
/// Une consigne, pas un diagnostic. « Utilise le format 2024-03-12 » et non « date invalide ».
///
/// **Pas `Sendable`, et le compilateur a raison** : `LocalizedStringKey` ne l'est pas. Ce type
/// n'a rien à faire d'un acteur à l'autre — la validation qui traverse est celle de
/// `CineShelfCore`, qui parle en clés et en valeurs, jamais en libellés d'interface.
public struct FieldError: Equatable {
    public let guidance: LocalizedStringKey

    public init(_ guidance: LocalizedStringKey) {
        self.guidance = guidance
    }
}

/// L'enveloppe commune : libellé, contenu, marques d'erreur.
///
/// Ce que la coquille possède : la géométrie, la couleur, le trait, la place du triangle et du
/// message. Ce que l'appelant fournit : **le texte du libellé, celui du message, et le
/// contenu** — la règle du dépôt, et la raison pour laquelle il n'y a pas d'`enum` de cas ici.
public struct FieldShell<Content: View>: View {
    private let label: LocalizedStringKey
    private let error: FieldError?
    private let isRequired: Bool
    private let isFocused: Bool
    private let content: Content

    @Environment(\.density) private var density

    /// - Parameters:
    ///   - label: le libellé, en capitales. Toujours présent : le bloc `8a` n'a aucun champ nu.
    ///   - isRequired: pose la mention « Requis » en `text.tertiary`. **Ce n'est pas une
    ///     erreur** — le bloc `11a` est explicite : « un requis vide reste neutre jusqu'à la
    ///     tentative de validation ».
    ///   - isFocused: pose le trait d'accent. Fourni par l'appelant plutôt que lu d'un
    ///     `@FocusState` : la coquille ne possède pas le focus, elle le rend.
    ///   - error: `nil` quand tout va bien. Un champ valide au repos ne se signale pas.
    ///   - content: la saisie elle-même.
    public init(
        _ label: LocalizedStringKey,
        isRequired: Bool = false,
        isFocused: Bool = false,
        error: FieldError? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.isRequired = isRequired
        self.isFocused = isFocused
        self.error = error
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            labelRow
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .frame(minHeight: density.fieldHeight, alignment: .leading)
                .background(fill)
                .overlay(alignment: .bottom) { underline }
                .overlay(alignment: .trailing) { warningMark }
            if let error {
                Text(error.guidance)
                    .font(Typo.micro)
                    .foregroundStyle(Color.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var labelRow: some View {
        HStack(spacing: Space.s2) {
            Text(label)
                .font(Typo.label)
                .textCase(.uppercase)
                .kerning(0.2 * Typo.Size.label)
                .foregroundStyle(error == nil ? Color.textTertiary : Color.danger)
            if isRequired, error == nil {
                Text("Requis")
                    .font(Typo.micro)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    /// Le voile de refus, et **rien de plus** : 12 % de `danger`, pas une teinte d'état.
    private var fill: Color {
        error == nil ? Color.bgFill : Color.danger.opacity(0.12)
    }

    /// Le trait bas. **Deux pixels**, comme le bloc `8a` les rend — le §11a écrit « trait
    /// 1 px », et c'est la prose de synthèse contre le bloc rendu : le bloc gagne.
    @ViewBuilder private var underline: some View {
        if error != nil {
            Color.danger.frame(height: Stroke.emphasis)
        } else if isFocused {
            Color.accent.frame(height: Stroke.emphasis)
        }
    }

    /// Le triangle **dans** le champ, à droite. Jamais dans le libellé, jamais dans le message.
    @ViewBuilder private var warningMark: some View {
        if error != nil {
            Image(systemName: Icon.error)
                .font(Typo.micro)
                .foregroundStyle(Color.danger)
                .padding(.trailing, Space.s2)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Le récapitulatif de refus — bloc 11c

/// La liste des champs fautifs, posée **en tête du formulaire, dans le contenu**.
///
/// « Rien n'est fermé, rien n'est perdu, aucune valeur remise à zéro » : ce composant ne fait
/// que nommer et mener. Chaque entrée est un lien vers son champ, et c'est l'écran qui sait
/// comment y aller — d'où la closure.
public struct ValidationSummary: View {
    private let title: LocalizedStringKey
    private let fields: [Entry]

    public struct Entry: Identifiable {
        public let id: String
        public let label: LocalizedStringKey
        public let focus: () -> Void

        public init(id: String, label: LocalizedStringKey, focus: @escaping () -> Void) {
            self.id = id
            self.label = label
            self.focus = focus
        }
    }

    public init(_ title: LocalizedStringKey, fields: [Entry]) {
        self.title = title
        self.fields = fields
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title)
                .font(Typo.headline)
                .foregroundStyle(Color.danger)
            ForEach(fields) { field in
                Button(action: field.focus) {
                    Text(field.label)
                        .font(Typo.callout)
                        .foregroundStyle(Color.textPrimary)
                        .underline()
                        .frame(minHeight: Space.minHitTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(Color.danger.opacity(0.12))
        .overlay(alignment: .leading) { Color.danger.frame(width: Stroke.emphasis) }
    }
}
