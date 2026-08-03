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

// MARK: - Le chemin que les vues empruntent reellement
//
// Les tests ci-dessus verifient que les *noms* de `ColorTokens.all` existent
// dans le catalogue. Ils ne verifient pas que les accesseurs publics y sont
// correctement cables : un accesseur pointant a cote compilerait, laisserait la
// liste de tokens juste, et ferait rendre du transparent a toutes les vues sans
// qu'un seul test bronche. C'est ce trou que les tests suivants ferment.
//
// La chaine d'un token ne vit plus qu'a un seul endroit — le bloc
// `extension ColorTokens` de ColorTokens.generated.swift — donc une faute de
// frappe ne peut plus se glisser dans un chemin sans l'autre. Ces tests restent
// utiles pour autant : ils verifient le cablage lui-meme (les deux extensions
// referencent-elles bien la bonne source ?) et surtout que le catalogue compile
// resout, ce qu'aucune relecture de code ne peut prouver.
//
// La sonde est l'alpha : un jeu absent ne rend pas « une couleur par defaut »,
// il rend transparent (mesure : 0.0000/0.0000/0.0000 a=0.00). Et comme les deux
// resolutions tournent dans le meme process, donc sous la meme apparence, leurs
// composantes doivent coincider exactement — la comparaison ne depend ni du
// theme clair/sombre ni du contraste eleve.

/// Les composantes sRGB d'une couleur, telles qu'une vue les rendrait.
private struct Components: CustomStringConvertible, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    /// Un jeu de couleurs absent rend transparent : c'est la seule signature
    /// fiable d'une resolution ratee, `Color(_:bundle:)` ne signalant rien.
    var isTransparent: Bool { alpha == 0 }

    /// Tolerance large : deux resolutions du meme jeu dans le meme process
    /// doivent coincider au bit pres, l'epsilon ne couvre que l'aller-retour
    /// par l'espace colorimetrique.
    func matches(_ other: Components) -> Bool {
        abs(red - other.red) < 0.0001
            && abs(green - other.green) < 0.0001
            && abs(blue - other.blue) < 0.0001
            && abs(alpha - other.alpha) < 0.0001
    }

    var description: String {
        String(format: "%.4f/%.4f/%.4f a=%.2f", red, green, blue, alpha)
    }
}

/// Les composantes d'une `Color`, ou `nil` si la plateforme n'expose pas de
/// conversion vers une couleur concrete.
private func components(of color: Color) -> Components? {
    #if canImport(AppKit)
        guard let resolved = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        return Components(
            red: resolved.redComponent,
            green: resolved.greenComponent,
            blue: resolved.blueComponent,
            alpha: resolved.alphaComponent
        )
    #elseif canImport(UIKit)
        var red = 0 as CGFloat
        var green = 0 as CGFloat
        var blue = 0 as CGFloat
        var alpha = 0 as CGFloat
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return Components(red: red, green: green, blue: blue, alpha: alpha)
    #else
        nil
    #endif
}

@Test(
    "Aucune semantique ne retombe sur un defaut",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    arguments: ColorTokens.semantics
)
@MainActor
func semanticColorsDoNotFallBackToADefault(token: String) throws {
    let accessor = try #require(
        ColorTokens.typedAccessor(for: token),
        "Pas d'accesseur type pour \(token)"
    )
    let rendered = try #require(components(of: accessor), "Conversion indisponible pour \(token)")

    // Premier filet : un jeu introuvable rend transparent. Aucune semantique du
    // catalogue n'est translucide, donc alpha nul == resolution ratee.
    #expect(
        rendered.isTransparent == false,
        """
        \(token) rend transparent : l'accesseur type ne pointe sur aucun Color \
        Set. Verifier le bloc `extension ColorTokens` de ColorTokens.generated.swift.
        """
    )

    // Second filet, le plus serre : l'accesseur et le nom du token doivent
    // designer le meme jeu.
    let byName = try #require(components(of: Color(token, bundle: .designSystem)))
    #expect(
        rendered.matches(byName),
        """
        \(token) : `extension Color` rend \(rendered), le jeu nomme rend \(byName). \
        L'accesseur ne pointe pas sur le bon token — verifier ColorTokens.generated.swift.
        """
    )
}

