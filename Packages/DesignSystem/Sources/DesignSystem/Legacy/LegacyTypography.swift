import SwiftUI

// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Ces rôles appartiennent à la direction abandonnée. Ils ne survivent que parce
// que l'interface des prompts 10 et 11 sert de banc d'essai à la logique : les
// retirer casserait sa compilation, et on ne la polit pas mais on ne la supprime
// pas non plus.
//
// Rien de neuf ne doit les lire. Ils disparaissent en bloc avec `V12`.
// Voir README.md de ce dossier, et « Arbitrages tranchés » de docs/PROMPTS.md.
//
// `Typo.body` n'est **pas** redéclaré ici : c'est le seul nom que les deux
// directions partagent, et le nouveau gagne. Le banc d'essai rend donc son corps
// de texte en Public Sans 300 — c'est voulu, et c'est exactement à quoi sert un
// banc d'essai.

extension Typo {

    // Titrage de l'ancienne direction — Archivo et Archivo SemiExpanded.
    public static let heroTitle = Font.custom(
        DesignSystemFonts.Face.semiExpandedExtraBold.postScriptName,
        size: LegacyBase.hero,
        relativeTo: .largeTitle
    )
    public static let pageTitle = Font.custom(
        DesignSystemFonts.Face.archivoBold.postScriptName,
        size: LegacyBase.page,
        relativeTo: .title
    )
    public static let sectionTitle = Font.custom(
        DesignSystemFonts.Face.archivoSemiBold.postScriptName,
        size: LegacyBase.section,
        relativeTo: .title3
    )
    /// À composer avec `.railLabelStyle()`.
    public static let railLabel = Font.custom(
        DesignSystemFonts.Face.semiExpandedSemiBold.postScriptName,
        size: LegacyBase.railLabel,
        relativeTo: .caption
    )

    // Interface et corps — SF Pro système.
    public static let cardTitle = Font.subheadline.weight(.medium)
    public static let bodyEmphasis = Font.body.weight(.semibold)
    public static let fieldLabel = Font.footnote.weight(.medium)
    public static let caption = Font.caption

    // Données — SF Mono.
    public static let cardMeta = Font.system(.caption2, design: .monospaced)
    public static let dataValue = Font.system(.callout, design: .monospaced)
    /// Compteur du rail d'étagère (« 01–08 / 24 »).
    public static let railCounter = Font.system(.caption2, design: .monospaced).monospacedDigit()

    /// Interlettrage des libellés de rail en majuscules (0.08em à la taille de base).
    public static let railTracking: CGFloat = LegacyBase.railLabel * 0.08

    /// Tailles de base par plateforme de l'ancienne direction.
    private enum LegacyBase {
        #if os(macOS)
            static let hero: CGFloat = 26
            static let page: CGFloat = 22
            static let section: CGFloat = 15
            static let railLabel: CGFloat = 10
        #else
            static let hero: CGFloat = 34
            static let page: CGFloat = 28
            static let section: CGFloat = 20
            static let railLabel: CGFloat = 12
        #endif
    }
}

extension View {
    /// Applique le rôle `railLabel` complet : casse, interlettrage, couleur.
    public func railLabelStyle() -> some View {
        self.font(Typo.railLabel)
            .textCase(.uppercase)
            .tracking(Typo.railTracking)
            .foregroundStyle(.textSecondary)
    }
}

extension EnvironmentValues {
    /// Au-delà de `.accessibility1`, les grilles de cartes passent en liste.
    ///
    /// La direction courante ne fait pas ça : ses grilles perdent une à deux
    /// colonnes et restent des grilles. Ne pas reprendre.
    public var prefersListLayout: Bool { dynamicTypeSize.isAccessibilitySize }
}
