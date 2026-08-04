import SwiftUI
import Testing

@testable import DesignSystem

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

// MARK: - Symboles
//
// Un nom de SF Symbol faux ne casse pas la compilation : `Image(systemName:)`
// accepte n'importe quelle chaine et rend un carre vide. Meme classe de
// defaillance silencieuse que `Color(_:bundle:)` et que `Font.custom`, et meme
// remede : passer par l'API qui renvoie `nil`.

/// `true` si le symbole existe sur la plateforme courante.
private func symbolExists(_ name: String) -> Bool {
    #if canImport(AppKit)
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    #elseif canImport(UIKit)
        UIImage(systemName: name) != nil
    #else
        false
    #endif
}

@Test("Chaque symbole de la correspondance existe", arguments: Icon.all)
func iconSymbolsExist(symbol: String) {
    #expect(symbolExists(symbol), "SF Symbol inconnu : \(symbol) — rendra un carre vide")
}

@Test("La sonde detecte bien un symbole inconnu")
func symbolProbeDetectsAnUnknownName() {
    // Controle negatif : sans lui, le test ci-dessus passerait tout aussi bien si
    // `symbolExists` renvoyait toujours `true`.
    #expect(symbolExists("ceSymboleNexistePas.vraiment") == false)
}

@Test("La liste des symboles n'a pas de doublon")
func iconListHasNoDuplicate() {
    // `Icon.all` est ecrite a la main — Swift n'enumere pas les membres statiques
    // d'un enum sans cas — donc un copier-coller peut y glisser deux fois le meme.
    #expect(Set(Icon.all).count == Icon.all.count)
    #expect(Icon.all.count == 37)
}

// MARK: - Affiches et matrice

@Test("Les six crans sont ceux de la planche 8")
func posterScalesMatchTheHandoff() {
    #expect(PosterScale.allCases.map(\.width) == [32, 56, 92, 140, 200, 280])
}

@Test("Le ratio derive la hauteur, 2:3 en portrait et 16:9 en paysage")
func posterRatiosAreCorrect() {
    let portrait = PosterScale.m.size(.portrait)
    #expect(portrait.width == 92)
    #expect(abs(portrait.height - 138) < 0.001, "2:3 attendu, hauteur \(portrait.height)")

    let landscape = PosterScale.m.size(.landscape)
    #expect(landscape.width == 92)
    #expect(abs(landscape.height - 51.75) < 0.001, "16:9 attendu, hauteur \(landscape.height)")

    // Le 3:2 a ete explicitement ecarte par le design : 8 % plus haut que le 16:9 a
    // largeur egale, invisible en rangee, mais desaligne du fond de hero. S'il
    // reapparait, c'est que quelqu'un a repris `Ratio.landscape` de l'ancienne
    // direction au lieu de `CardLayout.aspectRatio`.
    #expect(CardLayout.landscape.aspectRatio != 3.0 / 2.0)
}

@Test("La matrice complete, contexte par contexte", arguments: PosterContext.allCases)
func matrixCoversEveryContext(context: PosterContext) {
    // Les trois crans d'un contexte sont strictement croissants : une taille
    // « large » qui rendrait une carte plus petite que « medium » serait un
    // reglage sans effet visible, donc un bug qu'aucune compilation n'attrape.
    let scales = context.scales
    #expect(scales.compact.width < scales.medium.width)
    #expect(scales.medium.width < scales.large.width)

    // Et le reglage par defaut du contexte designe bien un de ces trois crans.
    let byDefault = context.defaultSetting
    #expect(context.scale(for: byDefault.size).width > 0)
}

@Test("Les correspondances de la table du handoff, une a une")
func matrixMatchesTheHandoffTable() {
    // Recopiees depuis la section 5 du handoff. Ce test existe pour qu'une faute
    // de frappe dans `scales` se voie ici et pas a l'ecran six mois plus tard.
    // Valeur nommee et non tuple a quatre membres : `large_tuple` l'interdit, et la
    // convention du depot est de nommer plutot que de desactiver la regle.
    struct Row {
        let context: PosterContext
        let compact: PosterScale
        let medium: PosterScale
        let large: PosterScale
    }

    let expected: [Row] = [
        Row(context: .homeTitles, compact: .m, medium: .l, large: .xl),
        Row(context: .homePeople, compact: .s, medium: .m, large: .l),
        Row(context: .homeCollections, compact: .m, medium: .l, large: .xl),
        Row(context: .homeSocial, compact: .s, medium: .m, large: .l),
        Row(context: .titles, compact: .m, medium: .l, large: .xxl),
        Row(context: .people, compact: .s, medium: .m, large: .xl),
        Row(context: .collections, compact: .m, medium: .l, large: .xxl),
        Row(context: .socialFeed, compact: .m, medium: .l, large: .xl)
    ]

    #expect(expected.count == PosterContext.allCases.count, "Un contexte n'est pas couvert")

    for row in expected {
        #expect(row.context.scale(for: .compact) == row.compact, "\(row.context.rawValue) compact")
        #expect(row.context.scale(for: .medium) == row.medium, "\(row.context.rawValue) medium")
        #expect(row.context.scale(for: .large) == row.large, "\(row.context.rawValue) large")
    }
}

