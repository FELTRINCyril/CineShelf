import Foundation
import SwiftData

// MARK: - L18 · Le fil d'activité, et son premier lecteur
//
// **`ActivityRecorder` écrit depuis le prompt 6 et personne n'a jamais relu.** Vérifié : aucun
// `fetch` d'`ActivityEntry` dans le dépôt avant ce fichier. C'est la seule table de la base
// dont on ne savait pas si elle contenait quelque chose de lisible — et une piste d'audit
// qu'on ne lit jamais est une piste d'audit qu'on n'a pas.
//
// Ce que la fiche demande, et qui décide de chaque choix ci-dessous :
//
// - **décroissante** : le fil se lit du plus récent, comme tout journal ;
// - **fenêtrée** : « le fil ne charge pas dix ans d'un coup ». Une bibliothèque active écrit
//   une entrée par geste ; sur deux ans, c'est un tableau que personne n'affiche ;
// - **groupée par jour** : le regroupement est un fait d'affichage, mais il se calcule ici —
//   une vue qui grouperait elle-même referait ce calcul à chaque passe de rendu ;
// - **le libellé vient d'`ActivityDescribing`**, pas de la vue ;
// - **les entrées dont la cible a disparu restent lisibles.** C'est la contrainte qui
//   commande la forme du type : `ActivityEntry.summary` est un libellé **figé au moment de
//   l'écriture**, et c'est fait pour. Résoudre l'entité à la lecture aurait rendu illisible
//   tout ce qui concerne un titre supprimé — c'est-à-dire précisément ce qu'on vient
//   consulter après une suppression.

/// Ce que le fil affiche pour un jour donné.
public struct ActivityDay: Identifiable, Sendable {
    /// Le début du jour, en calendrier courant. Sert d'identifiant et d'en-tête de section.
    public let id: Date
    public let entries: [ActivityItem]

    public init(id: Date, entries: [ActivityItem]) {
        self.id = id
        self.entries = entries
    }
}

/// Une entrée du fil, réduite à ce qui s'affiche.
///
/// **Une valeur et non le `@Model`**, pour une raison qui a déjà mordu ailleurs : un
/// `PersistentModel` appartient au contexte qui l'a lu, et le faire traverser vers un acteur
/// ne compile pas en concurrence stricte. Le fil est aussi ce qu'un widget affichera.
public struct ActivityItem: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let action: ActivityAction?
    public let entityType: ActivityEntityType?
    public let entityID: UUID
    /// Le libellé figé à l'écriture. **Jamais résolu à la lecture.**
    public let summary: String
    public let isUndoable: Bool

    public init(_ entry: ActivityEntry) {
        id = entry.id
        date = entry.createdAt
        action = entry.action
        entityType = entry.entityType
        entityID = entry.entityID
        summary = entry.summary
        isUndoable = entry.isUndoable
    }

    /// Le verbe de l'entrée, en français.
    ///
    /// **Ici et non dans la vue** : la fiche l'exige — « le libellé de chaque entrée construit
    /// depuis `ActivityDescribing` et non dans la vue ». Une entrée dont l'action est inconnue
    /// dit « opération », pas un repli plausible : `action` est déjà `nil` sur un `rawValue`
    /// inconnu, et une piste d'audit dit « je ne sais pas » plutôt que de deviner.
    public var actionLabel: String {
        switch action {
        case .create: "Ajouté"
        case .update: "Modifié"
        case .delete: "Mis à la corbeille"
        case .restore: "Restauré"
        case .merge: "Fusionné"
        case .import: "Importé"
        case .bulkEdit: "Modifié en masse"
        case nil: "Opération"
        }
    }

    public var entityLabel: String {
        switch entityType {
        case .library: "Bibliothèque"
        case .profile: "Profil"
        case .title: "Titre"
        case .person: "Personne"
        case .collection: "Collection"
        case .genre: "Genre"
        case .credit: "Crédit"
        case .media: "Image"
        case .link: "Lien"
        case .savedLink: "Signet"
        case .batch: "Lot"
        case nil: "Entrée"
        }
    }
}

/// Ce que le fil montre, et ce qu'il laisse de côté.
public struct ActivityFilter: Sendable, Hashable {
    /// Les actions retenues. **Vide vaut « toutes »**, comme `TitleFilter` et `GalleryFilter` :
    /// un filtre vide est un filtre inactif, pas un filtre qui ne rend rien.
    public var actions: Set<ActivityAction>
    public var entityTypes: Set<ActivityEntityType>

    public init(actions: Set<ActivityAction> = [], entityTypes: Set<ActivityEntityType> = []) {
        self.actions = actions
        self.entityTypes = entityTypes
    }

    public var isActive: Bool { !actions.isEmpty || !entityTypes.isEmpty }

