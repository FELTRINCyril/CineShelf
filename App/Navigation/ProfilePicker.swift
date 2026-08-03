import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

/// L'écran de choix de profil au lancement.
///
/// Affiché seulement quand il y a un choix à faire : un profil unique ouvre
/// directement, et l'option « ouvrir directement le dernier profil » court-circuite
/// aussi cet écran. C'est `RootView` qui arbitre — voir `RootView.swift`.
struct ProfilePicker: View {
    @Environment(ProfileSession.self) private var session

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]

    var body: some View {
        @Bindable var session = session

        // Défilable : c'est le premier écran de l'app, et sur iPhone SE en AX5
        // le titre, la grille et l'interrupteur ne tiennent pas ensemble.
        ScrollView {
            VStack(spacing: Space.xl) {
                VStack(spacing: Space.xs) {
                    Text("Qui regarde ?")
                        .font(Typo.heroTitle)
                        .foregroundStyle(.textPrimary)
                    Text("Chaque profil a ses favoris, ses notes et ses réglages.")
                        .font(Typo.body)
                        .foregroundStyle(.textSecondary)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: Space.lg)],
                    spacing: Space.lg
                ) {
                    ForEach(profiles) { profile in
                        ProfileTile(profile: profile) { session.open(profile) }
                    }
                }
                .frame(maxWidth: 640)

                Toggle("Ouvrir directement le dernier profil", isOn: $session.opensLastProfileDirectly)
                    .toggleStyle(.switch)
                    .font(Typo.body)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: 420)
            }
            .padding(Space.panelPadding)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bgCanvas)
    }
}

private struct ProfileTile: View {
    let profile: Profile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.sm) {
                ZStack {
                    Circle().fill(.bgSurfaceRaised)
                    if let emoji = profile.avatarEmoji {
                        Text(emoji).font(.system(.largeTitle))
                    } else {
                        Image(systemName: profile.avatarSymbol)
                            .font(.system(.largeTitle))
                            .foregroundStyle(.accentText)
                    }
                }
                .frame(width: 96, height: 96)
                .overlay(alignment: .bottomTrailing) {
                    // Le verrou est affiché parce que le modèle le porte ; il
                    // n'est pas encore appliqué — Face ID arrive au prompt 18.
                    if profile.requiresBiometry {
                        Image(systemName: Icon.isPrivate)
                            .font(.system(.caption))
                            .foregroundStyle(.textOnAccent)
                            .padding(Space.xs)
                            .background(.accentSolid, in: .circle)
                    }
                }

                Text(profile.name)
                    .font(Typo.cardTitle)
                    .foregroundStyle(.textPrimary)
            }
            .frame(minWidth: Space.minHitTarget, minHeight: Space.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            profile.requiresBiometry ? "\(profile.name), protégé par Face ID" : profile.name
        )
    }
}
