import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// Le menu de profil, en pied de barre latérale : qui est connecté, comment en
/// changer, et l'accès aux sections de service.
///
/// Ces sections (Ma liste, Gestion, Import / Export, Réglages) ne sont pas dans
/// la barre latérale de `docs/01` partie C. Les regrouper ici donne la même
/// organisation qu'en compact, où elles vivent derrière l'onglet « Plus ».
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
                // Sur Mac, « Réglages » et « Gestion » ont leurs propres
                // scènes : les afficher aussi dans la colonne du milieu serait
                // l'overlay maison que `docs/01` A.2 remplace justement par une
                // fenêtre Settings et une fenêtre dédiée.
                #if os(macOS)
                    SettingsLink {
                        Label(AppSection.settings.title, systemImage: AppSection.settings.symbol)
                    }
                    Button {
                        openWindow(id: CineShelfApp.managementWindowID)
                    } label: {
                        Label(AppSection.libraryAdmin.title, systemImage: AppSection.libraryAdmin.symbol)
                    }
                    ForEach([AppSection.myList, .transfer]) { section in
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
            HStack(spacing: Space.sm) {
                Image(systemName: session.current?.avatarSymbol ?? "person.crop.circle")
                    .font(.system(.title3))
                    .foregroundStyle(.accentText)
                Text(session.current?.name ?? "Aucun profil")
                    .font(Typo.cardTitle)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(.caption2))
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, Space.sm)
            .frame(minHeight: Space.minHitTarget)
            .contentShape(.rect)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Profil : \(session.current?.name ?? "aucun")")
    }

}
