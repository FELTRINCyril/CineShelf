import SwiftUI

/// La barre de menus — `docs/01` partie C.
///
/// Les entrées sans cible sont **désactivées**, pas absentes : un menu vide ne
/// dit rien, un menu grisé annonce ce qui arrive et où le chercher. Elles
/// s'activeront à mesure que les prompts de contenu les branchent.
struct CineShelfCommands: Commands {
    let navigation: NavigationModel
    let session: ProfileSession

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouveau titre") {
                navigation.section = .titles
                navigation.wantsNewTitle = true
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .importExport) {
            Button("Importer…") {}
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(true)

            Button("Exporter…") {}
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(true)
        }

        CommandGroup(after: .toolbar) {
            // ⌘K et non ⌘F : c'est le raccourci que la barre de navigation **affiche**
            // (planche 2 bloc `3a`, « Rechercher ⌘K »), et une mention de raccourci qui ne
            // fonctionne pas est pire que pas de mention. ⌘F reste en second, parce que
            // c'est le réflexe Mac et qu'il ne coûte rien.
            Button("Rechercher") {
                navigation.section = .search
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Rechercher (⌘F)") {
                navigation.section = .search
            }
            .keyboardShortcut("f", modifiers: .command)

            Button(navigation.isInspectorPresented ? "Masquer l'inspecteur" : "Afficher l'inspecteur") {
                navigation.isInspectorPresented.toggle()
            }
            .keyboardShortcut("i", modifiers: [.option, .command])
        }

        // « Aller à » et non « Bibliothèque » : ce menu ne contient aucune `Library`, et
        // le mot est réservé à l'entité. Le prototype montre bien un menu `Bibliothèque`
        // (planche 2 bloc `3a`), mais ce qu'il y range — changer de bibliothèque, gérer
        // les profils — appartient à `V7` et n'a encore aucune cible. Le créer vide
        // n'annoncerait rien.
        CommandMenu("Aller à") {
            ForEach(AppSection.navigationBar) { section in
                Button(section.title) { navigation.section = section }
            }

            Divider()

            Button(AppSection.savedLinks.title) { navigation.section = .savedLinks }
            Button(AppSection.transfer.title) { navigation.section = .transfer }
        }

        // ⌃⌘1…9. Dans la barre de menus, seul endroit où SwiftUI enregistre
        // vraiment un raccourci : posés dans un `Menu` de la barre latérale, ils
        // ne s'activaient qu'une fois le menu déroulé, et jamais colonne repliée.
        CommandMenu("Profil") {
            ForEach(Array(session.ordered.prefix(9).enumerated()), id: \.element.id) { index, profile in
                Button(profile.name) { session.open(profile) }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")), modifiers: [.control, .command])
            }

            if session.ordered.count > 9 {
                Text("Les profils au-delà du neuvième n'ont pas de raccourci.")
            }
        }
    }
}
