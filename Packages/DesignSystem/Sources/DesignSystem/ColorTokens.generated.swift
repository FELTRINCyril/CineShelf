// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py

import SwiftUI

public enum ColorTokens {

    /// Les 19 roles de la direction « 2a Plein cadre » — le seul
    /// niveau qu'une vue lit, et le seul que du code neuf a le droit de lire.
    ///
    /// Il n'y a pas de niveau « primitives » : la planche 8 ne fournit aucune
    /// rampe, elle pose directement ces roles avec leurs quatre apparences.
    public static let semantics: [String] = [
        "bg/canvas",
        "bg/inset",
        "bg/surface",
        "bg/raised",
        "bg/fill",
        "bg/viewer",
        "text/primary",
        "text/secondary",
        "text/tertiary",
        "accent",
        "accent/onAccent",
        "danger",
        "success",
        "separator",
        "private/mask",
        "scrim/modal",
        "scrim/crop",
        "fill/onImage",
        "chip/onImage"
    ]

    /// Les 19 Color Sets de la direction courante.
    public static let all: [String] = semantics

    /// Le nom d'accesseur Swift de chaque jeu, dans le meme ordre que `semantics`.
    ///
    /// Genere plutot que re-derive dans les tests : c'est ce qui permet a
    /// `ShapeStyleCollisionTests` de verifier les noms **reellement declares**,
    /// y compris ceux desambiguises par `ACCESSOR_OVERRIDES`.
    public static let accessorNames: [String] = [
        "bgCanvas",
        "bgInset",
        "bgSurface",
        "bgRaised",
        "bgFill",
        "bgViewer",
        "textPrimary",
        "textSecondary",
        "textTertiary",
        "accent",
        "accentOnAccent",
        "danger",
        "success",
        "separatorLine",
        "privateMask",
        "scrimModal",
        "scrimCrop",
        "fillOnImage",
        "chipOnImage"
    ]

    /// La couleur d'un token, par son nom. Sert au catalogue, qui parcourt la
    /// liste ci-dessus ; le code d'application passe par les accesseurs types.
    public static func color(for token: String) -> Color {
        Color(token, bundle: .designSystem)
    }

    // Un `switch` exhaustif genere n'a pas de complexite au sens ou la regle
    // l'entend : il n'y a rien a y simplifier.
    // swiftlint:disable cyclomatic_complexity

    /// L'accesseur type correspondant a un jeu semantique.
    ///
    /// Ce `switch` relie la source de verite JSON aux accesseurs publics :
    /// il traverse `extension Color`, donc il en verifie le cablage.
    public static func typedAccessor(for token: String) -> Color? {
        switch token {
        case "bg/canvas": Color.bgCanvas
        case "bg/inset": Color.bgInset
        case "bg/surface": Color.bgSurface
        case "bg/raised": Color.bgRaised
        case "bg/fill": Color.bgFill
        case "bg/viewer": Color.bgViewer
        case "text/primary": Color.textPrimary
        case "text/secondary": Color.textSecondary
        case "text/tertiary": Color.textTertiary
        case "accent": Color.accent
        case "accent/onAccent": Color.accentOnAccent
        case "danger": Color.danger
        case "success": Color.success
        case "separator": Color.separatorLine
        case "private/mask": Color.privateMask
        case "scrim/modal": Color.scrimModal
        case "scrim/crop": Color.scrimCrop
        case "fill/onImage": Color.fillOnImage
        case "chip/onImage": Color.chipOnImage
        default: nil
        }
    }

    // swiftlint:enable cyclomatic_complexity
}

// MARK: - Source unique des jeux semantiques
//
// La chaine d'un token n'apparait qu'ici, une seule fois. Les deux extensions
// publiques ci-dessous s'y referent : c'est ce qui rend impossible la faute de
// frappe qui existait quand les tokens etaient ecrits a la main deux fois.

