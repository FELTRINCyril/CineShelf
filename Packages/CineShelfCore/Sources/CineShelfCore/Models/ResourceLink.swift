import Foundation
import SwiftData

/// Un lien attaché à une entité.
@Model
public final class ResourceLink {
    public var id = UUID()
    public var urlString: String = ""
    public var label: String?
    public var summary: String?
    public var faviconData: Data?
    public var orderIndex: Int = 0
    public var isArchived: Bool = false
    public var createdAt = Date()
    public var updatedAt = Date()

    public var title: Title?
    public var person: Person?
    public var collection: TitleCollection?

    public init(urlString: String = "") {
        self.urlString = urlString
    }
}
