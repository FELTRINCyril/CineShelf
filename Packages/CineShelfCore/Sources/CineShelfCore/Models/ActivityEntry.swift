import Foundation
import SwiftData

/// Une entrée du journal d'activité : alimente l'écran « Fil » et donne une
/// piste d'audit pour les fusions et les imports.
@Model
public final class ActivityEntry {
    public var id = UUID()
    /// create, update, delete, merge, import…
    public var actionRaw: String = ""
    public var entityTypeRaw: String = ""
    public var entityID = UUID()
    public var summary: String = ""
    public var createdAt = Date()

    public init() {}
}