extension ColorTokens {
    static var bgCanvas: Color { ColorTokens.color(for: "bg/canvas") }
    static var bgInset: Color { ColorTokens.color(for: "bg/inset") }
    static var bgSurface: Color { ColorTokens.color(for: "bg/surface") }
    static var bgRaised: Color { ColorTokens.color(for: "bg/raised") }
    static var bgFill: Color { ColorTokens.color(for: "bg/fill") }
    static var bgViewer: Color { ColorTokens.color(for: "bg/viewer") }
    static var textPrimary: Color { ColorTokens.color(for: "text/primary") }
    static var textSecondary: Color { ColorTokens.color(for: "text/secondary") }
    static var textTertiary: Color { ColorTokens.color(for: "text/tertiary") }
    static var accent: Color { ColorTokens.color(for: "accent") }
    static var accentOnAccent: Color { ColorTokens.color(for: "accent/onAccent") }
    static var danger: Color { ColorTokens.color(for: "danger") }
    static var success: Color { ColorTokens.color(for: "success") }
    static var separatorLine: Color { ColorTokens.color(for: "separator") }
    static var privateMask: Color { ColorTokens.color(for: "private/mask") }
    static var scrimModal: Color { ColorTokens.color(for: "scrim/modal") }
    static var scrimCrop: Color { ColorTokens.color(for: "scrim/crop") }
    static var fillOnImage: Color { ColorTokens.color(for: "fill/onImage") }
    static var chipOnImage: Color { ColorTokens.color(for: "chip/onImage") }
}

// MARK: - Acces typé aux jeux semantiques
//
// Aucune couleur litterale n'existe hors de ce package. Clair, sombre et
// contraste eleve sont resolus par les apparences du catalogue d'assets, jamais
// par du code conditionnel.
//
// Deux extensions, parce que les deux chemins d'appel existent et doivent tous
// deux rester ergonomiques :
//
//   - `extension ShapeStyle where Self == Color` sert `.background(.bgCanvas)`,
//     `.foregroundStyle(.textPrimary)` — la forme implicite, celle que les vues
//     ecrivent le plus ;
//   - `extension Color` sert la ou le contexte n'infere pas un `ShapeStyle` :
//     `Color` stocke dans un modele, `.tint(Color)`, interpolations.
//
// Swift prefere le membre du type concret au membre d'extension de protocole :
// `Color.bgCanvas` atteint donc toujours la seconde, et seule la forme implicite
// atteint la premiere. C'est pour ca que ColorAssetTests les couvre separement.

extension ShapeStyle where Self == Color {
    public static var bgCanvas: Color { ColorTokens.bgCanvas }
    public static var bgInset: Color { ColorTokens.bgInset }
    public static var bgSurface: Color { ColorTokens.bgSurface }
    public static var bgRaised: Color { ColorTokens.bgRaised }
    public static var bgFill: Color { ColorTokens.bgFill }
    public static var bgViewer: Color { ColorTokens.bgViewer }
    public static var textPrimary: Color { ColorTokens.textPrimary }
    public static var textSecondary: Color { ColorTokens.textSecondary }
    public static var textTertiary: Color { ColorTokens.textTertiary }
    public static var accent: Color { ColorTokens.accent }
    public static var accentOnAccent: Color { ColorTokens.accentOnAccent }
    public static var danger: Color { ColorTokens.danger }
    public static var success: Color { ColorTokens.success }
    public static var separatorLine: Color { ColorTokens.separatorLine }
    public static var privateMask: Color { ColorTokens.privateMask }
    public static var scrimModal: Color { ColorTokens.scrimModal }
    public static var scrimCrop: Color { ColorTokens.scrimCrop }
    public static var fillOnImage: Color { ColorTokens.fillOnImage }
    public static var chipOnImage: Color { ColorTokens.chipOnImage }
}

extension Color {
    public static var bgCanvas: Color { ColorTokens.bgCanvas }
    public static var bgInset: Color { ColorTokens.bgInset }
    public static var bgSurface: Color { ColorTokens.bgSurface }
    public static var bgRaised: Color { ColorTokens.bgRaised }
    public static var bgFill: Color { ColorTokens.bgFill }
    public static var bgViewer: Color { ColorTokens.bgViewer }
    public static var textPrimary: Color { ColorTokens.textPrimary }
    public static var textSecondary: Color { ColorTokens.textSecondary }
    public static var textTertiary: Color { ColorTokens.textTertiary }
    public static var accent: Color { ColorTokens.accent }
    public static var accentOnAccent: Color { ColorTokens.accentOnAccent }
    public static var danger: Color { ColorTokens.danger }
    public static var success: Color { ColorTokens.success }
    public static var separatorLine: Color { ColorTokens.separatorLine }
    public static var privateMask: Color { ColorTokens.privateMask }
    public static var scrimModal: Color { ColorTokens.scrimModal }
    public static var scrimCrop: Color { ColorTokens.scrimCrop }
    public static var fillOnImage: Color { ColorTokens.fillOnImage }
    public static var chipOnImage: Color { ColorTokens.chipOnImage }
}
