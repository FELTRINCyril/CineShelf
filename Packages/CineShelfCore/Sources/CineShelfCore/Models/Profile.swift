import Foundation
import SwiftData

/// Une personne qui consulte : nom, avatar, ses listes, ses préférences.
@Model
public final class Profile {
    public var id = UUID()
    public var name: String = ""
    public var avatarSymbol: String = "person.crop.circle"
    public var avatarEmoji: String?
    /// Jeton du catalogue de couleurs, jamais un hexadécimal.
    public var accentToken: String = "accent/solid"
    public var isDefault: Bool = false
    public var sortIndex: Int = 0

    /// Ce profil exige Face ID / Touch ID pour être ouvert.
    public var requiresBiometry: Bool = false
    /// Ce profil ne voit jamais les entités marquées privées.
    public var hidesPrivateContent: Bool = false

    public var createdAt = Date()
    public var updatedAt = Date()

    /// Le catalogue que ce profil consulte.
    /// Deux profils sur la même `Library` = modèle Netflix.
    public var library: Library?

    @Relationship(deleteRule: .cascade, inverse: \TitleFlag.profile)
    public var titleFlags: [TitleFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \PersonFlag.profile)
    public var personFlags: [PersonFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaFlag.profile)
    public var mediaFlags: [MediaFlag]? = []

    public init(name: String = "", isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
