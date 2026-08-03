import Foundation
import Testing

// La navigation est le seul endroit où les features se coordonnent : une
// incohérence entre l'onglet, le segment et la section ne se voit pas à la
// compilation, seulement à l'usage, et seulement sur une plateforme.

@MainActor
struct NavigationModelTests {

    /// `UserDefaults` jetable : les tests de restauration écrivent pour de vrai,
    /// et ne doivent pas polluer les réglages de la machine.
    private func makeDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "navigation.tests.\(UUID().uuidString)")
        return suite ?? .standard
    }

    // MARK: Cohérence compact / large

    @Test("Choisir une section dans la barre latérale aligne l'onglet compact")
    func selectingASectionAlignsTheCompactTab() {
        let navigation = NavigationModel()

        navigation.section = .people
        #expect(navigation.compactTab == .catalogue)
        #expect(navigation.catalogueSegment == .people)

        navigation.section = .gallery
        #expect(navigation.compactTab == .gallery)

        navigation.section = .settings
        #expect(navigation.compactTab == .more)
    }

    @Test("Changer d'onglet aligne la section")
    func changingTabAlignsTheSection() {
        let navigation = NavigationModel()

        navigation.compactTab = .search
        #expect(navigation.section == .search)

        navigation.catalogueSegment = .collections
        navigation.compactTab = .catalogue
        #expect(navigation.section == .collections)
    }

    @Test("L'onglet « Plus » ne change pas la section : c'est une liste")
    func moreTabDoesNotChangeTheSection() {
        let navigation = NavigationModel()
        navigation.section = .gallery

        navigation.compactTab = .more

        #expect(navigation.section == .gallery)
    }

    @Test("Changer de segment ne déplace la section que depuis l'onglet Catalogue")
    func segmentOnlyMovesTheSectionFromItsOwnTab() {
        let navigation = NavigationModel()
        navigation.compactTab = .gallery

        navigation.catalogueSegment = .people

        #expect(navigation.section == .gallery)
    }

    // MARK: Piles

    @Test("Chaque section a sa propre pile")
    func stacksArePerSection() {
        let navigation = NavigationModel()
        let title = UUID()
        let person = UUID()

        navigation.section = .titles
        navigation.open(.title(title))
        navigation.section = .people
        navigation.open(.person(person))

        #expect(navigation.path(for: .titles) == [.title(title)])
        #expect(navigation.path(for: .people) == [.person(person)])
        #expect(navigation.path(for: .gallery).isEmpty)
    }

    @Test("L'onglet « Plus » a sa propre pile, distincte de toute section")
    func moreTabHasItsOwnStack() {
        let navigation = NavigationModel()
        let route = AppRoute.media(UUID())

        navigation.section = .gallery
        navigation.paths[.more] = [route]

        // Le bug corrigé : « Plus » était lié à la pile de la section courante,
        // donc trois NavigationStack vivants partageaient un même tableau.
        #expect(navigation.path(for: .gallery).isEmpty)
        #expect(navigation.path(for: .more) == [route])
    }

    // MARK: Précédent / suivant

    @Test("⌥↑ et ⌥↓ parcourent la collection sans empiler")
    func previousAndNextWalkTheCollectionInPlace() {
        let navigation = NavigationModel()
        let ids = (0..<3).map { _ in UUID() }
        let collection = ids.map { AppRoute.title($0) }

        navigation.section = .titles
        navigation.open(collection[1], within: collection)

        #expect(navigation.canGoToPrevious)
        #expect(navigation.canGoToNext)

        navigation.goToNext()
        #expect(navigation.path(for: .titles) == [collection[2]], "Le détail est remplacé, pas empilé")
        #expect(navigation.canGoToNext == false, "Dernier élément : plus de suivant")

        navigation.goToPrevious()
        navigation.goToPrevious()
        #expect(navigation.path(for: .titles) == [collection[0]])
        #expect(navigation.canGoToPrevious == false)
    }

    @Test("Sans collection, il n'y a ni précédent ni suivant")
    func withoutACollectionThereIsNoNeighbour() {
        let navigation = NavigationModel()
        navigation.section = .titles
        navigation.open(.title(UUID()))

        #expect(navigation.canGoToPrevious == false)
        #expect(navigation.canGoToNext == false)
    }

    @Test("Aller au voisin sur une pile vide ne fait rien")
    func neighbourOnAnEmptyStackIsANoOp() {
        let navigation = NavigationModel()
        navigation.goToNext()

        #expect(navigation.path(for: navigation.section).isEmpty)
    }

    // MARK: Restauration

    @Test("La navigation traverse un redémarrage")
    func navigationSurvivesARestart() {
        let defaults = makeDefaults()
        let profileID = UUID()
        let route = AppRoute.person(UUID())

        let saved = NavigationModel()
        saved.section = .people
        saved.open(route)
        saved.isInspectorPresented = true
        saved.save(profileID: profileID, to: defaults)

        let restored = NavigationModel()
        restored.restore(profileID: profileID, from: defaults)

        #expect(restored.section == .people)
        #expect(restored.catalogueSegment == .people)
        #expect(restored.compactTab == .catalogue, "L'onglet doit suivre la section restaurée")
        #expect(restored.path(for: .people) == [route])
        #expect(restored.isInspectorPresented)
    }

    @Test("La restauration est par profil")
    func restorationIsPerProfile() {
        let defaults = makeDefaults()
        let first = UUID()
        let second = UUID()

        let saved = NavigationModel()
        saved.section = .gallery
        saved.save(profileID: first, to: defaults)

        let restored = NavigationModel()
        restored.restore(profileID: second, from: defaults)

        #expect(restored.section == .home, "Un profil sans état enregistré démarre sur l'accueil")
    }

    @Test("Basculer vers un profil sans état enregistré ne conserve rien du précédent")
    func switchingToAFreshProfileDoesNotInheritTheOtherOne() {
        let defaults = makeDefaults()
        let navigation = NavigationModel()

        // Le premier profil laisse un état chargé sur l'instance partagée.
        navigation.section = .collections
        navigation.open(.collection(UUID()))
        navigation.isInspectorPresented = true
        navigation.save(profileID: UUID(), to: defaults)

        // Le second n'en a aucun : il doit repartir de zéro, pas hériter.
        navigation.restore(profileID: UUID(), from: defaults)

        #expect(navigation.section == .home)
        #expect(navigation.paths.isEmpty)
        #expect(navigation.isInspectorPresented == false)
        #expect(navigation.catalogueSegment == .titles)
        #expect(navigation.canGoToNext == false)
    }
}