// `typedAccessor(for:)` traverse `extension Color`, et rien d'autre : Swift
// prefere le membre du type concret au membre d'extension de protocole, donc
// `Color.bgCanvas` n'atteint jamais `extension ShapeStyle where Self == Color`.
// Or c'est celle-la que `.background(.bgCanvas)` emprunte — la forme que les
// vues ecrivent le plus. Verifie par experience : avant la generation, une faute
// de frappe dans la version ShapeStyle passait tous les tests.
//
// Le parametre `some ShapeStyle` ci-dessous force la resolution vers
// l'extension de protocole. La liste est ecrite a la main ici, et c'est voulu :
// une liste generee depuis la meme source que le code teste ne prouverait rien.
// `shapeStyleListIsExhaustive` la garde alignee sur ColorTokens.semantics.

private func viaShapeStyle(_ style: some ShapeStyle) -> Color? { style as? Color }

/// Les paires exploitables, indexees par token. Une entree qui aurait rendu
/// `nil` disparait ici, et `shapeStyleListIsExhaustive` la signale.
private let shapeStyleAccessors = Dictionary(
    uniqueKeysWithValues: shapeStylePairs.compactMap { token, color in
        color.map { (token, $0) }
    }
)

private let shapeStylePairs: [(String, Color?)] = [
    ("bg/canvas", viaShapeStyle(.bgCanvas)),
    ("bg/surface", viaShapeStyle(.bgSurface)),
    ("bg/surfaceRaised", viaShapeStyle(.bgSurfaceRaised)),
    ("bg/inset", viaShapeStyle(.bgInset)),
    ("bg/selected", viaShapeStyle(.bgSelected)),
    ("text/primary", viaShapeStyle(.textPrimary)),
    ("text/secondary", viaShapeStyle(.textSecondary)),
    ("text/tertiary", viaShapeStyle(.textTertiary)),
    ("text/onAccent", viaShapeStyle(.textOnAccent)),
    ("border/subtle", viaShapeStyle(.borderSubtle)),
    ("border/default", viaShapeStyle(.borderDefault)),
    ("border/strong", viaShapeStyle(.borderStrong)),
    ("accent/text", viaShapeStyle(.accentText)),
    ("accent/solid", viaShapeStyle(.accentSolid)),
    ("accent/soft", viaShapeStyle(.accentSoft)),
    ("status/success", viaShapeStyle(.statusSuccess)),
    ("status/warning", viaShapeStyle(.statusWarning)),
    ("status/danger", viaShapeStyle(.statusDanger)),
    ("status/info", viaShapeStyle(.statusInfo)),
    ("media/placeholder", viaShapeStyle(.mediaPlaceholder)),
    ("media/ring", viaShapeStyle(.mediaRing)),
    ("state/private", viaShapeStyle(.statePrivate)),
    ("state/archived", viaShapeStyle(.stateArchived))
]

@Test("La liste ShapeStyle du test couvre toutes les semantiques")
func shapeStyleListIsExhaustive() {
    // Sans ce test, ajouter un token semantique sans l'ajouter ci-dessus
    // laisserait sa version ShapeStyle non verifiee, en silence.
    #expect(
        Set(shapeStyleAccessors.keys) == Set(ColorTokens.semantics),
        "La liste ShapeStyle a divergé de ColorTokens.semantics"
    )
}

@Test(
    "Aucun accesseur ShapeStyle ne retombe sur un defaut",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason),
    arguments: ColorTokens.semantics
)
@MainActor
func shapeStyleAccessorsDoNotFallBackToADefault(token: String) throws {
    let accessor = try #require(
        shapeStyleAccessors[token],
        "\(token) : accesseur ShapeStyle absent de la liste du test"
    )
    let rendered = try #require(components(of: accessor))
    let byName = try #require(components(of: Color(token, bundle: .designSystem)))

    #expect(rendered.isTransparent == false, "\(token) rend transparent via ShapeStyle")
    #expect(
        rendered.matches(byName),
        """
        \(token) : l'accesseur ShapeStyle rend \(rendered), le jeu nomme rend \(byName). \
        La chaine de `extension ShapeStyle where Self == Color` ne correspond pas au token.
        """
    )
}

@Test(
    "La sonde d'alpha detecte bien un jeu absent",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
@MainActor
func alphaProbeDetectsAMissingColorSet() throws {
    // Controle negatif : sans lui, le test ci-dessus passerait tout aussi bien
    // si toute `Color` rendait un alpha non nul.
    let absent = try #require(components(of: Color("bg/ceJeuNexistePas", bundle: .designSystem)))
    #expect(absent.isTransparent, "Un jeu absent devrait rendre transparent, il rend \(absent)")
}

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
