import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// L'avatar de profil, en bout de barre de navigation, et son menu.
///
/// **Ce qu'il porte, et ce qu'il ne porte pas.** Le prototype (planche 2 bloc `3a`) montre
/// un carré ambre de 26 pt avec une initiale, tout à droite de la barre. Il donne accès au
/// changement de **profil** et aux sections de service. Il ne porte **pas** le changement
/// de bibliothèque : vérifié contre les planches, le design met ce sujet dans un menu
/// `Bibliothèque` de la barre de menus Mac et dans l'écran de gestion « Profils et
/// bibliothèques » (planche 5 bloc `7f`, donc `V7`). L'hypothèse naturelle — un `Profile`
/// pointe vers une `Library`, donc les deux vont ensemble — est fausse ici.
struct ProfileMenu: View {
    @Environment(NavigationModel.self) private var navigation
    @Environment(ProfileSession.self) private var session

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]

    #if os(macOS)
        @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        Menu {
            if profiles.count > 1 {
                Section("Changer de profil") {
                    ForEach(profiles) { profile in
                        Button {
                            session.open(profile)
                        } label: {
                            Label(profile.name, systemImage: profile.avatarSymbol)
                        }
                    }
                }
            }

            Section {
                // Sur Mac, « Réglages » et « Gestion » ont leurs propres scènes : les
                // afficher aussi dans la colonne de contenu serait l'overlay maison que la
                // convention Mac remplace par une fenêtre Settings et une fenêtre dédiée.
                #if os(macOS)
                    SettingsLink {
                        Label(AppSection.settings.title, systemImage: AppSection.settings.symbol)
                    }
                    Button {
                        openWindow(id: CineShelfApp.managementWindowID)
                    } label: {
                        Label(
                            AppSection.libraryAdmin.title,
                            systemImage: AppSection.libraryAdmin.symbol)
                    }
                    ForEach([AppSection.savedLinks, .transfer]) { section in
                        Button {
                            navigation.section = section
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                        }
                    }
                #else
                    ForEach(AppSection.utility) { section in
                        Button {
                            navigation.section = section
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                        }
                    }
                #endif
            }
        } label: {
            ProfileAvatar(
                name: session.current?.name ?? "?",
                // `Color.accent` et **pas** `session.accentColor` : ce dernier rend un
                // jeton de l'ancienne direction (`accentSolid` / `accentText`), que la
                // direction courante a supprimé — un seul ambre existe désormais. La
                // couleur *par profil* est une vraie fonctionnalité, mais sa palette
                // arrive avec `I9` (sélecteur de couleur de profil) et `V7` ; d'ici là,
                // l'accent unique est la bonne réponse, pas un contournement.
                tint: .accent,
                size: .toolbar
            )
            // La cible de 44 pt est portée par le bouton, pas par l'avatar : le carré fait
            // 28 pt, et c'est une valeur du design, pas une cible tactile.
            .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
            .contentShape(.rect)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Profil : \(session.current?.name ?? "aucun")")
    }
}
