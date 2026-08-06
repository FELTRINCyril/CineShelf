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

/// **Ajouté par `V5b`**, quand l'écran des signets est devenu le premier à en créer.
///
/// `ActivityEntityType.savedLink` existait depuis la fermeture du schéma et **aucune entité ne
/// s'y déclarait** : un cas d'énumération sans habitant, que `ActivityItem.entityLabel` savait
/// pourtant nommer. C'est le pendant exact de `ActivityEntry`, écrit quinze prompts avant
/// d'être lu — ici, le type était lisible avant d'être écrivable.
extension SavedLink: ActivityDescribing {
    public var activityEntityID: UUID { id }
    public var activityEntityType: ActivityEntityType { .savedLink }
    /// Le nom quand il existe, sinon l'adresse. **Jamais une chaîne vide** : le résumé est
    /// figé à l'écriture et relu après suppression, donc une entrée vide serait définitive.
    public var activitySummary: String {
        if let name, !name.isEmpty { return name }
        return urlString.isEmpty ? "Signet sans adresse" : urlString
    }
}
