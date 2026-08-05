import SwiftUI

// MARK: - I10 · L'état vide paramétré
//
// Relevé sur la **planche 7, bloc `9a`** — « États vides · un par écran, avec son action ».
// Six écrans y sont rendus avec le même gabarit, et c'est ce qui en fait un composant :
//
//     <span style="width:70px;height:105px;background:repeating-linear-gradient(45deg,…)">
//     <span style="font:400 30px/1 'Bebas Neue'">{{ e.title }}</span>
//     <span style="font:300 14px/1.55 'Archivo Narrow';max-width:400px">{{ e.body }}</span>
//     <div style="gap:9px">
//       <span style="padding:12px 20px;background:oklch(0.99 0 0);color:oklch(0.12 0 0)
//                    font:600 12px">{{ e.cta }}</span>
//       <span style="padding:12px 18px;background:oklch(1 0 0 / 0.1)">{{ e.alt }}</span>
//     </div>
//     <span style="font:400 10px/1 'IBM Plex Mono'">{{ e.hint }}</span>
//
// **Cinq emplacements, et un seul est obligatoire.** Le titre. Le corps, l'action
// principale, l'action secondaire et l'indice sont facultatifs — les six exemples les
// remplissent tous, mais rien dans la direction n'oblige un écran à avoir deux actions, et
// un paramètre obligatoire vide se remplirait de texte inventé.
//
// **Ce que ce composant remplace.** `Components/StateView.swift`, de l'ancienne direction,
// qui prenait un `case` par situation — `noTitles`, `noResults`, `syncFailed` — et portait
// donc son texte en dur. Un état vide sur six écrans avec six messages différents ne peut
// pas être une énumération fermée dans `DesignSystem` : la copie appartient à l'écran, qui
// seul sait qu'il y a « deux filtres actifs » ou « 946 titres déjà vus ».
//
// MARK: - ÉCART : la carte fantôme est un aplat, pas une trame rayée
//
// Le bloc rend un pavé 2:3 en `repeating-linear-gradient(45deg, oklch(0.185), oklch(0.15))`.
// La claire des deux bandes tombe **exactement** sur `bg/surface` (mesuré : `#131313`, soit
// oklch 0,187) ; la sombre, à 0,15, n'est aucun jeton — entre `bg/inset` et `bg/surface`,
// sans correspondre à ni l'un ni l'autre.
//
// La trame n'est donc pas reproductible sans inventer un second jeton, et le §écart de la
// planche 7 dit lui-même de ses rayures qu'elles remplacent ce que l'app fera autrement.
// **Aplat `bg/surface`**, et l'écart s'inscrit. Ce qui compte est conservé : la forme est un
// **2:3**, celui d'une affiche absente, et non un SF Symbol — un pictogramme dirait « voici
// une catégorie », le pavé dit « il devrait y avoir une affiche ici ».

/// L'écran n'a rien à montrer, et il dit quoi faire.
public struct EmptyState: View {

    /// Une action de l'état vide.
    ///
    /// Deux rangs, et le rang décide du dessin : `primary` est l'aplat clair inversé,
    /// `secondary` le fond translucide. Le bloc n'en montre jamais plus de deux.
    public struct Action {
        let label: LocalizedStringKey
        let perform: () -> Void

        public init(_ label: LocalizedStringKey, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let primary: Action?
    private let secondary: Action?
    private let hint: LocalizedStringKey?

    /// - Parameters:
    ///   - title: la seule chose obligatoire.
    ///   - message: l'explication. Bornée à 400 pt de large par le bloc, pour rester
    ///     lisible. **Nommée `message` et non `body`** : un membre stocké `body` heurte
    ///     `View.body`, et l'erreur est une redéclaration invalide, pas un avertissement.
    ///   - primary: l'action que l'écran recommande.
    ///   - secondary: l'autre chemin, s'il en existe un.
    ///   - hint: la ligne technique — un raccourci, un total. En monospace, comme tout
    ///     chiffre du système.
    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        primary: Action? = nil,
        secondary: Action? = nil,
        hint: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.message = message
        self.primary = primary
        self.secondary = secondary
        self.hint = hint
    }

    public var body: some View {
        VStack(spacing: Space.s4) {
            ghost
            Text(title)
                .font(Typo.title1(dynamicTypeSize))
                .foregroundStyle(.textPrimary)
            if let message {
                Text(message)
                    .font(Typo.body)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: Self.bodyWidth)
            }
            if primary != nil || secondary != nil {
                actions
            }
            if let hint {
                Text(hint)
                    .font(Typo.micro)
                    .foregroundStyle(.textTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Space.s6)
        .accessibilityElement(children: .contain)
    }

    /// L'affiche absente : un 2:3, pas un pictogramme.
    private var ghost: some View {
        Rectangle()
            .fill(.bgSurface)
            .frame(width: Self.ghostWidth, height: Self.ghostWidth / CardLayout.portrait.aspectRatio)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        HStack(spacing: Space.s2 + 1) {
            if let primary {
                Button(primary.label, action: primary.perform)
                    .buttonStyle(ActionButtonStyle(rank: .primary))
            }
            if let secondary {
                Button(secondary.label, action: secondary.perform)
                    .buttonStyle(ActionButtonStyle(rank: .secondary))
            }
        }
        .padding(.top, Space.s1)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 400 pt, la borne du bloc — au-delà, une phrase de trois lignes devient un pavé.
    static let bodyWidth: CGFloat = 400
    /// 70 pt de large, soit 105 de haut : le 2:3 exact du bloc.
    static let ghostWidth: CGFloat = 70
}

// MARK: - Les deux rangs d'action

/// Le style des boutons d'action de la direction : aplat clair, ou fond translucide.
///
/// Un `ButtonStyle` et non deux vues : le rang ne change que le remplissage et le poids, et
/// deux composants auraient dupliqué la cible tactile et l'état pressé.
///
/// **Nommé `ActionButtonStyle` et public depuis `V2 bis`.** Il s'appelait
/// `EmptyStateButtonStyle` et était interne, parce que l'état vide était son seul appelant.
/// `CropEditor` en a besoin pour ses actions, et un second style aurait donné deux boutons
/// primaires qui ne se ressemblent pas — c'est exactement le cas que « l'écran ne possède pas
/// la forme » existe pour empêcher.
public struct ActionButtonStyle: ButtonStyle {
    public enum Rank: Sendable { case primary, secondary }

    private let rank: Rank

    public init(rank: Rank) {
        self.rank = rank
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(rank == .primary ? Typo.action : Typo.callout)
            .textCase(.uppercase)
            .tracking(Typo.Tracking.action)
            .foregroundStyle(rank == .primary ? Color.accentOnAccent : Color.textPrimary)
            .padding(.horizontal, rank == .primary ? Space.s5 : Space.s4 + 2)
            .padding(.vertical, Space.s3)
            .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
            .background(rank == .primary ? Color.textPrimary : Color.bgFill)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}

// MARK: - Previews

#Preview("État vide · les cinq emplacements") {
    VStack(spacing: Space.s6) {
        EmptyState(
            title: "Aucun titre pour l'instant",
            message: "Ta collection est vide. Importe un CSV ou ajoute un premier film à la main.",
            primary: .init("Importer un CSV") {},
            secondary: .init("Nouveau titre") {},
            hint: "⇧⌘I pour l'import")
        EmptyState(title: "Aucun résultat")
    }
    .background(Color.bgCanvas)
}
