import Foundation
import SwiftData

/// Un catalogue : des titres, des personnes, des collections, des genres.
///
/// Distinct de `Profile`, qui est une personne qui consulte. C'est cette
/// séparation qui couvre à la fois le modèle Netflix (plusieurs profils sur la
/// même bibliothèque) et le bac à sable (un profil sur sa propre bibliothèque).
@Model
public final class Library {
    public var id = UUID()
    public var name: String = "Ma bibliothèque"
    public var isDefault: Bool = false
    public var isSandbox: Bool = false
    public var sortIndex: Int = 0
    public var createdAt = Date()
    public var updatedAt = Date()

    @Relationship(deleteRule: .cascade, inverse: \Title.library)
    public var titles: [Title]? = []
    @Relationship(deleteRule: .cascade, inverse: \Person.library)
    public var people: [Person]? = []
    @Relationship(deleteRule: .cascade, inverse: \TitleCollection.library)
    public var collections: [TitleCollection]? = []
    @Relationship(deleteRule: .cascade, inverse: \Genre.library)
    public var genres: [Genre]? = []
    @Relationship(deleteRule: .cascade, inverse: \SavedLink.library)
    public var savedLinks: [SavedLink]? = []

    @Relationship(deleteRule: .nullify, inverse: \Profile.library)
    public var profiles: [Profile]? = []
    /// Le côté inverse de `ImportMapping.library`.
    ///
    /// Sans lui, le miroir CloudKit refuse le schéma **entier** — « all relationships
    /// have an inverse ». C'est le deuxième cas du projet, après `TitleCollection.links`
    /// (`docs/02` §3.7), et `CloudKitConformanceTests` l'a attrapé au premier lancement
    /// en nommant la relation fautive.
    public var importMappings: [ImportMapping]? = []

    public init(name: String = "Ma bibliothèque", isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
