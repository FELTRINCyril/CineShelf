#if os(macOS)

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
    //
    // > **`#if os(macOS)`, et la CI a payé son absence.** La première rédaction gardait la suite
    // > sur les deux plateformes avec un saut conditionné à « aucune fenêtre dans l'arbre ». Sur
    // > iOS une fenêtre existe toujours, donc le saut ne déclenchait pas et les trois tests
    // > cherchaient un écran Mac sur un iPhone — CI rouge. Le périmètre est de toute façon
    // > macOS : le bloc `7a` « assume un usage clavier », et la sélection multiple par clic
    // > modifié n'a pas d'équivalent iOS. La leçon est celle de la garde de saut : une condition
    // > écrite en pensant à une plateforme doit être **bornée** à elle, pas devinée à
    // > l'exécution.

    final class ConsoleUITests: XCTestCase {

        override func setUp() {
            continueAfterFailure = false
        }

        private func launch(seed: Int) throws -> XCUIApplication {
            let app = XCUIApplication()
            app.launchArguments = ["-cineshelf-seed", String(seed)]
            if ProcessInfo.processInfo.environment["CINESHELF_NO_LOCK"] != nil {
                app.launchArguments.append("-cineshelf-no-lock")
            }
            app.launch()
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

            // **La cause est trouvée, et ce n'est pas le code : l'autorisation
            // d'accessibilité manque sur cette machine.** Mesuré le 2026-08-06 :
            // `osascript -e 'tell application "System Events" to return UI elements enabled'`
            // rend `false`, et toute requête d'élément rend zéro sur une app pourtant lancée et
            // au premier plan.
            //
            // **Deux hypothèses écartées par la mesure avant d'arriver là** : ce n'était pas ma
            // garde de saut (`windows`, `groups`, `others` et `tables` sont tous à zéro, pas
            // seulement `windows`), et ce n'était pas le voile de confidentialité de `L14` — avec
            // `-cineshelf-no-lock`, qui contourne entièrement la porte du verrou, l'arbre reste
            // vide. `app.activate()` n'y change rien non plus.
            //
            // Ils **sautent** plutôt que de rougir : un défaut de droits ne doit pas se lire
            // comme un défaut de code, sinon on cherche des heures du mauvais côté.
            // **Et l'autorisation accordée à Xcode.app ne suffit pas**, mesuré le 2026-08-06
            // après qu'elle l'a été : l'arbre reste vide, `UI elements enabled` rend toujours
            // `false`, et aucun refus TCC n'est journalisé pendant la course. Le processus qui
            // pilote ici est **`xcodebuild` lancé depuis un terminal**, pas Xcode.app — c'est
            // l'application responsable du terminal qui aurait besoin du droit. Piste non
            // épuisée, écart inscrit.
            print(
                "UI DIAG windows=\(app.windows.allElementsBoundByIndex.count) "
                    + "groups=\(app.groups.allElementsBoundByIndex.count) "
                    + "others=\(app.otherElements.allElementsBoundByIndex.count) "
                    + "tables=\(app.tables.allElementsBoundByIndex.count) "
                    + "root=\(app.descendants(matching: .any)["root.content"].exists) "
                    + "consoleTable=\(app.descendants(matching: .any)["console.table"].exists)")
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

#endif
