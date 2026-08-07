import Foundation
import SwiftData

// MARK: - L16 · La corbeille : lister, restaurer, savoir ce qui va disparaître
//
// **La contrepartie de `MaintenanceService`.** L'une supprime définitivement, l'autre est la
// seule chance de l'en empêcher : sans un écran qui liste, `deletedAt` est une suppression
// différée de trente jours plutôt qu'une corbeille.

/// Une entité à la corbeille, décrite pour être listée sans connaître son type.
///
/// **Un type de valeur et non l'entité elle-même.** L'écran a besoin d'un libellé, d'une date et
/// d'un compte à rebours ; lui passer six tableaux hétérogènes de `@Model` l'obligerait à
/// connaître les six. C'est le même motif qu'`ActivityDescribing`, et pour la même raison.
public struct TrashedItem: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let entity: ActivityEntityType
    /// Le nom montré. Figé à la lecture : l'entité peut disparaître avant le prochain rendu.
    public let label: String
    public let deletedAt: Date
    /// Combien de jours avant la purge. **Peut être négatif** — une entité expirée n'est
    /// supprimée qu'au prochain passage de la maintenance, et il n'y a aucune raison de le
    /// cacher : « expiré, sera purgé au prochain entretien » est une information exacte, là où
    /// un `max(0, …)` ferait croire à un sursis.
    public let daysRemaining: Int

    public init(
        id: UUID, entity: ActivityEntityType, label: String, deletedAt: Date, daysRemaining: Int
    ) {
        self.id = id
        self.entity = entity
        self.label = label
        self.deletedAt = deletedAt
        self.daysRemaining = daysRemaining
    }

    /// **`<= 0` et non `< 0`**, parce que les deux côtés ne comptaient pas pareil : le compte à
    /// rebours tronque en jours de calendrier, la purge compare des **instants**. Un élément
    /// supprimé il y a 30 jours et 2 heures affichait « 0 jour restant », non marqué expiré — et
    /// disparaissait au lancement suivant. C'est exactement le sursis fictif que le commentaire
    /// de `daysRemaining` dit vouloir éviter.
    public var isExpired: Bool { daysRemaining <= 0 }
}

/// Lit la corbeille et restaure ce qu'on lui désigne.
@MainActor
public struct TrashService {

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Tout ce qui est à la corbeille, le plus récemment supprimé d'abord.
    ///
    /// **Trié par date de suppression décroissante**, parce que ce qu'on vient de jeter est ce
    /// qu'on veut récupérer : une corbeille triée par nom oblige à chercher ce qu'on a fait il y
    /// a trente secondes.
    public func items(now: Date = .now, calendar: Calendar = .current) throws -> [TrashedItem] {
        let clock = Clock(now: now, calendar: calendar)
        var items: [TrashedItem?] = []
        items += try trashed(Title.self).map {
            item($0.id, .title, $0.name, $0.deletedAt, clock)
        }
        items += try trashed(Person.self).map {
            item($0.id, .person, $0.displayName, $0.deletedAt, clock)
        }
        items += try trashed(TitleCollection.self).map {
            item($0.id, .collection, $0.name, $0.deletedAt, clock)
        }
        items += try trashed(Genre.self).map {
            item($0.id, .genre, $0.name, $0.deletedAt, clock)
        }
        items += try trashed(SavedLink.self).map {
            item($0.id, .savedLink, $0.name ?? $0.urlString, $0.deletedAt, clock)
        }
        items += try trashed(MediaAsset.self).map {
            item($0.id, .media, $0.mimeType ?? "média", $0.deletedAt, clock)
        }
        return items.compactMap { $0 }.sorted { $0.deletedAt > $1.deletedAt }
    }

    /// L'instant de référence et le calendrier, portés ensemble.
    ///
    /// **Un type plutôt que deux paramètres traînés partout** : ils ne se séparent jamais — un
    /// calendrier sans l'instant qu'il mesure ne veut rien dire — et les passer séparément à
    /// six appels faisait dépasser la limite de paramètres, ce qui était le symptôme et non le
    /// problème.
    struct Clock {
        let now: Date
        let calendar: Calendar
    }

