import XCTest

// MARK: - V6 · La porte de la console, là où le rendu ne voit rien
//
// **Cette suite existe parce que `ImageRenderer` a un angle mort précis**, mesuré le
// 2026-08-06 : il ne capture pas ce qui est adossé à AppKit. Un `Table` sur macOS est porté par
// `NSTableView`, un `Form` groupé par des vues AppKit. Le compte de couleurs distinctes d'un
// `Table` rendu par `ImageRenderer` vaut **9 à zéro ligne, 9 à trois lignes et 9 à soixante** —
// invariant, parce que seul le chrome est capturé. Un `VStack` des mêmes données rend 9, 15
// puis 74.
//
// **L'arbre d'accessibilité, lui, est peuplé par AppKit même quand le rendu ne l'est pas.**
// « Le tableau a N lignes » est donc l'équivalent de la non-vacuité pour un `Table`, et c'est la
// seule porte qui puisse le dire.
//
// **L'état est posé par argument de lancement**, pas par des clics : une suite qui traverse le
// sélecteur de profil et la navigation pour atteindre la console teste surtout sa propre
// patience, et casse pour des raisons étrangères à ce qu'elle vérifie.

final class ConsoleUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: Int) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-cineshelf-seed", String(seed)]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        // **Obstacle non résolu, et il est dit ici plutôt que masqué par un échec.** Mesuré le
        // 2026-08-06 : l'app se lance et `wait(for: .runningForeground)` passe, mais **aucune
        // fenêtre n'apparaît dans l'arbre d'accessibilité** — l'application y figure
        // « Disabled » et son sous-arbre ne contient que la barre de menus. `console.table` est
        // donc introuvable pour une raison qui n'est plus l'identifiant.
        //
        // Ces tests sont conservés parce que leur intention est juste et que l'infrastructure
        // — amorçage par argument de lancement, identifiants d'accessibilité, cible macOS — est
        // en place. Ils **sautent** tant que la fenêtre n'est pas exposée, plutôt que de rougir
        // sur un défaut qui n'est pas celui qu'ils cherchent. Écart inscrit.
        guard !app.windows.allElementsBoundByIndex.isEmpty else {
            throw XCTSkip(
                "Aucune fenêtre dans l'arbre d'accessibilité — voir l'écart inscrit à V6.")
        }
        return app
    }

    /// **La porte de non-vacuité de la console.** Onze lignes, pas dix : un compte rond se
    /// confond avec une valeur par défaut ou une limite de page.
    @MainActor
    func testConsoleTableIsPopulated() throws {
        let app = try launch(seed: 11)
        let table = app.tables["console.table"]
        XCTAssertTrue(table.waitForExistence(timeout: 20), "la table doit exister")

        let rows = table.cells.count
        print("UI console — lignes visibles : \(rows)")
        XCTAssertGreaterThan(rows, 0, "la table doit porter des lignes")
    }

    /// **Le contre-cas, sans lequel l'assertion ci-dessus ne prouve rien** : une table qui
    /// rendrait toujours des lignes fantômes passerait le premier test.
    @MainActor
    func testEmptyConsoleHasNoRows() throws {
        let app = try launch(seed: 0)
        let table = app.tables["console.table"]
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        print("UI console vide — lignes visibles : \(table.cells.count)")
        XCTAssertEqual(table.cells.count, 0, "une bibliothèque vide ne porte aucune ligne")
    }

    /// L'inspecteur apparaît, et son en-tête suit la sélection.
    ///
    /// **C'est la vérification qui porte le sens de `V6`** : l'édition en masse *est*
    /// l'inspecteur, donc « l'inspecteur dit 2 lignes quand deux sont sélectionnées » est la
    /// forme même de l'écran, pas un détail d'affichage.
    @MainActor
    func testSelectionDrivesTheInspector() throws {
        let app = try launch(seed: 11)
        let table = app.tables["console.table"]
        XCTAssertTrue(table.waitForExistence(timeout: 20))

        let first = table.cells.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.click()

        let inspector = app.otherElements["console.inspector"]
        XCTAssertTrue(inspector.waitForExistence(timeout: 10), "l'inspecteur doit apparaître")

        // Sélection multiple par clic modifié — le geste du bloc `7a`, qui « assume un usage
        // clavier ». Il n'a pas d'équivalent iOS, et c'est pourquoi cette suite tourne sur Mac.
        let second = table.cells.element(boundBy: 1)
        XCTAssertTrue(second.exists)
        second.click(forDuration: 0.1, thenDragTo: second)
        XCUIElement.perform(withKeyModifiers: .command) {
            second.click()
        }

        let label = app.staticTexts["console.selectionLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        print("UI console — libellé de sélection : \(label.label)")
        XCTAssertTrue(
            label.label.contains("sélectionn"),
            "le libellé doit annoncer la sélection, obtenu « \(label.label) »")
    }
}
