import SwiftUI
import Testing

@testable import DesignSystem

// Tests de rendu sur PosterCard et ShelfRail, avec `ImageRenderer` — livré avec
// SwiftUI, donc aucune bibliothèque de snapshot ajoutée.
//
// Pas d'images de référence : elles se périment au premier changement de police
// système et personne ne les relit. Ces tests vérifient plutôt des propriétés
// que le rendu doit tenir, et qui cassent pour de vraies raisons :
//
//   - chaque combinaison produit une image (pas de crash, pas de taille nulle) ;
//   - clair et sombre donnent des pixels différents — si une couleur était
//     codée en dur, les deux rendus seraient identiques ;
//   - AX3 rend plus haut que la taille normale — preuve que Dynamic Type
//     traverse réellement le composant ;
//   - compact < medium < large en largeur.
//
// Ils ont besoin d'un Colors.xcassets compilé : sous `swift test` ils se
// mettent en « skipped » (cf. ColorAssetTests), et tournent pour de vrai dans
// la cible DesignSystemAssetTests.

/// Ce qu'on retient d'un rendu : sa taille et une empreinte de ses pixels.
private struct Render {
    let width: Int
    let height: Int
    let fingerprint: Int
}

@MainActor
private func render(
    _ content: some View,
    scheme: ColorScheme,
    typeSize: DynamicTypeSize = .large,
    width: CGFloat = 420
) -> Render? {
    let renderer = ImageRenderer(
        content:
            content
            .frame(width: width)
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, typeSize)
            .background(.bgCanvas)
    )
    renderer.scale = 1

    guard let image = renderer.cgImage,
        let data = image.dataProvider?.data as Data?
    else { return nil }

    // FNV-1a : il ne s'agit pas de sécurité, seulement de distinguer deux rendus.
    var hash = 14_695_981_039_346_656_037 as UInt64
    for byte in data {
        hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }

    return Render(width: image.width, height: image.height, fingerprint: Int(bitPattern: UInt(hash)))
}

private let schemes: [ColorScheme] = [.light, .dark]
private let typeSizes: [DynamicTypeSize] = [.large, .accessibility3]

/// `ImageRenderer` honore-t-il `dynamicTypeSize` sur cette plateforme ?
///
/// Mesuré, pas supposé : sur macOS, un simple `Text().font(.body)` rend
/// exactement la même hauteur à `.large`, `AX3` et `AX5` — macOS n'a pas
/// Dynamic Type. Les assertions de croissance ne veulent donc rien dire là-bas.
/// Sur iOS elles passent, et c'est là qu'elles ont un sens.
///
/// `macOSStillIgnoresDynamicType`, plus bas, échoue le jour où ça change : on
/// saura qu'il faut réactiver les tests ici plutôt que de découvrir six mois
/// plus tard qu'on ne testait plus rien.
private let rendererHonoursDynamicType: Bool = {
    #if os(macOS)
        false
    #else
        true
    #endif
}()

private let dynamicTypeSkipReason: Comment = """
    ImageRenderer ignore dynamicTypeSize sur macOS : ces assertions ne tournent \
    que sur iOS.
    """

// MARK: - PosterCard

@MainActor
@Test(
    "PosterCard se rend dans toutes les combinaisons thème × taille × Dynamic Type",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    arguments: schemes, CardSize.allCases
)
func posterCardRenders(scheme: ColorScheme, size: CardSize) throws {
    for typeSize in typeSizes {
        let card = PosterCard(.sample, metrics: .metrics(.portrait, size))
        let result = try #require(
            render(card, scheme: scheme, typeSize: typeSize),
            "Rendu impossible : \(scheme) / \(size) / \(typeSize)"
        )

        #expect(result.width > 0)
        #expect(result.height > 0)
    }
}

@MainActor
@Test(
    "PosterCard : clair et sombre ne rendent pas la même chose",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    arguments: CardSize.allCases
)
func posterCardDiffersBetweenSchemes(size: CardSize) throws {
    let card = PosterCard(.sample, metrics: .metrics(.portrait, size))
    let light = try #require(render(card, scheme: .light))
    let dark = try #require(render(card, scheme: .dark))

    // Une couleur codée en dur rendrait ces deux empreintes identiques.
    #expect(
        light.fingerprint != dark.fingerprint,
        "Le rendu clair et le rendu sombre sont identiques en \(size) : une couleur ne suit pas le thème."
    )
}