    private func item(
        _ id: UUID,
        _ entity: ActivityEntityType,
        _ label: String,
        _ deletedAt: Date?,
        _ clock: Clock
    ) -> TrashedItem? {
        guard let deletedAt else { return nil }
        return TrashedItem(
            id: id, entity: entity, label: label, deletedAt: deletedAt,
            daysRemaining: Self.daysRemaining(
                from: deletedAt, now: clock.now, calendar: clock.calendar))
    }

    /// Combien de jours il reste avant la purge.
    ///
    /// **Compté en jours de calendrier entre les deux instants, et non en secondes divisées.**
    /// C'est la même raison que `MaintenanceService.expiry(from:)` : un changement d'heure
    /// décale la division, et l'affichage dirait « 29 jours » le lendemain d'une suppression.
    ///
    /// Nonisolée et sans magasin, donc assénable sur des instants quelconques — un mardi à
    /// 22 h 13, pas minuit.
    public nonisolated static func daysRemaining(
        from deletedAt: Date, now: Date, calendar: Calendar = .current
    ) -> Int {
        let elapsed = calendar.dateComponents([.day], from: deletedAt, to: now).day ?? 0
        return MaintenanceService.retentionDays - elapsed
    }

    private func trashed<T: PersistentModel & Trashable>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>()).filter { $0.deletedAt != nil }
    }

    /// Restaure une entité désignée par la liste.
    ///
    /// **Passe par le repository de son type et non par `deletedAt = nil`.** Chacun fait deux
    /// choses de plus qui ne se devinent pas : il journalise la restauration dans
    /// `ActivityEntry`, et il **réindexe Spotlight** pour les trois entités qui y sont — c'est
    /// `L3` qui l'exige, et une entité restaurée qui reste hors de l'index est introuvable par
    /// la recherche système sans que rien ne le signale.
    ///
    /// - Returns: `true` si l'entité a été retrouvée et restaurée.
    @discardableResult
    public func restore(_ item: TrashedItem) throws -> Bool {
        try restoreIndexed(item) ?? restoreSecondary(item) ?? false
    }

    /// Les trois entités qui vivent dans l'index Spotlight.
    ///
    /// Séparées des autres parce que leur restauration a une conséquence de plus — la
    /// réindexation — et non pour découper au hasard : c'est la frontière que `L3` a posée.
    /// `nil` signifie « ce n'est pas mon type », `false` « c'est mon type et je ne l'ai pas
    /// trouvé » : les confondre ferait chercher un titre parmi les genres.
    private func restoreIndexed(_ item: TrashedItem) throws -> Bool? {
        switch item.entity {
        case .title:
            guard let entity = try find(Title.self, item.id) else { return false }
            TitleRepository(context: context).restore(entity)
        case .person:
            guard let entity = try find(Person.self, item.id) else { return false }
            PersonRepository(context: context).restore(entity)
        case .collection:
            guard let entity = try find(TitleCollection.self, item.id) else { return false }
            CollectionRepository(context: context).restore(entity)
        default:
            return nil
        }
        return true
    }

    /// Les trois autres : elles journalisent, elles n'indexent pas.
    private func restoreSecondary(_ item: TrashedItem) throws -> Bool? {
        switch item.entity {
        case .genre:
            guard let entity = try find(Genre.self, item.id) else { return false }
            GenreRepository(context: context).restore(entity)
        case .savedLink:
            guard let entity = try find(SavedLink.self, item.id) else { return false }
            SavedLinkRepository(context: context).restore(entity)
        case .media:
            guard let entity = try find(MediaAsset.self, item.id) else { return false }
            MediaRepository(context: context).restore(entity)
        default:
            return nil
        }
        return true
    }

    private func find<T: PersistentModel & Identifiable>(
        _ type: T.Type, _ id: UUID
    ) throws -> T? where T.ID == UUID {
        try context.fetch(FetchDescriptor<T>()).first { $0.id == id }
    }
}
