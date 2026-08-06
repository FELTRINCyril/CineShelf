import SwiftUI
import Testing

@testable import DesignSystem

// Les champs de `I7` + `I8` + `I9`.
//
// **Ce qui se teste et ce qui se regarde.** Une saisie ne se teste pas sans clavier, et une
// couleur ne se juge pas dans un test. Ce qui se teste ici est ce qui **décide** : combien de
// champs une précision demande, ce qu'une valeur hors bornes déclenche, et — par la sonde de
// pixels — qu'un champ en erreur ne rend pas comme un champ valide.

@Suite("Champs de formulaire")
struct FormFieldTests {

    @Test("Chaque cran de précision demande le bon nombre de champs")
    func precisionDecidesFieldCount() {
        // Source : handoff §6, « date à précision variable (trois crans : année, mois, jour) ».
        #expect(DateFieldPrecision.year.fieldCount == 1)
        #expect(DateFieldPrecision.month.fieldCount == 2)
        #expect(DateFieldPrecision.day.fieldCount == 3)
        #expect(DateFieldPrecision.allCases.count == 3)
    }

    @Test("Une date n'est complète que si sa précision est renseignée")
    func completenessFollowsPrecision() {
        #expect(PrecisionDate(year: 1974, precision: .year).isComplete)
        // Une année seule ne suffit pas à une précision au mois — et c'est ce qui empêche
        // d'écrire une date « au mois » dont le mois est inventé.
        #expect(!PrecisionDate(year: 1974, precision: .month).isComplete)
        #expect(PrecisionDate(year: 1974, month: 3, precision: .month).isComplete)
        #expect(!PrecisionDate(year: 1974, month: 3, precision: .day).isComplete)
        #expect(PrecisionDate(year: 1974, month: 3, day: 12, precision: .day).isComplete)
        #expect(!PrecisionDate().isComplete)
    }

    @Test("Le jour n'est pas borné au mois, et c'est délibéré")
    func dayIsNotBoundToItsMonth() {
        // Un 31 février se **tape** et se refuse par l'anatomie d'erreur, avec un message qui
        // dit quoi faire. Un champ qui refuse la frappe ne dit rien.
        #expect(PrecisionDate.dayBounds.contains(31))
        #expect(PrecisionDate.monthBounds == 1...12)
    }

    @Test("Les quatre couleurs de profil sont une liste fermée et distinctes")
    func profileColoursAreClosedAndDistinct() {
        // Source : handoff §6, « jetons de couleur en liste fermée ».
        #expect(ProfileColor.allCases.count == 4)
        #expect(Set(ProfileColor.allCases.map(\.rawValue)).count == 4)
    }
}

// MARK: - Ce que le pixel doit montrer

@MainActor
@Test(
    "Un champ en erreur ne rend pas comme un champ valide",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func erroredFieldDiffersFromValid() async throws {
    func field(_ error: FieldError?) -> some View {
        FieldShell("Année", error: error) {
            Text(verbatim: "2021").font(Typo.callout).foregroundStyle(Color.textPrimary)
        }
        .padding(Space.s4)
        .background(Color.bgSurface)
    }

    let valid = try #require(await renderStats(field(nil), width: 260))
    let failing = try #require(
        await renderStats(field(FieldError("Utilise quatre chiffres.")), width: 260))

    #expect(valid.fingerprint != failing.fingerprint)
    // Les quatre marques ajoutent du rouge, un triangle et une ligne de texte : le champ en
    // erreur est **plus haut** et porte plus de couleurs. S'il n'était que teinté, la hauteur
    // ne changerait pas — et le message serait absent.
    #expect(failing.height > valid.height, "Le message d'erreur n'occupe aucune place")
    #expect(failing.distinctColours > valid.distinctColours)
}

@MainActor
@Test(
    "Un champ requis vide reste neutre",
    .enabled(if: AssetCatalog.isCompiled, AssetCatalog.skipReason)
)
func requiredEmptyFieldStaysNeutral() async throws {
    // La règle du bloc `11a`, et celle qu'on enfreint sans y penser : « un requis vide reste
    // neutre jusqu'à la tentative de validation ». Le contrôle est le champ **en erreur** :
    // s'ils rendaient pareil, le requis serait peint en rouge.
    func field(isRequired: Bool, error: FieldError?) -> some View {
        FieldShell("Titre", isRequired: isRequired, error: error) {
            Text(verbatim: "").font(Typo.callout)
        }
        .padding(Space.s4)
        .background(Color.bgSurface)
    }

    let required = try #require(await renderStats(field(isRequired: true, error: nil), width: 260))
    let failing = try #require(
        await renderStats(field(isRequired: false, error: FieldError("Donne un titre.")), width: 260))

    #expect(required.fingerprint != failing.fingerprint)
    #expect(required.height < failing.height)
}
