import Foundation
import SwiftData

/// Une personne : acteur, réalisateur, compte social… selon ses rôles.
///
/// Fusionne les anciennes tables `actors` et `social_profiles` de la version
/// web : lier un profil social à un acteur revient désormais à ajouter un rôle.
@Model
public final class Person {
    public var id = UUID()

    public var firstName: String = ""
    public var lastName: String = ""
    /// Maintenu par `refreshDerived()`.
    public var displayName: String = ""
    /// Maintenu par `refreshDerived()`.
    public var sortName: String = ""
    public var birthDate: Date?
    public var deathDate: Date?
    public var bio: String?

    /// Rôles portés par cette personne, persistés en `rawValue`.
    public var roleValues: [String] = [PersonRole.actor.rawValue]

    public var isPrivate: Bool = false
    public var isArchived: Bool = false
    public var deletedAt: Date?
    /// Maintenu par `refreshDerived()`.
    public var searchText: String = ""
    public var createdAt = Date()
    public var updatedAt = Date()

    public var library: Library?
    @Relationship(deleteRule: .cascade, inverse: \PersonFlag.person)
    public var flags: [PersonFlag]? = []
    @Relationship(deleteRule: .cascade, inverse: \SocialHandle.person)
    public var handles: [SocialHandle]? = []
    @Relationship(inverse: \Genre.people)
    public var genres: [Genre]? = []
    @Relationship(inverse: \Credit.person)
    public var credits: [Credit]? = []
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.person)
    public var attachments: [MediaAttachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ResourceLink.person)
    public var links: [ResourceLink]? = []

    public init(firstName: String = "", lastName: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        refreshDerived()
    }
}

extension Person {
    public var roles: Set<PersonRole> {
        get { Set(roleValues.compactMap(PersonRole.init(rawValue:))) }
        set { roleValues = newValue.map(\.rawValue).sorted() }
    }

    public var isActor: Bool { roleValues.contains(PersonRole.actor.rawValue) }
    public var isSocial: Bool { roleValues.contains(PersonRole.social.rawValue) }

    public var age: Int? {
        guard let birthDate else { return nil }
        let end = deathDate ?? .now
        return Calendar.current.dateComponents([.year], from: birthDate, to: end).year
    }

    /// À appeler dans chaque `didSet` métier et avant chaque `save`.
    public func refreshDerived() {
        displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        sortName = "\(lastName) \(firstName)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        searchText = [displayName, bio]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        updatedAt = .now
    }
}
