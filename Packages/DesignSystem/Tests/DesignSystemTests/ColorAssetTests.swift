import SwiftUI
import Testing

@testable import DesignSystem

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

// `Color("bg/canvas", bundle:)` ne signale pas un jeu absent : SwiftUI rend une
// couleur par défaut et l'app continue. Ces tests passent donc par AppKit /
// UIKit, dont les initialiseurs renvoient `nil` quand le jeu n'existe pas.
//
// La liste vient de ColorTokens.generated.swift, generee depuis le JSON de
// tokens : un token ajoute a la source est automatiquement couvert ici.

enum AssetCatalog {

    /// `true` si le jeu de couleurs existe dans le catalogue **compile**.
    static func contains(_ name: String) -> Bool {
        #if canImport(AppKit)
            NSColor(named: name, bundle: .designSystem) != nil
        #elseif canImport(UIKit)
            UIColor(named: name, in: .designSystem, compatibleWith: nil) != nil
        #else
            false
        #endif
    }

    /// SwiftPM copie `Colors.xcassets` tel quel : il ne lance pas `actool`, donc
    /// aucun `Assets.car` n'est produit et aucune couleur ne se resout sous
    /// `swift test`. Seul un build Xcode compile le catalogue. Les tests qui en
    /// dependent sont donc conditionnes — et la cible DesignSystemAssetTests du
    /// project.yml, elle, exige que le catalogue soit bien la (voir plus bas).
    static let isCompiled = contains("bg/canvas")

    static let skipReason: Comment = """
        Catalogue d'assets non compile : SwiftPM ne lance pas actool. \
        Ces verifications tournent sous xcodebuild, via la cible \
        DesignSystemAssetTests.
        """
}

@Test(
    "Les 59 Color Sets sont presents dans le catalogue compile",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func everyColorTokenResolves() {
    #expect(ColorTokens.all.count == 59)

    let missing = ColorTokens.all.filter { !AssetCatalog.contains($0) }
    #expect(missing.isEmpty, "Color Sets absents du .xcassets : \(missing.joined(separator: ", "))")
}

@Test(
    "La sonde detecte bien un jeu absent",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func probeDetectsAMissingColorSet() {
    // Contrôle négatif : sans lui, le test principal passerait tout aussi bien
    // si `AssetCatalog.contains` renvoyait `true` en toutes circonstances.
    #expect(AssetCatalog.contains("ceJeuDeCouleursNexistePas") == false)
}

#if XCODE_ASSET_TESTS
    @Test("Sous xcodebuild, le catalogue d'assets doit etre compile")
    func assetCatalogIsCompiledUnderXcode() {
        // Sans ce test, une regression qui empeche actool de tourner rendrait les
        // deux tests ci-dessus « skipped » — donc verts — au lieu d'echouer.
        #expect(
            AssetCatalog.isCompiled,
            "Colors.xcassets n'a pas ete compile : les couleurs ne se resoudront pas dans l'app."
        )
    }
#endif

// Ces deux-la ne touchent pas au catalogue compile : ils tournent partout.

@Test("Le decoupage primitives / semantiques est celui attendu")
func tokenListsHaveExpectedShape() {
    #expect(ColorTokens.primitives.count == 36)
    #expect(ColorTokens.semantics.count == 23)
    #expect(Set(ColorTokens.primitives).isDisjoint(with: Set(ColorTokens.semantics)))
    #expect(Set(ColorTokens.all).count == ColorTokens.all.count, "Nom de token en double")
}

@Test("Chaque semantique a un accesseur type", arguments: ColorTokens.semantics)
func semanticTokensAreReachableThroughTypedAccessors(token: String) {
    // Le catalogue et l'app passent par les accesseurs, jamais par la chaine.
    // Si un jeu existe mais n'a pas d'accesseur, il est inatteignable en pratique.
    #expect(ColorTokens.typedAccessor(for: token) != nil, "Pas d'accesseur type pour \(token)")
}
