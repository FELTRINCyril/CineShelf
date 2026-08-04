import Foundation

// MARK: - Décrire une mutation sans toucher l'entité
//
// Une mutation de masse se décrit **avant** de savoir sur quoi elle s'appliquera :
// l'interface construit un descripteur, l'exécuteur le déroule sur une sélection.
// C'est ce qui permet à la console de gestion (`V6`) et à l'aperçu d'import (`V8`)
// de partager le même moteur.
//
// **Les relations sont désignées par `UUID`, jamais par objet.** Un `@Model` n'est pas
// `Sendable` : le passer à travers `BulkEditor`, qui est un acteur, ne compile pas en
// concurrence stricte. Et même si c'était possible, un objet appartient au contexte qui
// l'a chargé — le traverser reviendrait à faire écrire l'acteur dans le contexte de
// l'appelant, donc à perdre le « tout ou rien ». L'exécuteur résout les identifiants
// dans son propre contexte.

/// Ce qu'une mutation de masse peut faire à un champ.
///
/// Les quatre opérations de la fiche `L10`. Elles ne sont pas exprimées comme un enum
/// séparé mais portées par les cas de `TitleBulkMutation` et `PersonBulkMutation` :
/// « vider » n'a pas de sens sur un `Bool`, « ajouter » n'en a pas sur un scalaire, et
/// un enum exhaustif par entité rend ces combinaisons impossibles à écrire plutôt qu'à
/// valider à l'exécution.
public enum BulkOperationKind: String, Codable, Sendable, CaseIterable {
    /// Poser une valeur, en remplaçant celle qui s'y trouve.
    case replace
    /// Remettre un champ optionnel à `nil`.
    case clear
    /// Ajouter à une relation, sans toucher à ce qui y est déjà.
    case addToRelation
    /// Retirer d'une relation, sans toucher au reste.
    case removeFromRelation
}

/// Une mutation applicable à une sélection de titres.
public enum TitleBulkMutation: Sendable, Hashable {

    // Scalaires
    case setKind(TitleKind)
    case setRating(Double)
    case clearRating
    case setRuntime(Int)
    case clearRuntime
    case setReleaseDate(Date, precision: DatePrecision)
    case clearReleaseDate
    case setSummary(String)
    case clearSummary
    case setArchived(Bool)
    case setPrivate(Bool)

    // Relations
    case setCollection(UUID)
    case clearCollection
    case setGenres([UUID])
    case addGenres([UUID])
    case removeGenres([UUID])
    case clearGenres

    public var kind: BulkOperationKind {
        switch self {
        case .setKind, .setRating, .setRuntime, .setReleaseDate, .setSummary,
            .setArchived, .setPrivate, .setCollection, .setGenres:
            .replace
        case .clearRating, .clearRuntime, .clearReleaseDate, .clearSummary,
            .clearCollection, .clearGenres:
            .clear
        case .addGenres: .addToRelation
        case .removeGenres: .removeFromRelation
        }
    }

    /// Le nom du champ visé, tel qu'il apparaît dans le diff et dans le journal.
    public var field: String {
        switch self {
        case .setKind: "kind"
        case .setRating, .clearRating: "rating"
        case .setRuntime, .clearRuntime: "runtimeMinutes"
        case .setReleaseDate, .clearReleaseDate: "releaseDate"
        case .setSummary, .clearSummary: "summary"
        case .setArchived: "isArchived"
        case .setPrivate: "isPrivate"
        case .setCollection, .clearCollection: "collection"
        case .setGenres, .addGenres, .removeGenres, .clearGenres: "genres"
        }
    }

    /// Les identifiants de relation que l'exécuteur devra résoudre.
    ///
    /// Séparé de `field` parce que c'est ce qui décide de la validation : un
    /// identifiant absent, supprimé, ou appartenant à une autre bibliothèque est un
    /// refus, et il vaut mieux le découvrir avant d'avoir écrit quoi que ce soit.
    public var referencedIDs: [UUID] {
        switch self {
        case .setCollection(let id): [id]
        case .setGenres(let ids), .addGenres(let ids), .removeGenres(let ids): ids
        default: []
        }
    }

    /// `true` si la mutation porte sur la relation de genres.
    var touchesGenres: Bool {
        switch self {
        case .setGenres, .addGenres, .removeGenres, .clearGenres: true
        default: false
        }
    }

    /// `true` si la mutation porte sur la collection.
    var touchesCollection: Bool {
        switch self {
        case .setCollection, .clearCollection: true
        default: false
        }
    }
}

/// Une mutation applicable à une sélection de personnes.
public enum PersonBulkMutation: Sendable, Hashable {

    // Scalaires
    case setRoles(Set<PersonRole>)
    case setBio(String)
    case clearBio
    case setArchived(Bool)
    case setPrivate(Bool)

    // Relations
    case setGenres([UUID])
    case addGenres([UUID])
    case removeGenres([UUID])
    case clearGenres

    public var kind: BulkOperationKind {
        switch self {
        case .setRoles, .setBio, .setArchived, .setPrivate, .setGenres: .replace
        case .clearBio, .clearGenres: .clear
        case .addGenres: .addToRelation
        case .removeGenres: .removeFromRelation
        }
    }

