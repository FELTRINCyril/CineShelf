import Foundation
import Testing

// La navigation est le seul endroit où les features se coordonnent : une incohérence
// entre l'onglet et la section ne se voit pas à la compilation, seulement à l'usage, et
// seulement sur une plateforme.
//
// **Réécrit par `V0`.** L'ancienne coquille avait cinq onglets dont un « Catalogue »
// segmenté ; le design (planche 2 bloc `3c`) en donne cinq autres — Accueil · Titres ·
// Recherche · Ma liste · Gérer — et aucun segment. `CatalogueSegment` a disparu avec lui.

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

        navigation.section = .titles
        #expect(navigation.compactTab == .titles)

        navigation.section = .myList
        #expect(navigation.compactTab == .myList)

        // Les sections sans onglet propre retombent sur « Gérer ».
        navigation.section = .gallery
        #expect(navigation.compactTab == .manage)

        navigation.section = .settings
        #expect(navigation.compactTab == .manage)
    }

    @Test("Changer d'onglet aligne la section")
    func changingTabAlignsTheSection() {
        let navigation = NavigationModel()

        navigation.compactTab = .search
        #expect(navigation.section == .search)

        navigation.compactTab = .titles
        #expect(navigation.section == .titles)
    }

    @Test("L'onglet « Gérer » ne change pas la section : c'est une liste")
    func manageTabDoesNotChangeTheSection() {
        let navigation = NavigationModel()
        navigation.section = .titles

        navigation.compactTab = .manage

        #expect(navigation.section == .titles)
    }

    @Test("Chaque section a un onglet d'accueil, et « Gérer » recueille le reste")
    func everySectionIsReachableFromATab() {
        // Le contrôle qui manquait : sans lui, ajouter une section la rendrait
        // inatteignable sur iPhone sans que rien ne le signale. Les quatre sections que le
        // design ne met dans aucun onglet — Personnes, Collections, Galerie, Signets —
        // doivent être listées par « Gérer ». Voir la note de `CompactTab`.
        for section in AppSection.allCases {
            let tab = CompactTab.containing(section)
            if tab == .manage {
                #expect(CompactTab.managed.contains(section), "\(section.rawValue) introuvable")
            } else {
                #expect(tab.section == section, "\(section.rawValue)")
            }
        }
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
        #expect(restored.compactTab == .manage, "L'onglet doit suivre la section restaurée")
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
        #expect(navigation.canGoToNext == false)
    }
}
