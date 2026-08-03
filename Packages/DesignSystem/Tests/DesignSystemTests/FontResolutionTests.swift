import CoreText
import SwiftUI
import Testing

@testable import DesignSystem

// `Font.custom` ne signale jamais un nom PostScript inconnu : il retombe
// silencieusement sur une autre police. Un `Archivo-SemiBold` mal orthographié,
// un fichier oublié dans le bundle, un renommage amont — et l'app compile,
// s'affiche, passe les tests visuels, mais n'a plus sa typographie. C'est le
// pire mode de défaillance possible : invisible.
//
// Ces tests comparent donc la famille réellement résolue à la famille attendue,
// et vérifient qu'elle n'est ni la police système, ni la police de repli.

/// Famille de la police système (`.AppleSystemUIFont`).
private func systemFamilyName() -> String {
    guard let font = CTFontCreateUIFontForLanguage(.system, 20, nil) else { return "" }
    return CTFontCopyFamilyName(font) as String
}

/// Famille sur laquelle CoreText retombe quand le nom demandé n'existe pas.
///
/// Mesurée, pas supposée : `CTFontCreateWithName` ne retombe pas sur la police
/// système mais sur Helvetica. Coder « Helvetica » en dur rendrait ces tests
/// faux le jour où la plateforme change de repli — d'où la sonde.
private func fallbackFamilyName() -> String {
    let font = CTFontCreateWithName("CeNomDePoliceNexistePas-Regular" as CFString, 20, nil)
    return CTFontCopyFamilyName(font) as String
}

@Test("Chaque fichier de police embarqué est présent dans le bundle")
func embeddedFontFilesArePresent() {
    for face in DesignSystemFonts.Face.allCases {
        let url = Bundle.designSystem.url(forResource: face.fileName, withExtension: "ttf")
        #expect(url != nil, "Fichier manquant : \(face.fileName).ttf")
    }
}

@Test(
    "Chaque police custom se résout sur sa vraie famille",
    arguments: DesignSystemFonts.Face.allCases
)
func customFontResolvesToItsOwnFamily(face: DesignSystemFonts.Face) {
    DesignSystemFonts.register()

    let font = CTFontCreateWithName(face.postScriptName as CFString, 20, nil)
    let resolvedFamily = CTFontCopyFamilyName(font) as String
    let resolvedPostScript = CTFontCopyPostScriptName(font) as String

    // Les deux assertions qui attrapent un repli silencieux.
    #expect(
        resolvedFamily != fallbackFamilyName(),
        """
        \(face.postScriptName) est retombé sur la police de repli \
        (\(fallbackFamilyName())). Le nom PostScript est faux, ou \
        \(face.fileName).ttf n'est pas dans le bundle.
        """
    )
    #expect(
        resolvedFamily != systemFamilyName(),
        "\(face.postScriptName) est retombé sur la police système."
    )

    // L'assertion qui verrouille : la bonne famille, à la bonne chasse.
    #expect(
        resolvedFamily == face.familyName,
        "\(face.postScriptName) : famille résolue « \(resolvedFamily) », attendue « \(face.familyName) »"
    )
    #expect(
        resolvedPostScript == face.postScriptName,
        "Nom PostScript résolu « \(resolvedPostScript) », attendu « \(face.postScriptName) »"
    )
}

@Test("La sonde de repli detecte bien un nom inconnu")
func fallbackProbeActuallyDetectsAnUnknownName() {
    // Contrôle négatif : sans lui, le test précédent pourrait passer pour une
    // raison qui n'a rien à voir avec la résolution des polices.
    let fallback = fallbackFamilyName()

    #expect(fallback.isEmpty == false)
    for face in DesignSystemFonts.Face.allCases {
        #expect(fallback != face.familyName)
    }
}

@Test("Les deux chasses sont des familles distinctes")
func widthVariantsAreSeparateFamilies() {
    DesignSystemFonts.register()

    #expect(
        DesignSystemFonts.Face.displaySemiBold.familyName
            != DesignSystemFonts.Face.displayExpandedSemiBold.familyName
    )

    // `wdth` 112 de docs/01 §B.2 correspond au cran 112,5 d'Archivo, dont le
    // nom de famille est « SemiExpanded ». « Archivo Expanded » est le cran 125.
    #expect(DesignSystemFonts.Face.displayExpandedSemiBold.familyName == "Archivo SemiExpanded")
}

@Test("register() est idempotent")
func registerIsIdempotent() {
    DesignSystemFonts.register()
    DesignSystemFonts.register()

    let font = CTFontCreateWithName(
        DesignSystemFonts.Face.displayExpandedExtraBold.postScriptName as CFString, 20, nil)
    #expect(CTFontCopyFamilyName(font) as String == "Archivo SemiExpanded")
}
