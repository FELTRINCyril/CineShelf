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

    /// Maintenu par `refreshDerived()`. Les rôles et les identifiants de genre et
    /// de bibliothèque, sous forme interrogeable. Voir `FilterKey`.
    ///
    /// Les rôles y sont parce que `roleValues` est un tableau de `String` :
    /// SwiftData le persiste en binaire, et un `contains` dessus n'est pas
    /// traduisible en SQL de façon fiable.
    public var filterKeys: String = ""

    /// L'âge au décès, maintenu par `refreshDerived()`. `nil` pour les vivants.
    ///
    /// **Ne pas généraliser ce champ à l'âge tout court.** C'est la simplification
    /// tentante, et elle serait fausse : un vivant vieillit, et son âge dénormalisé
    /// resterait celui de la dernière écriture — faux jusqu'à un mois près au mieux,
    /// jusqu'à des années en pratique, sans que rien ne le signale.
    ///
    /// L'âge au décès, lui, est immuable par nature : le dénormaliser est exact pour
    /// toujours. Les vivants sont donc filtrés autrement, par bornes de `birthDate`
    /// calculées à l'instant de la requête. Voir `PersonFilter.ageClauses`.
    public var ageAtDeath: Int?

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
    ///
    /// Depuis `L1`, cette méthode lit aussi les **relations** de la personne pour
    /// composer `filterKeys`. Toute mutation de relation doit donc l'appeler, y
    /// compris celles qui ne passent pas par la personne — un genre attaché depuis
    /// le genre. Même règle que sur `Title`.
    public func refreshDerived() {
        displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        sortName = "\(lastName) \(firstName)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        searchText = [displayName, bio]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        filterKeys = FilterKey.keys(
            [library?.id].compactMap { $0 }.map(FilterKey.library)
                + (genres ?? []).map { FilterKey.genre($0.id) }
                + roleValues.compactMap(PersonRole.init(rawValue:)).map(FilterKey.role)
        )
        ageAtDeath = deathDate.flatMap { death in
            birthDate.flatMap {
                Calendar.current.dateComponents([.year], from: $0, to: death).year
            }
        }
        updatedAt = .now
    }
}
