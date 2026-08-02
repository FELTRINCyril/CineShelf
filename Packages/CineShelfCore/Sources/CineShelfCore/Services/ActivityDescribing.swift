import Foundation
import SwiftData

/// Une entité que le fil d'activité sait décrire.
public protocol ActivityDescribing {
    var activityEntityID: UUID { get }
    var activityEntityType: String { get }
    var activitySummary: String { get }
}

extension ActivityDescribing where Self: PersistentModel {
    /// Le nom du type, pour que le journal suive les renommages sans table à part.
    public var activityEntityType: String { String(describing: Self.self) }
}

extension Library: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { name }
}

extension Title: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { name }
}

extension Person: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { displayName }
}

extension TitleCollection: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { name }
}

extension Genre: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { name }
}

extension Profile: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { name }
}

extension MediaAsset: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activitySummary: String { mimeType ?? kindRaw }
}