    public func accepts(_ item: ActivityItem) -> Bool {
        if !actions.isEmpty {
            guard let action = item.action, actions.contains(action) else { return false }
        }
        if !entityTypes.isEmpty {
            guard let type = item.entityType, entityTypes.contains(type) else { return false }
        }
        return true
    }
}

public enum ActivityFeed {

    /// La taille d'une fenêtre de lecture.
    ///
    /// **Cent, et le motif est la fenêtre elle-même, pas le nombre.** La fiche demande que le
    /// fil ne charge pas tout ; la valeur exacte est un compromis entre « une page d'écran » et
    /// « un aller-retour au disque par défilement ». Elle se règle à l'appel.
    public static let pageSize = 100

    /// Les entrées les plus récentes, filtrées et groupées par jour.
    ///
    /// - Parameters:
    ///   - filter: les actions et types retenus. Vide vaut « tous ».
    ///   - limit: la taille de la fenêtre.
    ///   - before: ne rend que les entrées **antérieures** à cette date. C'est ce qui pagine :
    ///     la vue rappelle avec la date de sa dernière entrée. **Un curseur de date et non un
    ///     décalage** : un `offset` se décale dès qu'une entrée s'écrit pendant la lecture, et
    ///     le fil saute alors une ligne — sur un journal qui s'écrit en continu, c'est
    ///     garanti.
    ///   - context: le contexte de lecture.
    /// - Returns: les jours, du plus récent au plus ancien, chacun avec ses entrées dans le
    ///   même ordre.
    /// - Throws: ce que `ModelContext.fetch` lève.
    public static func days(
        matching filter: ActivityFilter = ActivityFilter(),
        limit: Int = pageSize,
        before: Date? = nil,
        in context: ModelContext
    ) throws -> [ActivityDay] {
        group(try items(matching: filter, limit: limit, before: before, in: context))
    }

    /// Les entrées seules, sans regroupement. Sert au widget et aux tests.
    public static func items(
        matching filter: ActivityFilter = ActivityFilter(),
        limit: Int = pageSize,
        before: Date? = nil,
        in context: ModelContext
    ) throws -> [ActivityItem] {
        var descriptor = FetchDescriptor<ActivityEntry>(
            predicate: ActivityQuery.written(before: before),
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

        // **La fenêtre est posée sur le `fetch`, pas après.** Un `fetch` complet suivi d'un
        // `prefix` matérialiserait toutes les entrées — c'est le coût mesuré à `L1` : 248 ms
        // pour 5 000 objets rendus, contre 5,3 ms pour une requête qui en rend 32.
        descriptor.fetchLimit = max(0, limit)

        let items = try context.fetch(descriptor).map(ActivityItem.init)
        // Le filtre s'applique **après** le fetch, et c'est assumé : `action` et `entityType`
        // sont des `rawValue` de `String`, donc un prédicat sur un `Set` d'énumérations
        // demanderait de les convertir en chaînes et de traverser deux ensembles. Sur une
        // fenêtre de cent lignes, la différence n'est pas mesurable ; sur la lisibilité, si.
        //
        // La conséquence est réelle et il faut la dire : une fenêtre filtrée peut rendre
        // **moins** de `limit` entrées alors qu'il en existe d'autres plus loin. La vue
        // pagine sur la date, donc elle les retrouve au tour suivant.
        return filter.isActive ? items.filter(filter.accepts) : items
    }

    /// Regroupe des entrées déjà triées, par jour de calendrier courant.
    ///
    /// **Calendrier courant, à la différence du hero.** Ce n'est pas une incohérence : le hero
    /// doit être identique sur deux appareils au même instant, donc il se cale sur l'époque ;
    /// le fil dit à l'utilisateur ce qu'il a fait « aujourd'hui », donc il se cale sur *son*
    /// minuit. Deux besoins opposés, deux réponses.
    public static func group(_ items: [ActivityItem]) -> [ActivityDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var order: [Date] = []
        var buckets: [Date: [ActivityItem]] = [:]

        for item in items {
            let day = calendar.startOfDay(for: item.date)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(item)
        }
        // L'ordre des jours suit celui des entrées, qui sont déjà décroissantes : trier à
        // nouveau ferait dépendre le résultat de deux sources qui pourraient diverger.
        return order.map { ActivityDay(id: $0, entries: buckets[$0] ?? []) }
    }
}

// MARK: - La requête

extension ActivityQuery {

    /// Les entrées antérieures à une date, ou toutes. Une seule clause, aucune traversée.
    public static func written(before date: Date?) -> Predicate<ActivityEntry>? {
        guard let date else { return nil }
        return #Predicate<ActivityEntry> { $0.createdAt < date }
    }
}

/// Les requêtes du fil. Vide pour l'instant : `written(before:)` vit dans l'extension
/// ci-dessus, avec le service qui l'utilise.
public enum ActivityQuery {}
