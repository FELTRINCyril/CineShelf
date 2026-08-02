import Foundation
import SwiftData

/// Un compte social rattaché à une personne.
@Model
public final class SocialHandle {
    public var id = UUID()
    /// instagram, x, tiktok…
    public var platform: String = ""
    public var handle: String = ""
    public var urlString: String?
    public var createdAt = Date()

    public var person: Person?

    public init(platform: String = "", handle: String = "") {
        self.platform = platform
        self.handle = handle
    }
}
