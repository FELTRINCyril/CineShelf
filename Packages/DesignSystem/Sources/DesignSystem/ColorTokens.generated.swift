// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py

import SwiftUI

public enum ColorTokens {

    /// Les 36 primitives. Aucune vue de l'app ne doit les lire :
    /// elles ne sont exposees que pour le catalogue et les tests.
    public static let primitives: [String] = [
        "Graphite/0",
        "Graphite/50",
        "Graphite/100",
        "Graphite/200",
        "Graphite/300",
        "Graphite/400",
        "Graphite/500",
        "Graphite/600",
        "Graphite/700",
        "Graphite/800",
        "Graphite/850",
        "Graphite/900",
        "Graphite/950",
        "Graphite/1000",
        "Ember/50",
        "Ember/100",
        "Ember/200",
        "Ember/300",
        "Ember/400",
        "Ember/500",
        "Ember/600",
        "Ember/700",
        "Ember/800",
        "Ember/900",
        "Jade/400",
        "Jade/500",
        "Jade/600",
        "Amber/400",
        "Amber/500",
        "Amber/600",
        "Crimson/400",
        "Crimson/500",
        "Crimson/600",
        "Azure/400",
        "Azure/500",
        "Azure/600"
    ]

    /// Les 23 jeux semantiques — le seul niveau que les vues lisent.
    public static let semantics: [String] = [
        "bg/canvas",
        "bg/surface",
        "bg/surfaceRaised",
        "bg/inset",
        "bg/selected",
        "text/primary",
        "text/secondary",
        "text/tertiary",
        "text/onAccent",
        "border/subtle",
        "border/default",
        "border/strong",
        "accent/text",
        "accent/solid",
        "accent/soft",
        "status/success",
        "status/warning",
        "status/danger",
        "status/info",
        "media/placeholder",
        "media/ring",
        "state/private",
        "state/archived"
    ]

    /// Les 59 Color Sets du catalogue.
    public static let all: [String] = primitives + semantics

    /// La couleur d'un token, par son nom. Sert au catalogue, qui parcourt les
    /// listes ci-dessus ; le code d'application passe par les accesseurs types.
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
        case "bg/surface": Color.bgSurface
        case "bg/surfaceRaised": Color.bgSurfaceRaised
        case "bg/inset": Color.bgInset
        case "bg/selected": Color.bgSelected
        case "text/primary": Color.textPrimary
        case "text/secondary": Color.textSecondary
        case "text/tertiary": Color.textTertiary
        case "text/onAccent": Color.textOnAccent
        case "border/subtle": Color.borderSubtle
        case "border/default": Color.borderDefault
        case "border/strong": Color.borderStrong
        case "accent/text": Color.accentText
        case "accent/solid": Color.accentSolid
        case "accent/soft": Color.accentSoft
        case "status/success": Color.statusSuccess
        case "status/warning": Color.statusWarning
        case "status/danger": Color.statusDanger
        case "status/info": Color.statusInfo
        case "media/placeholder": Color.mediaPlaceholder
        case "media/ring": Color.mediaRing
        case "state/private": Color.statePrivate
        case "state/archived": Color.stateArchived
        default: nil
        }
    }

    // swiftlint:enable cyclomatic_complexity
}

// MARK: - Source unique des jeux semantiques
//
// La chaine d'un token n'apparait qu'ici, une seule fois. Les deux extensions
// publiques ci-dessous s'y referent : c'est ce qui rend impossible la faute de
// frappe qui existait quand les 23 tokens etaient ecrits a la main deux fois.

