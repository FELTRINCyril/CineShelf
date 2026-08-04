import SwiftUI
import Testing

@testable import DesignSystem

// Les trois composants de `I6`. Ce qui se teste ici est leur **arithmetique** — le rendu,
// lui, se juge sur la planche du catalogue.
//
// **Pourquoi cette arithmetique ne vit pas sur les vues.** `View` est `@MainActor`, donc
// tout membre d'une vue l'est aussi, et une cloture qui capture `self` depuis un test non
// isole fait sauter le processus (`_swift_task_checkIsolatedSwift`, `SIGTRAP`) au lieu
// d'echouer proprement. Mesure du jour : un `segments.map { width(of: $0, …) }` porte par
// `ProgressTrack` tuait la suite entiere, y compris avec zero test selectionne, et le
// message ne nommait aucun test. `ProgressMetrics` est sorti de la vue pour ca — meme
// forme que `GridMetrics` pour `I4`.

// MARK: - Notation

@Test("Cinq crans, et c'est la regle du design, pas un reglage")
func theRatingBarHasFiveSteps() {
    // Source : `docs/design/README.md` §6, « note en cinq etoiles pleines (pas de
    // demi-etoile) ». C'est une regle de **rendu** : le modele note sur 10
    // (`docs/02` §3.3, `CatalogBounds.ratings` == 0...10).
    #expect(RatingBar.starCount == 5)
}

@Test("La note affichee est bornee a l'echelle, jamais au-dela")
func filledStarsStayWithinTheScale() {
    // Valeur nommee et non tuple : convention du depot.
    struct Case {
        let rating: Double?
        let expected: Int
    }

    let cases = [
        Case(rating: nil, expected: 0),
        Case(rating: 0, expected: 0),
        Case(rating: 3, expected: 3),
        Case(rating: 5, expected: 5),
        // Une note impaire du modele arrive ici en fractionnaire : 9/10 -> 4,5.
        Case(rating: 4.5, expected: 5),
        Case(rating: 4.4, expected: 4),
        // Des valeurs hors echelle ne doivent produire ni six etoiles ni un compte
        // negatif : la barre affiche, elle ne valide pas.
        Case(rating: 12, expected: 5),
        Case(rating: -3, expected: 0),
        // `Int(_:)` sur un Double non fini **trappe**, il ne rend pas zero. D'ou le
        // `isFinite` dans `filledCount(for:)`, et ces deux cas.
        Case(rating: .nan, expected: 0),
        Case(rating: .infinity, expected: 0)
    ]

    for item in cases {
        #expect(
            RatingBar.filledCount(for: item.rating) == item.expected,
            "note \(String(describing: item.rating))")
    }
}

// **Il n'y a volontairement pas de test « le modele note sur 10 » ici.** Cette borne est
// `CatalogBounds.ratings`, dans `CineShelfCore`, que `DesignSystem` ne peut pas importer —
// et la recopier pour l'assener produirait une seconde source de verite pour une valeur
// qui n'en a qu'une. C'est le defaut qu'on vient de retirer de `Breakpoint.columns`.
//
// Ce qui protege cette frontiere existe deja, ailleurs : la docstring de
// `CatalogBounds.ratings`, `BulkEditor+Validation`, et les tests de `L10` et de l'import
// qui verifient qu'une note de 9 passe. `RatingBar` n'a qu'une obligation, tenue par le
// test ci-dessus : ne rien refuser, seulement afficher.

// MARK: - Progression

@Test("Les segments se partagent la piste au prorata du total")
func segmentsSplitTheTrack() {
    // Source : addendum 1 bloc `11e` — 1 284 lignes, 771 pretes, 417 en erreur,
    // 96 doublons, soit 60 % / 32,5 % / 7,5 %.
    let widths = ProgressMetrics.widths(
        of: [
            ProgressSegment(id: "ok", value: 771, role: .done),
            ProgressSegment(id: "ko", value: 417, role: .failed),
            ProgressSegment(id: "dup", value: 96, role: .neutral)
        ],
        total: 1284,
        in: 1000)

    #expect(abs(widths[0] - 600) < 0.5, "771 / 1284 = 60 %")
    #expect(abs(widths[1] - 325) < 0.5, "417 / 1284 = 32,5 %")
    #expect(abs(widths[2] - 75) < 0.5, "96 / 1284 = 7,5 %")
    #expect(abs(widths.reduce(0, +) - 1000) < 0.5, "les trois remplissent la piste")
}

@Test("Une piste a un segment laisse le reste vide")
func aSingleSegmentLeavesTheRestEmpty() {
    // Le bloc `9d` : « synchronisation · 312 sur 1 284 ». Ce n'est pas un partage.
    let widths = ProgressMetrics.widths(
        of: [ProgressSegment(id: "sync", value: 312, role: .inProgress)],
        total: 1284,
        in: 1284)
    #expect(widths.count == 1)
    #expect(abs(widths[0] - 312) < 0.5)
}

@Test("Aucune largeur negative, aucune division par zero, aucun debordement")
func degenerateTotalsAreSafe() {
    func widths(_ value: Int, _ total: Int, _ available: CGFloat) -> [CGFloat] {
        ProgressMetrics.widths(
            of: [ProgressSegment(id: "x", value: value, role: .done)],
            total: total,
            in: available)
    }

    #expect(widths(5, 0, 100) == [0], "total nul")
    #expect(widths(0, 100, 100) == [0], "compte nul")
    #expect(widths(5, 100, 0) == [0], "piste de largeur nulle")
    #expect(widths(-5, 100, 100) == [0], "compte negatif")
    #expect(widths(150, 100, 100) == [100], "compte superieur au total")
}

// MARK: - Badge

@MainActor
@Test("Les trois teintes pleines portent le texte prevu pour elles")
func filledTonesUseTheOnAccentToken() {
    // Le prototype pose du `oklch(0.14 0 0)` sur l'ambre, sur le vert et sur le rouge :
    // c'est ce que `accent.onAccent` existe pour dire. Un texte clair n'y passerait pas
    // le contraste.
    //
    // `@MainActor` parce que `Tone` est imbrique dans une `View` : il herite de son
    // isolation. C'est l'autre facon de traiter ce que `ProgressMetrics` a resolu par
    // extraction — ici il n'y a pas d'arithmetique a extraire, seulement des jetons.
    for tone in [StateBadge.Tone.accent, .success, .danger] {
        #expect(tone.foreground == Color.accentOnAccent, "\(tone)")
    }
    #expect(StateBadge.Tone.onImage.foreground == Color.textPrimary)
    #expect(StateBadge.Tone.onImage.background == Color.chipOnImage)
}
