import DesignSystem
import SwiftUI

// Les valeurs attendues des champs de formulaire — `I7`, `I8`, `I9`.
//
// **Dans son propre fichier**, parce que `BlockSpecs.swift` a repassé 500 lignes en les
// accueillant, et que `file_length` a raison de le refuser. La coupure suit les lots : les
// composants d'affichage d'un côté, les champs de l'autre. C'est la deuxième fois que ce
// fichier se scinde, et ce sera la règle — un lot, un fichier de valeurs.

extension BlockSpec {

    static let fieldShell = BlockSpec(
        component: "FieldShell · les quatre marques d'erreur",
        source: "planche 6 blocs 8a et 8b · addendum 1 blocs 11a–11c, 11i",
        measures: [
            .init(name: "Hauteur de champ", expected: "28 pt dense, 38 pt ample", verdict: .matches),
            .init(name: "Rembourrage", expected: "9 × 11 pt", verdict: .matches),
            .init(name: "Fond", expected: "blanc à 8 % — bg.fill", verdict: .matches),
            .init(name: "Focus", expected: "trait bas 2 pt en accent", verdict: .matches),
            .init(
                name: "Marques d'erreur",
                expected: "quatre, jamais plus : libellé, trait, triangle dans le champ, message dessous",
                verdict: .matches),
            .init(
                name: "Épaisseur du trait d'erreur",
                expected: "2 pt (bloc 8a rendu) · 1 px (prose du §11a)",
                verdict: .keptAtToken(
                    gap: 18, code: "Stroke.emphasis, 2 pt",
                    reason: "Le bloc rendu gagne sur la prose de synthèse")),
            .init(
                name: "Requis vide",
                expected: "neutre — mention « Requis » en text.tertiary, aucune marque rouge",
                verdict: .matches),
            .init(
                name: "Champ valide au repos",
                expected: "aucune marque : ni coche, ni liseré",
                verdict: .matches),
            .init(
                name: "Récapitulatif de refus",
                expected: "dans le contenu, jamais en notification (11c)",
                verdict: .matches)
        ])

    static let precisionDate = BlockSpec(
        component: "PrecisionDateRow",
        source: "planche 6 · handoff §6",
        measures: [
            .init(name: "Crans", expected: "trois : année, mois, jour", verdict: .matches),
            .init(
                name: "Champs affichés",
                expected: "un, deux ou trois selon le cran",
                verdict: .matches),
            .init(
                name: "Bornes du jour",
                expected: "non spécifiées par le bloc",
                verdict: .keptAtToken(
                    gap: 19, code: "1 à 31, quel que soit le mois",
                    reason: """
                        Un 31 février se tape et se refuse par l'anatomie d'erreur. Un champ qui \
                        refuse la frappe ne dit pas pourquoi
                        """))
        ])

    static let tokenField = BlockSpec(
        component: "TokenFieldRow · ProfileColorPicker",
        source: "planche 6 bloc 8a · arbitrages tranchés, point 2",
        measures: [
            .init(name: "Jeton de valeur", expected: "5 × 8 pt, fond accent à 22 %", verdict: .matches),
            .init(
                name: "Création à la volée",
                expected: "« genre existant » quand la frappe correspond, « créer » sinon",
                verdict: .matches),
            .init(name: "Couleurs de profil", expected: "liste fermée", verdict: .matches),
            .init(
                name: "Pastille retenue",
                expected: "liseré clair 2 pt à l'extérieur, jamais l'ambre",
                verdict: .matches),
            .init(
                name: "Couleurs hors catalogue d'assets",
                expected: "non spécifié",
                verdict: .keptAtToken(
                    gap: 20, code: "littérales en displayP3, hors ColorTokens",
                    reason: """
                        Une couleur de profil est une valeur **persistée** que l'utilisateur \
                        choisit, pas un rôle de l'interface : elle ne doit pas suivre l'apparence
                        """))
        ])

}
