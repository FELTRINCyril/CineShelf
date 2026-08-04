// Fichier genere par scripts/generate-colors.py — ne pas editer a la main.
// Source de verite : Resources/colors.legacy.tokens.json
// Regenerer avec : python3 scripts/generate-colors.py
//
// ANCIENNE DIRECTION ARTISTIQUE — EN SURSIS.
//
// Ces 17 jeux n'existent que pour que l'interface des prompts 10 et 11
// continue de compiler et de s'afficher : elle sert de banc d'essai a la logique.
// Les retirer du catalogue d'assets ne casserait pas la compilation, elle
// rendrait du transparent — une defaillance silencieuse.
//
// Rien de neuf ne doit les lire. Ils disparaissent en bloc avec `V12`, avec
// `Legacy/` en entier et les deux ArchivoSemiExpanded.
// Voir Legacy/README.md et « Arbitrages tranchés » de docs/PROMPTS.md.

import SwiftUI

public enum LegacyColorTokens {

    /// Les 17 jeux de l'ancienne direction encore lus par le banc d'essai.
    /// Les six noms communs avec la direction courante n'y sont pas : ils sont
    /// servis par `ColorTokens`, donc avec les nouvelles valeurs.
    public static let semantics: [String] = [
        "bg/surfaceRaised",
        "bg/selected",
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

    public static func color(for token: String) -> Color {
        Color(token, bundle: .designSystem)
    }
}

extension LegacyColorTokens {
    static var bgSurfaceRaised: Color { LegacyColorTokens.color(for: "bg/surfaceRaised") }
    static var bgSelected: Color { LegacyColorTokens.color(for: "bg/selected") }
    static var textOnAccent: Color { LegacyColorTokens.color(for: "text/onAccent") }
    static var borderSubtle: Color { LegacyColorTokens.color(for: "border/subtle") }
    static var borderDefault: Color { LegacyColorTokens.color(for: "border/default") }
    static var borderStrong: Color { LegacyColorTokens.color(for: "border/strong") }
    static var accentText: Color { LegacyColorTokens.color(for: "accent/text") }
    static var accentSolid: Color { LegacyColorTokens.color(for: "accent/solid") }
    static var accentSoft: Color { LegacyColorTokens.color(for: "accent/soft") }
    static var statusSuccess: Color { LegacyColorTokens.color(for: "status/success") }
    static var statusWarning: Color { LegacyColorTokens.color(for: "status/warning") }
    static var statusDanger: Color { LegacyColorTokens.color(for: "status/danger") }
    static var statusInfo: Color { LegacyColorTokens.color(for: "status/info") }
    static var mediaPlaceholder: Color { LegacyColorTokens.color(for: "media/placeholder") }
    static var mediaRing: Color { LegacyColorTokens.color(for: "media/ring") }
    static var statePrivate: Color { LegacyColorTokens.color(for: "state/private") }
    static var stateArchived: Color { LegacyColorTokens.color(for: "state/archived") }
}

extension ShapeStyle where Self == Color {
    public static var bgSurfaceRaised: Color { LegacyColorTokens.bgSurfaceRaised }
    public static var bgSelected: Color { LegacyColorTokens.bgSelected }
    public static var textOnAccent: Color { LegacyColorTokens.textOnAccent }
    public static var borderSubtle: Color { LegacyColorTokens.borderSubtle }
    public static var borderDefault: Color { LegacyColorTokens.borderDefault }
    public static var borderStrong: Color { LegacyColorTokens.borderStrong }
    public static var accentText: Color { LegacyColorTokens.accentText }
    public static var accentSolid: Color { LegacyColorTokens.accentSolid }
    public static var accentSoft: Color { LegacyColorTokens.accentSoft }
    public static var statusSuccess: Color { LegacyColorTokens.statusSuccess }
    public static var statusWarning: Color { LegacyColorTokens.statusWarning }
    public static var statusDanger: Color { LegacyColorTokens.statusDanger }
    public static var statusInfo: Color { LegacyColorTokens.statusInfo }
    public static var mediaPlaceholder: Color { LegacyColorTokens.mediaPlaceholder }
    public static var mediaRing: Color { LegacyColorTokens.mediaRing }
    public static var statePrivate: Color { LegacyColorTokens.statePrivate }
    public static var stateArchived: Color { LegacyColorTokens.stateArchived }
}

extension Color {
    public static var bgSurfaceRaised: Color { LegacyColorTokens.bgSurfaceRaised }
    public static var bgSelected: Color { LegacyColorTokens.bgSelected }
    public static var textOnAccent: Color { LegacyColorTokens.textOnAccent }
    public static var borderSubtle: Color { LegacyColorTokens.borderSubtle }
    public static var borderDefault: Color { LegacyColorTokens.borderDefault }
    public static var borderStrong: Color { LegacyColorTokens.borderStrong }
    public static var accentText: Color { LegacyColorTokens.accentText }
    public static var accentSolid: Color { LegacyColorTokens.accentSolid }
    public static var accentSoft: Color { LegacyColorTokens.accentSoft }
    public static var statusSuccess: Color { LegacyColorTokens.statusSuccess }
    public static var statusWarning: Color { LegacyColorTokens.statusWarning }
    public static var statusDanger: Color { LegacyColorTokens.statusDanger }
    public static var statusInfo: Color { LegacyColorTokens.statusInfo }
    public static var mediaPlaceholder: Color { LegacyColorTokens.mediaPlaceholder }
    public static var mediaRing: Color { LegacyColorTokens.mediaRing }
    public static var statePrivate: Color { LegacyColorTokens.statePrivate }
    public static var stateArchived: Color { LegacyColorTokens.stateArchived }
}