@MainActor
@Test(
    "PosterCard grandit avec Dynamic Type",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    .enabled(if: rendererHonoursDynamicType, dynamicTypeSkipReason),
    arguments: CardSize.allCases
)
func posterCardGrowsWithDynamicType(size: CardSize) throws {
    let card = PosterCard(.sample, metrics: .metrics(.portrait, size))
    let normal = try #require(render(card, scheme: .dark, typeSize: .large))
    let ax3 = try #require(render(card, scheme: .dark, typeSize: .accessibility3))

    #expect(
        ax3.height > normal.height,
        "En \(size), AX3 rend la même hauteur qu'en taille normale : Dynamic Type ne traverse pas le composant."
    )
}

@MainActor
@Test(
    "Les trois tailles de carte se distinguent",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func cardSizesAreOrdered() throws {
    // Rendues sans largeur imposée, pour mesurer la carte elle-même.
    func height(_ size: CardSize) throws -> Int {
        let card = PosterCard(.sample, metrics: .metrics(.portrait, size))
        return try #require(render(card, scheme: .dark, width: 400)).height
    }

    #expect(try height(.compact) < height(.medium))
    #expect(try height(.medium) < height(.large))
}

// MARK: - ShelfRail

@MainActor
@Test(
    "ShelfRail se rend dans toutes les combinaisons thème × Dynamic Type",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    arguments: schemes, typeSizes
)
func shelfRailRenders(scheme: ColorScheme, typeSize: DynamicTypeSize) throws {
    for size in CardSize.allCases {
        let rail = ShelfRail(.sample, metrics: .metrics(.portrait, size))
        let result = try #require(
            render(rail, scheme: scheme, typeSize: typeSize, width: 640),
            "Rendu impossible : \(scheme) / \(size) / \(typeSize)"
        )

        #expect(result.width > 0)
        #expect(result.height > 0)
    }
}

@MainActor
@Test(
    "ShelfRail : clair et sombre ne rendent pas la même chose",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func shelfRailDiffersBetweenSchemes() throws {
    let rail = ShelfRail(.sample)
    let light = try #require(render(rail, scheme: .light, width: 640))
    let dark = try #require(render(rail, scheme: .dark, width: 640))

    #expect(light.fingerprint != dark.fingerprint)
}

@MainActor
@Test(
    "ShelfRail grandit avec Dynamic Type",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    .enabled(if: rendererHonoursDynamicType, dynamicTypeSkipReason)
)
func shelfRailGrowsWithDynamicType() throws {
    let rail = ShelfRail(.sample)
    let normal = try #require(render(rail, scheme: .dark, typeSize: .large, width: 640))
    let ax3 = try #require(render(rail, scheme: .dark, typeSize: .accessibility3, width: 640))

    #expect(ax3.height > normal.height)
}

// MARK: - Controle negatif

@MainActor
@Test(
    "L'empreinte distingue bien deux rendus differents",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func fingerprintDistinguishesDifferentRenders() throws {
    // Sans ce controle, les tests « clair != sombre » passeraient tout aussi
    // bien si l'empreinte etait constante.
    let one = try #require(render(Text("un").font(Typo.body), scheme: .dark, width: 200))
    let other = try #require(render(Text("deux").font(Typo.body), scheme: .dark, width: 200))

    #expect(one.fingerprint != other.fingerprint)

    // Et deux rendus identiques doivent donner la meme empreinte.
    let again = try #require(render(Text("un").font(Typo.body), scheme: .dark, width: 200))
    #expect(one.fingerprint == again.fingerprint)
}

#if os(macOS)

    @MainActor
    @Test(
        "Sur macOS, ImageRenderer ignore toujours dynamicTypeSize",
        .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
    )
    func macOSStillIgnoresDynamicType() throws {
        // Sentinelle : ce test verrouille la raison pour laquelle les assertions
        // de croissance sont desactivees sur macOS. S'il echoue, c'est une bonne
        // nouvelle — il faut reactiver `rendererHonoursDynamicType` partout.
        let text = Text("Un titre assez long pour occuper plusieurs lignes").font(Typo.body)
        let normal = try #require(render(text, scheme: .dark, typeSize: .large, width: 300))
        let ax5 = try #require(render(text, scheme: .dark, typeSize: .accessibility5, width: 300))

        #expect(
            normal.height == ax5.height,
            """
            ImageRenderer honore desormais Dynamic Type sur macOS : passer \
            `rendererHonoursDynamicType` a `true` et reactiver les assertions.
            """
        )
    }

#endif