    public var field: String {
        switch self {
        case .setRoles: "roles"
        case .setBio, .clearBio: "bio"
        case .setArchived: "isArchived"
        case .setPrivate: "isPrivate"
        case .setGenres, .addGenres, .removeGenres, .clearGenres: "genres"
        }
    }

    public var referencedIDs: [UUID] {
        switch self {
        case .setGenres(let ids), .addGenres(let ids), .removeGenres(let ids): ids
        default: []
        }
    }

    var touchesGenres: Bool {
        switch self {
        case .setGenres, .addGenres, .removeGenres, .clearGenres: true
        default: false
        }
    }
}

// MARK: - Refus

/// Pourquoi une entité a été refusée.
///
/// Un cas par cause, et non un `String` libre : l'interface doit pouvoir grouper les
/// refus par cause — c'est ce que l'aperçu d'import fait de six causes sur 417 lignes —
/// et un message libre ne se groupe pas.
public enum BulkRefusalReason: Sendable, Hashable {
    /// L'entité n'existe pas, ou plus, dans le magasin.
    case entityNotFound
    /// L'entité est à la corbeille : la modifier la ferait réapparaître modifiée.
    case entityDeleted
    /// Une relation citée n'existe pas, ou plus.
    case relationNotFound(UUID)
    /// Une relation citée appartient à une autre bibliothèque.
    ///
    /// La cause la plus sournoise : rien ne l'empêche techniquement, et le résultat
    /// est un genre qui fuit d'une bibliothèque à l'autre.
    case relationInAnotherLibrary(UUID)
    /// Un genre dont la cible ne correspond pas à l'entité (`title` sur une personne).
    case genreTargetMismatch(UUID)
    /// Une valeur hors des bornes acceptées.
    case valueOutOfRange(field: String, expected: String)
    /// Une valeur vide là où le champ ne l'accepte pas.
    case valueEmpty(field: String)

    /// Le message montré à l'utilisateur. Dit quoi faire, pas ce qui est faux.
    public var message: String {
        switch self {
        case .entityNotFound:
            "Cet élément n'existe plus. Recharger la sélection."
        case .entityDeleted:
            "Cet élément est à la corbeille. Le restaurer avant de le modifier."
        case .relationNotFound:
            "Une valeur liée n'existe plus. Choisir une autre valeur."
        case .relationInAnotherLibrary:
            "Une valeur liée appartient à une autre bibliothèque. Choisir une valeur de cette bibliothèque."
        case .genreTargetMismatch:
            "Ce genre ne s'applique pas à ce type d'élément."
        case .valueOutOfRange(let field, let expected):
            "\(field) attendu \(expected)."
        case .valueEmpty(let field):
            "\(field) ne peut pas être vide."
        }
    }
}

/// Une entité refusée, et pourquoi.
public struct BulkRefusal: Sendable, Hashable {
    public let entityID: UUID
    public let reason: BulkRefusalReason

    public init(entityID: UUID, reason: BulkRefusalReason) {
        self.entityID = entityID
        self.reason = reason
    }

    /// L'identifiant qui désigne « la mutation entière » et non une entité.
    ///
    /// Une valeur hors bornes est fautive quelle que soit la sélection : le refus ne
    /// vise donc aucune entité. Un `UUID` fixe plutôt qu'un `entityID` optionnel, ce qui
    /// éviterait à chaque appelant de traiter un cas nul qu'il ne sait pas afficher —
    /// l'interface groupe les refus par cause, pas par entité.
    ///
    /// Construit depuis ses octets et non depuis `UUID(uuidString:)`, qui rend un
    /// optionnel : le dépaquetage forcé est interdit hors des tests, et un repli
    /// `?? UUID()` donnerait une valeur différente à chaque lancement.
    public static let mutationScope = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// `true` si ce refus porte sur la mutation elle-même et non sur une entité.
    public var isMutationScope: Bool { entityID == Self.mutationScope }
}

// MARK: - Résultat

/// Ce qu'une application de masse a produit.
///
/// **Tout ou rien.** La validation tourne sur la sélection entière avant la moindre
/// écriture : au premier refus, rien n'est écrit et l'appelant reçoit la liste. Il n'y a
/// pas de cas « partiel », et c'est délibéré — une édition à moitié appliquée sur
/// cinquante enregistrements laisse une base dont personne ne sait plus l'état, et
/// l'annulation de `L20` n'aurait plus de point de départ net.
public enum BulkEditOutcome: Sendable, Equatable {
    /// Toutes les entités ont été modifiées. `activityID` est l'entrée de journal du
    /// lot, celle que `L20` retrouvera pour annuler.
    case applied(count: Int, activityID: UUID)
    /// Rien n'a été écrit. Au moins un refus.
    case refused([BulkRefusal])

    /// Le nombre d'entités modifiées, `0` si l'opération a été refusée.
    public var appliedCount: Int {
        switch self {
        case .applied(let count, _): count
        case .refused: 0
        }
    }

    /// Les refus, vides si l'opération a été appliquée.
    public var refusals: [BulkRefusal] {
        switch self {
        case .applied: []
        case .refused(let refusals): refusals
        }
    }
}
