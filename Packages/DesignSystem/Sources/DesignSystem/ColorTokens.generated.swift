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
    /// Ce `switch` est ce qui relie la source de verite JSON aux accesseurs
    /// ecrits a la main dans Colors.swift : ajouter un jeu semantique au JSON
    /// sans lui ecrire son accesseur casse la compilation, pas seulement un test.
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
