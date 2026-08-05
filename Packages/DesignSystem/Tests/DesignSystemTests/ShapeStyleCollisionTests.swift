import SwiftUI
import Testing

@testable import DesignSystem

// SwiftUI declare deja des statiques sur `ShapeStyle`. Un accesseur de token qui
// porte le meme nom **ne casse pas la compilation du package** : il rend l'usage
// implicite ambigu, et une vue qui ecrit `.foregroundStyle(.separator)` peut alors
// prendre la couleur systeme d'Apple au lieu du token.
//
// C'est arrive : le token `separator` de la planche 8 heurtait `ShapeStyle.separator`.
// Trouve par `ColorAssetTests`, corrige en nommant l'accesseur `separatorLine` — le
// token garde son nom dans le JSON, seul le nom Swift est desambiguise
// (`ACCESSOR_OVERRIDES` dans scripts/generate-colors.py).
//
// Ce fichier traite la classe entiere, plutot que ce cas la.

/// Les statiques que SwiftUI expose en position `ShapeStyle` implicite.
///
/// **Mesurees, pas recopiees d'une documentation.** Protocole, reproductible : pour
/// chaque nom candidat, compiler
/// `Text("x").foregroundStyle(.<nom>)` avec le seul `import SwiftUI` et regarder si
/// `swiftc -typecheck` accepte. Un nom absent echoue sur
/// « type 'ShapeStyle' has no member '<nom>' », ce qui donne le controle negatif.
///
/// Releve sur le SDK macOS 15 (Xcode 26.6). `windowBackground` est propre a macOS et
/// figure quand meme ici : un nom reserve sur une seule plateforme suffit a interdire
/// le token, qui doit se resoudre sur les deux.
private let nativeShapeStyleNames: Set<String> = [
    // HierarchicalShapeStyle
    "primary", "secondary", "tertiary", "quaternary", "quinary",
    // Roles
    "background", "foreground", "selection", "link", "placeholder", "fill", "tint",
    "separator", "windowBackground",
    // Materials
    "regularMaterial", "thinMaterial", "ultraThinMaterial", "thickMaterial",
    "ultraThickMaterial", "bar"
]

@Test("Aucun accesseur de token ne heurte une statique de ShapeStyle")
func noAccessorCollidesWithANativeShapeStyle() {
    let colliding = ColorTokens.accessorNames.filter(nativeShapeStyleNames.contains)

    #expect(
        colliding.isEmpty,
        """
        Ces accesseurs portent le nom d'une statique SwiftUI : \
        \(colliding.sorted().joined(separator: ", ")). L'usage implicite devient \
        ambigu et une vue peut prendre la couleur systeme au lieu du token. \
        Ajouter une entree a ACCESSOR_OVERRIDES dans scripts/generate-colors.py, \
        puis regenerer — sans toucher au nom du token dans le JSON.
        """
    )
}

@Test("Les jeux legacy non plus")
func noLegacyAccessorCollidesEither() {
    // L'ancienne direction est en sursis mais toujours lue par le banc d'essai :
    // une collision y produirait la meme prise de couleur systeme.
    let legacyAccessors = LegacyColorTokens.semantics.map { token -> String in
        let parts = token.split(separator: "/").map(String.init)
        return parts[0] + parts.dropFirst().map { $0.capitalized }.joined()
    }
    let colliding = legacyAccessors.filter(nativeShapeStyleNames.contains)
    #expect(colliding.isEmpty, "Collision legacy : \(colliding.sorted().joined(separator: ", "))")
}

@Test("La liste des statiques natives est bien peuplee, et contient le cas connu")
func nativeListIsCalibrated() {
    // Controle negatif de la liste elle-meme : vide ou tronquee, le test ci-dessus
    // passerait toujours. `separator` doit y etre — c'est le cas reel qui a motive
    // ce fichier, et sa presence prouve que la garde aurait mordu sur le nom
    // d'origine du token.
    #expect(nativeShapeStyleNames.contains("separator"))
    #expect(nativeShapeStyleNames.contains("primary"))
    #expect(nativeShapeStyleNames.contains("fill"))
    #expect(nativeShapeStyleNames.count == 20)

    // Et la garde mord bien : le nom d'accesseur d'origine aurait ete refuse.
    #expect(nativeShapeStyleNames.contains("separator"), "Le nom refuse etait bien `separator`")
    #expect(ColorTokens.accessorNames.contains("separatorLine"), "Le nom retenu est `separatorLine`")
    #expect(ColorTokens.accessorNames.contains("separator") == false)
}

@Test("Chaque jeu semantique a un accesseur, et un seul nom")
func accessorNamesMatchTokenList() {
    #expect(ColorTokens.accessorNames.count == ColorTokens.semantics.count)
    #expect(Set(ColorTokens.accessorNames).count == ColorTokens.accessorNames.count)
}

// MARK: - Garde de compilation
//
// Le test ci-dessus compare des chaines ; il ne prouve pas que l'usage implicite
// compile. Cette vue le prouve : une ambiguite future la rend non compilable, donc
// la suite de tests ne construit plus. C'est volontairement une erreur de
// compilation et non un test rouge — une ambiguite n'est pas rattrapable a
// l'execution.
//
// Un accesseur ajoute au JSON doit etre ajoute ici. Ce n'est pas de la duplication :
// c'est le seul endroit du depot ou la forme `.<token>` est exercee telle que les
// vues l'ecrivent.

private struct ImplicitShapeStyleUsage: View {
    var body: some View {
        VStack {
            Text("x").foregroundStyle(.bgCanvas)
            Text("x").foregroundStyle(.bgInset)
            Text("x").foregroundStyle(.bgSurface)
            Text("x").foregroundStyle(.bgRaised)
            Text("x").foregroundStyle(.bgFill)
            Text("x").foregroundStyle(.bgViewer)
            Text("x").foregroundStyle(.textPrimary)
            Text("x").foregroundStyle(.textSecondary)
            Text("x").foregroundStyle(.textTertiary)
            Text("x").foregroundStyle(.accent)
            Text("x").foregroundStyle(.accentOnAccent)
            Text("x").foregroundStyle(.ratingEmpty)
            Text("x").foregroundStyle(.danger)
            Text("x").foregroundStyle(.success)
            Text("x").foregroundStyle(.separatorLine)
            Text("x").foregroundStyle(.privateMask)
            Text("x").foregroundStyle(.scrimModal)
            Text("x").foregroundStyle(.scrimCrop)
            Text("x").foregroundStyle(.fillOnImage)
            Text("x").foregroundStyle(.chipOnImage)
        }
    }
}

@Test("La garde de compilation couvre les 20 jeux")
func compilationGuardCoversEveryToken() {
    // Si un jeu est ajoute au JSON sans etre ajoute a `ImplicitShapeStyleUsage`,
    // sa forme implicite n'est exercee nulle part : ce compte le signale.
    #expect(ColorTokens.semantics.count == 20, "Ajouter le nouveau jeu a ImplicitShapeStyleUsage")
    _ = ImplicitShapeStyleUsage()
}
