import Foundation
import SwiftData

/// Un lien de casting entre un titre et une personne. Remplace `movie_actor`.
@Model
public final class Credit {
    public var id = UUID()
    public var roleRaw: String = CreditRole.cast.rawValue
    public var characterName: String?
    public var orderIndex: Int = 0
    public var createdAt = Date()

    public var title: Title?
    public var person: Person?

    public init(role: CreditRole = .cast, characterName: String? = nil, orderIndex: Int = 0) {
        self.roleRaw = role.rawValue
        self.characterName = characterName
        self.orderIndex = orderIndex
    }
}

extension Credit {
    public var role: CreditRole {
        get { CreditRole(rawValue: roleRaw) ?? .cast }
        set { roleRaw = newValue.rawValue }
    }
}
