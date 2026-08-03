import Foundation
import SwiftData

/// Une entité que le fil d'activité sait décrire.
public protocol ActivityDescribing {
    var activityEntityID: UUID { get }
    var activityEntityType: ActivityEntityType { get }
    var activitySummary: String { get }
}

extension Library: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .library }
    public var activitySummary: String { name }
}

extension Title: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .title }
    public var activitySummary: String { name }
}

extension Person: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .person }
    public var activitySummary: String { displayName }
}

extension TitleCollection: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .collection }
    public var activitySummary: String { name }
}

extension Genre: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .genre }
    public var activitySummary: String { name }
}

extension Profile: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .profile }
    public var activitySummary: String { name }
}

extension MediaAsset: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .media }
    public var activitySummary: String { mimeType ?? kindRaw }
}
