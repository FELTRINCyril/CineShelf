import Foundation
import SwiftData

/// Rattachement d'un média à exactement une entité.
/// L'exclusivité était un `CHECK` SQL ; elle devient une invariante Swift.
@Model
public final class MediaAttachment {
    public var id = UUID()
    public var slotRaw: String = MediaSlot.gallery.rawValue
    public var orderIndex: Int = 0
    public var createdAt = Date()

    public var asset: MediaAsset?
    public var title: Title?
    public var person: Person?
    public var collection: TitleCollection?

    public init(slot: MediaSlot = .gallery, orderIndex: Int = 0) {
        self.slotRaw = slot.rawValue
        self.orderIndex = orderIndex
    }

    /// Invariante : exactement un parent. Vérifiée en test et avant chaque `save`.
    public var hasExactlyOneOwner: Bool {
        [title != nil, person != nil, collection != nil].filter { $0 }.count == 1
    }
}

extension MediaAttachment {
    public var slot: MediaSlot {
        get { MediaSlot(rawValue: slotRaw) ?? .gallery }
        set { slotRaw = newValue.rawValue }
    }
}