extension ColorTokens {
    static var bgCanvas: Color { color(for: "bg/canvas") }
    static var bgSurface: Color { color(for: "bg/surface") }
    static var bgSurfaceRaised: Color { color(for: "bg/surfaceRaised") }
    static var bgInset: Color { color(for: "bg/inset") }
    static var bgSelected: Color { color(for: "bg/selected") }
    static var textPrimary: Color { color(for: "text/primary") }
    static var textSecondary: Color { color(for: "text/secondary") }
    static var textTertiary: Color { color(for: "text/tertiary") }
    static var textOnAccent: Color { color(for: "text/onAccent") }
    static var borderSubtle: Color { color(for: "border/subtle") }
    static var borderDefault: Color { color(for: "border/default") }
    static var borderStrong: Color { color(for: "border/strong") }
    static var accentText: Color { color(for: "accent/text") }
    static var accentSolid: Color { color(for: "accent/solid") }
    static var accentSoft: Color { color(for: "accent/soft") }
    static var statusSuccess: Color { color(for: "status/success") }
    static var statusWarning: Color { color(for: "status/warning") }
    static var statusDanger: Color { color(for: "status/danger") }
    static var statusInfo: Color { color(for: "status/info") }
    static var mediaPlaceholder: Color { color(for: "media/placeholder") }
    static var mediaRing: Color { color(for: "media/ring") }
    static var statePrivate: Color { color(for: "state/private") }
    static var stateArchived: Color { color(for: "state/archived") }
}

// MARK: - Acces typé aux jeux semantiques
//
// Niveau 2 uniquement : aucune vue ne reference une primitive (Graphite/900…),
// et aucune couleur litterale n'existe hors du package.
// Clair / sombre / contraste eleve sont resolus par les apparences du catalogue,
// jamais par du code conditionnel.
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
    public static var bgSurface: Color { ColorTokens.bgSurface }
    public static var bgSurfaceRaised: Color { ColorTokens.bgSurfaceRaised }
    public static var bgInset: Color { ColorTokens.bgInset }
    public static var bgSelected: Color { ColorTokens.bgSelected }
    public static var textPrimary: Color { ColorTokens.textPrimary }
    public static var textSecondary: Color { ColorTokens.textSecondary }
    public static var textTertiary: Color { ColorTokens.textTertiary }
    public static var textOnAccent: Color { ColorTokens.textOnAccent }
    public static var borderSubtle: Color { ColorTokens.borderSubtle }
    public static var borderDefault: Color { ColorTokens.borderDefault }
    public static var borderStrong: Color { ColorTokens.borderStrong }
    public static var accentText: Color { ColorTokens.accentText }
    public static var accentSolid: Color { ColorTokens.accentSolid }
    public static var accentSoft: Color { ColorTokens.accentSoft }
    public static var statusSuccess: Color { ColorTokens.statusSuccess }
    public static var statusWarning: Color { ColorTokens.statusWarning }
    public static var statusDanger: Color { ColorTokens.statusDanger }
    public static var statusInfo: Color { ColorTokens.statusInfo }
    public static var mediaPlaceholder: Color { ColorTokens.mediaPlaceholder }
    public static var mediaRing: Color { ColorTokens.mediaRing }
    public static var statePrivate: Color { ColorTokens.statePrivate }
    public static var stateArchived: Color { ColorTokens.stateArchived }
}

extension Color {
    public static var bgCanvas: Color { ColorTokens.bgCanvas }
    public static var bgSurface: Color { ColorTokens.bgSurface }
    public static var bgSurfaceRaised: Color { ColorTokens.bgSurfaceRaised }
    public static var bgInset: Color { ColorTokens.bgInset }
    public static var bgSelected: Color { ColorTokens.bgSelected }
    public static var textPrimary: Color { ColorTokens.textPrimary }
    public static var textSecondary: Color { ColorTokens.textSecondary }
    public static var textTertiary: Color { ColorTokens.textTertiary }
    public static var textOnAccent: Color { ColorTokens.textOnAccent }
    public static var borderSubtle: Color { ColorTokens.borderSubtle }
    public static var borderDefault: Color { ColorTokens.borderDefault }
    public static var borderStrong: Color { ColorTokens.borderStrong }
    public static var accentText: Color { ColorTokens.accentText }
    public static var accentSolid: Color { ColorTokens.accentSolid }
    public static var accentSoft: Color { ColorTokens.accentSoft }
    public static var statusSuccess: Color { ColorTokens.statusSuccess }
    public static var statusWarning: Color { ColorTokens.statusWarning }
    public static var statusDanger: Color { ColorTokens.statusDanger }
    public static var statusInfo: Color { ColorTokens.statusInfo }
    public static var mediaPlaceholder: Color { ColorTokens.mediaPlaceholder }
    public static var mediaRing: Color { ColorTokens.mediaRing }
    public static var statePrivate: Color { ColorTokens.statePrivate }
    public static var stateArchived: Color { ColorTokens.stateArchived }
}
