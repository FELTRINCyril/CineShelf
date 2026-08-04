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

// Les deux sondes sont des `let` globales, donc calculées **une seule fois** par
// exécution (`swift_once`, sûr entre threads) et non à chaque instance de test.
//
// Ce n'est pas une optimisation. Demander à CoreText un nom de police inconnu
// déclenche une résolution par XPC vers `libFontRegistry`, et le gestionnaire
// d'auto-activation qui va avec. swift-testing exécute les cas paramétrés en
// parallèle : à quatre fontes ça passait, à onze les appels XPC concurrents se
// bloquent mutuellement et la suite ne rend jamais la main — observé, dix minutes
// à 0 % de processeur, la pile entière en attente dans `XTypeXPCClient run:`.

/// Famille de la police système (`.AppleSystemUIFont`).
private let systemFamilyName: String = {
    guard let font = CTFontCreateUIFontForLanguage(.system, 20, nil) else { return "" }
    return CTFontCopyFamilyName(font) as String
}()

/// Famille sur laquelle CoreText retombe quand le nom demandé n'existe pas.
///
/// Mesurée, pas supposée : `CTFontCreateWithName` ne retombe pas sur la police
/// système mais sur Helvetica. Coder « Helvetica » en dur rendrait ces tests
/// faux le jour où la plateforme change de repli — d'où la sonde.
private let fallbackFamilyName: String = {
    let font = CTFontCreateWithName("CeNomDePoliceNexistePas-Regular" as CFString, 20, nil)
    return CTFontCopyFamilyName(font) as String
}()

@Test("Chaque fichier de police embarqué est présent dans le bundle")
func embeddedFontFilesArePresent() {
    for face in DesignSystemFonts.Face.allCases {
        let url = Bundle.designSystem.url(forResource: face.fileName, withExtension: "ttf")
        #expect(url != nil, "Fichier manquant : \(face.fileName).ttf")
    }
}

@Test("L'enregistrement des polices ne remonte aucune erreur")
func registrationReportsNoError() throws {
    // Le test ci-dessus vérifie que les fichiers sont là ; celui-ci vérifie que
    // CoreText les a **acceptés**. Un .ttf tronqué, corrompu ou dans un format
    // refusé est présent dans le bundle et échoue quand même à s'enregistrer :
    // sans ce test, le seul symptôme serait une typographie absente à l'écran.
    DesignSystemFonts.register()

    let report = try #require(
        DesignSystemFonts.registrationReport,
        "register() n'a produit aucun compte rendu"
    )

    #expect(
        report.missingFiles.isEmpty,
        "Fichiers de police introuvables : \(report.missingFiles.joined(separator: ", "))"
    )
    #expect(
        report.errors.isEmpty,
        "CoreText a refusé des polices : \(report.errors.joined(separator: " | "))"
    )
    // Sans ce contrôle, un rapport lu trop tôt — CoreText n'ayant pas encore
    // signalé la fin — passerait pour propre alors qu'il est seulement vide.
    #expect(report.isComplete, "CoreText n'a pas signalé la fin de l'enregistrement")
    #expect(report.isClean)
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
        resolvedFamily != fallbackFamilyName,
        """
        \(face.postScriptName) est retombé sur la police de repli \
        (\(fallbackFamilyName)). Le nom PostScript est faux, ou \
        \(face.fileName).ttf n'est pas dans le bundle.
        """
    )
    #expect(
        resolvedFamily != systemFamilyName,
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
    let fallback = fallbackFamilyName

    #expect(fallback.isEmpty == false)
    for face in DesignSystemFonts.Face.allCases {
        #expect(fallback != face.familyName)
    }
}

@Test("Les cinq familles du handoff sont embarquees et distinctes")
func theFiveFamiliesAreDistinct() {
    DesignSystemFonts.register()

    let families = Set(DesignSystemFonts.Face.allCases.map(\.familyName))
    // Cinq familles pour la direction courante, plus « Archivo SemiExpanded » que
    // seul le banc d'essai lit.
    #expect(
        families.isSuperset(of: [
            "Bebas Neue", "Archivo", "Archivo Narrow", "Public Sans", "IBM Plex Mono"
        ]))

    // Archivo et Archivo Narrow sont deux familles, pas deux graisses de la meme :
    // `Font.custom` n'a aucun axe de variation, la chasse doit venir du fichier.
    #expect(
        DesignSystemFonts.Face.archivoSemiBold.familyName
            != DesignSystemFonts.Face.narrowSemiBold.familyName
    )
}

@Test(
    "Le nom PostScript n'est pas devinable depuis le nom de fichier",
    arguments: [
        (DesignSystemFonts.Face.plexMono, "IBMPlexMono", "IBMPlexMono-Regular"),
        (DesignSystemFonts.Face.plexMonoMedium, "IBMPlexMono-Medm", "IBMPlexMono-Medium")
    ]
)
func postScriptNamesDivergeFromFileNames(
    face: DesignSystemFonts.Face,
    postScript: String,
    file: String
) {
    // Les deux IBM Plex Mono sont le contre-exemple qui justifie de relever chaque
    // nom sur le fichier reel : le Regular n'a pas de suffixe et le Medium est
    // abrege en « Medm ». Ecrits « comme on les attend », `Font.custom` serait
    // retombe sur Helvetica sans que rien ne le signale.
    #expect(face.postScriptName == postScript)
    #expect(face.fileName == file)
    #expect(face.postScriptName != face.fileName)
}

@Test("register() est idempotent")
func registerIsIdempotent() {
    DesignSystemFonts.register()
    DesignSystemFonts.register()

    let font = CTFontCreateWithName(
        DesignSystemFonts.Face.bebas.postScriptName as CFString, 20, nil)
    #expect(CTFontCopyFamilyName(font) as String == "Bebas Neue")
}
