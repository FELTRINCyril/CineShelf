import CineShelfCore
import DesignSystem
import SwiftData
import SwiftUI

// MARK: - V7 · Les profils
//
// Planche 5, bloc `7f`. « 3 profils · 2 bibliothèques », puis une ligne par profil avec son
// avatar, sa bibliothèque, et ses deux bascules — « Face ID pour entrer » et « Masquer le
// contenu privé ».
//
// **Les deux bascules ne sont pas décoratives depuis `L14`** : `requiresBiometry` était
// « affiché mais jamais appliqué », et `PrivacyScope` l'applique désormais. C'est la première
// fois que l'interrupteur du prototype fait quelque chose.
//
// **Ce qui n'est pas livré, et pourquoi** : le panneau « Déplacer vers une autre bibliothèque »
// avec sa clôture transitive. C'est `L15`, reportée en v1.1. En rendre la coquille donnerait un
// bouton qui ne déplace rien.

struct ProfilesView: View {
    @Environment(ProfileSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @Query(sort: \Library.name) private var libraries: [Library]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
                Text("Profils")
                    .title2Style()
                    .foregroundStyle(Color.textPrimary)
                Text(countLabel)
                    .numericStyle()
                    .foregroundStyle(Color.textTertiary)
                Spacer(minLength: Space.s4)
                Button("Nouveau profil", action: createProfile)
                    .buttonStyle(.plain)
                    .actionStyle()
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: Space.minHitTarget)
            }

            ForEach(profiles, id: \.persistentModelID) { profile in
                row(profile)
            }
        }
    }

    /// « 3 profils · 2 bibliothèques » — le sous-titre du bloc `7f`.
    private var countLabel: String {
        let people = profiles.count == 1 ? "1 profil" : "\(profiles.count) profils"
        let shelves =
            libraries.count == 1 ? "1 bibliothèque" : "\(libraries.count) bibliothèques"
        return "\(people) · \(shelves)"
    }

    private func row(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s3) {
                // `tint: .accent` — la palette par profil de `I9` n'est pas branchée sur le
                // chrome, et `ProfileMenu` fait déjà ce choix pour la même raison : un seul
                // ambre existe dans la direction retenue. Le sélecteur de couleur ci-dessous
                // écrit bien `accentRaw`, ce qui ferme l'écart « lu 53 fois, jamais écrit ».
                ProfileAvatar(initials: ProfileFormat.initials(of: profile), tint: .accent)
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(profile.name.isEmpty ? "Sans nom" : profile.name)
                        .headlineStyle()
                        .foregroundStyle(Color.textPrimary)
                    Text(profile.library?.name ?? "Aucune bibliothèque")
                        .metaStyle()
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer(minLength: Space.s4)
            }

            ToggleRow(
                "Face ID pour entrer",
                note: "Le contenu privé reste masqué tant que ce profil n'est pas déverrouillé.",
                isOn: binding(profile, \.requiresBiometry))
            ToggleRow("Masquer le contenu privé", isOn: binding(profile, \.hidesPrivateContent))
            ProfileColorPicker("Couleur", selection: accentBinding(profile))
        }
        .padding(.vertical, Space.s3)
    }

    /// **L'écriture passe par le repository**, comme partout : c'est lui qui appelle
    /// `refreshDerived()` et journalise. Une bascule écrite depuis la vue laisserait
    /// `updatedAt` en arrière, donc la synchronisation ne saurait pas que le profil a changé.
    private func binding(
        _ profile: Profile, _ keyPath: ReferenceWritableKeyPath<Profile, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { value in
                ProfileRepository(context: modelContext).update(profile) {
                    $0[keyPath: keyPath] = value
                }
            })
    }

    /// **Le sélecteur de couleur de `I9` trouve enfin un appelant.** Il existait depuis le lot
    /// des champs de formulaire, et rien ne l'appelait — donc `Profile.accentRaw` était lu
    /// cinquante-trois fois et écrit nulle part.
    private func accentBinding(_ profile: Profile) -> Binding<ProfileColor> {
        Binding(
            get: { ProfileColor(rawValue: profile.accentRaw) ?? .amber },
            set: { value in
                ProfileRepository(context: modelContext).update(profile) {
                    $0.accentRaw = value.rawValue
                }
            })
    }

    private func createProfile() {
        guard let library = session.current?.library ?? libraries.first else { return }
        ProfileRepository(context: modelContext).create(name: "Nouveau profil", in: library)
    }
}

/// Le formatage propre aux profils.
enum ProfileFormat {
    /// Les initiales d'un profil, pour la pastille.
    ///
    /// **Jamais vide** : une pastille sans lettre se lit comme un défaut d'affichage. Un profil
    /// sans nom rend « ? », ce qui est une information — il faut le nommer.
    static func initials(of profile: Profile) -> String {
        let words = profile.name.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}