@Test("Les defauts par contexte sont ceux du handoff")
func defaultSettingsMatchTheHandoff() {
    #expect(PosterContext.homeTitles.defaultSetting == PosterSetting(layout: .portrait, size: .medium))
    #expect(PosterContext.homePeople.defaultSetting == PosterSetting(layout: .portrait, size: .compact))
    #expect(PosterContext.homeCollections.defaultSetting == PosterSetting(layout: .landscape, size: .medium))
    #expect(PosterContext.homeSocial.defaultSetting == PosterSetting(layout: .landscape, size: .compact))
    #expect(PosterContext.titles.defaultSetting == PosterSetting(layout: .portrait, size: .medium))
    #expect(PosterContext.people.defaultSetting == PosterSetting(layout: .portrait, size: .compact))
    #expect(PosterContext.collections.defaultSetting == PosterSetting(layout: .landscape, size: .medium))
    #expect(PosterContext.socialFeed.defaultSetting == PosterSetting(layout: .landscape, size: .medium))
}

// MARK: - Metriques

@Test("L'echelle d'espacement est en base 4")
func spacingScaleIsBaseFour() {
    let scale = [Space.s1, Space.s2, Space.s3, Space.s4, Space.s5, Space.s6, Space.s7, Space.s8]
    #expect(scale == [4, 8, 12, 16, 24, 32, 48, 64])
    #expect(Space.minHitTarget == 44, "Contrainte d'accessibilite, pas un choix de design")
}

@Test("Les rayons sont ceux du handoff, et `none` vaut zero")
func radiiMatchTheHandoff() {
    #expect(Radius.none == 0, "Tout ce qui est photographique n'a aucun rayon")
    #expect(Radius.xs == 2)
    #expect(Radius.s == 4)
    #expect(Radius.m == 10)
    #expect(Radius.l == 14)

    // `radius.sheet` depend de la plateforme : coins hauts arrondis sur iOS,
    // dialogue a angles francs sur macOS.
    #if os(macOS)
        #expect(Radius.sheet == Radius.none)
    #else
        #expect(Radius.sheet == Radius.l)
    #endif
}

@Test("La densite a deux crans, et le cran ample est partout plus grand")
func densityHasTwoStepsAndRoomyIsLarger() {
    #expect(Density.allCases.count == 2, "Deux crans, pas trois : docs/03 a ete corrige")

    let dense = Density.dense
    let roomy = Density.roomy
    #expect(dense.rowHeight < roomy.rowHeight)
    #expect(dense.toolbarHeight < roomy.toolbarHeight)
    #expect(dense.screenMargin < roomy.screenMargin)
    #expect(dense.formSpacing < roomy.formSpacing)
    #expect(dense.fieldHeight < roomy.fieldHeight)
    #expect(dense.baseGridGutter < roomy.baseGridGutter)
    #expect(dense.bodyLeading < roomy.bodyLeading)

    // La cible tactile de 44 pt doit etre atteignable meme en dense : c'est une
    // contrainte d'accessibilite, et une ligne de 28 pt ne la satisfait pas seule.
    #expect(roomy.rowHeight >= Space.minHitTarget)

    #if os(macOS)
        #expect(Density.platformDefault == .dense)
    #else
        #expect(Density.platformDefault == .roomy)
    #endif
}

@Test("Les traits : une epaisseur, et l'entorse nommee")
func strokesAreOneAndAnException() {
    #expect(Stroke.hairline == 1)
    #expect(Stroke.emphasis == 2)
}

@Test("Les plans sont ordonnes, et la notification est au-dessus de tout")
func layersAreOrdered() {
    let ordered = [
        Layer.content, Layer.sticky, Layer.menu, Layer.scrim,
        Layer.modal, Layer.viewer, Layer.notification
    ]
    #expect(ordered == ordered.sorted(), "L'ordre de superposition est l'ordre des valeurs")
    #expect(Layer.notification == ordered.max())
    #expect(Layer.viewer > Layer.modal, "La visionneuse passe au-dessus d'une feuille")
}

@Test(
    "Le point de rupture se deduit de la largeur de fenetre",
    arguments: [
        (CGFloat(320), Breakpoint.phonePortrait),
        (429, .phonePortrait),
        (430, .phoneLandscape),
        (743, .phoneLandscape),
        (744, .padPortrait),
        (1023, .padPortrait),
        (1024, .padLandscape),
        (1279, .padLandscape),
        (1280, .macStandard),
        (1679, .macStandard),
        (1680, .macWide),
        (3000, .macWide)
    ]
)
func breakpointsResolveFromWidth(width: CGFloat, expected: Breakpoint) {
    #expect(Breakpoint.forWidth(width) == expected, "\(width) pt")
}

@Test("L'inspecteur n'est jamais une colonne sous 1024 pt")
func inspectorIsASheetBelowPadLandscape() {
    #expect(Breakpoint.phonePortrait.showsInspectorAsColumn == false)
    #expect(Breakpoint.phoneLandscape.showsInspectorAsColumn == false)
    #expect(Breakpoint.padPortrait.showsInspectorAsColumn == false)
    #expect(Breakpoint.padLandscape.showsInspectorAsColumn)
    #expect(Breakpoint.macStandard.showsInspectorAsColumn)
    #expect(Breakpoint.macWide.showsInspectorAsColumn)
}

// Le compte de colonnes n'est plus une propriete de `Breakpoint` : il se calcule, et
// ses tests sont dans `GridMetricsTests`. Voir la note en tete de `GridMetrics.swift`.

@Test("Seul macWide desaccorde la gouttiere de la densite")
func macWideWidensTheGutter() {
    // `docs/design/README.md` §4.6 : « ≥ 1680 · marges 64, gouttiere 24 », alors que la
    // densite par defaut du Mac est dense, donc 16.
    #expect(Breakpoint.macWide.gridGutter(.dense) == 24)
    #expect(Breakpoint.macStandard.gridGutter(.dense) == 16)
    #expect(Breakpoint.macStandard.gridGutter(.roomy) == 24)
    for cran in Breakpoint.allCases where cran != .macWide {
        #expect(cran.gridGutter(.dense) == Density.dense.baseGridGutter, "\(cran.rawValue)")
        #expect(cran.gridGutter(.roomy) == Density.roomy.baseGridGutter, "\(cran.rawValue)")
    }
}

// MARK: - Typographie

@Test("Les onze roles ont les tailles de la planche 8")
func typeSizesMatchTheHandoff() {
    #expect(Typo.Size.display == 56)
    #expect(Typo.Size.title1 == 34)
    #expect(Typo.Size.title2 == 22)
    #expect(Typo.Size.headline == 15)
    #expect(Typo.Size.body == 15)
    #expect(Typo.Size.callout == 13)
    #expect(Typo.Size.label == 11)
    #expect(Typo.Size.action == 12)
    #expect(Typo.Size.meta == 11)
    #expect(Typo.Size.numeric == 12)
    #expect(Typo.Size.micro == 10)
}

@Test("Le titrage bascule a la premiere taille d'accessibilite")
func titlingSwitchesAtTheFirstAccessibilitySize() {
    // La planche 8 ecrit `.accessibilityMedium`, qui est le nom `ContentSizeCategory`
    // de cette taille ; dans `DynamicTypeSize` elle s'appelle `.accessibility1`.
    #expect(DynamicTypeSize.xxLarge.usesAccessibleTitling == false)
    #expect(DynamicTypeSize.xxxLarge.usesAccessibleTitling == false)
    #expect(DynamicTypeSize.accessibility1.usesAccessibleTitling)
    #expect(DynamicTypeSize.accessibility5.usesAccessibleTitling)
}

@Test("L'interlignage ne demande jamais un espacement negatif")
func leadingNeverAsksForNegativeSpacing() {
    // `.lineSpacing()` ajoute de l'espace, il ne sait pas resserrer : un ratio sous
    // l'interligne naturel de la police doit rendre 0, pas une valeur negative.
    #expect(Typo.Leading.spacing(for: Typo.Leading.display, at: Typo.Size.display) == 0)
    #expect(Typo.Leading.spacing(for: Typo.Leading.body, at: Typo.Size.body) > 0)
    #expect(Typo.Leading.spacing(for: 0.5, at: 100) == 0)
}
