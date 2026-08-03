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

    /// Le diff inversable d'une opération de masse, encodé en JSON.
    ///
    /// Un enregistrement par entité touchée : son identifiant, son type, et pour chaque
    /// champ modifié la valeur d'avant et celle d'après ; pour les relations, ce qui a
    /// été rattaché et détaché. **Un `Data` unique et non une colonne par cas** : le
    /// contenu dépend de l'opération, et figer sa forme dans le schéma reviendrait à
    /// devoir le rouvrir à chaque nouveau type de mutation.
    ///
    /// `nil` sur les entrées ordinaires — créer un titre n'a pas besoin d'être défait,
    /// la corbeille s'en charge. Seules l'édition en masse et la fusion en portent un,
    /// parce qu'elles touchent des dizaines d'enregistrements qu'aucune main ne peut
    /// remettre en place. Écrit et relu par `L20`.
    @Attribute(.externalStorage) public var payload: Data?

    /// Quand cette opération a été annulée, si elle l'a été.
    ///
    /// Sans cet état, rien n'empêcherait d'annuler deux fois le même lot — la seconde
    /// annulation rejouerait le diff à l'envers sur des valeurs déjà restaurées, et
    /// écraserait ce qui aurait été saisi entre-temps. Consommé par `L20`.
    public var undoneAt: Date?

    public init() {}
}

extension ActivityEntry {
    /// Nulle si l'entrée vient d'une version qui journalisait une autre action :
    /// dans une piste d'audit, mieux vaut l'absence qu'une valeur de repli fausse.
    public var action: ActivityAction? { ActivityAction(rawValue: actionRaw) }

    /// Le type d'entité visé. Nul pour la même raison que `action` : une piste d'audit
    /// dit « je ne sais pas » plutôt qu'une valeur de repli plausible et fausse.
    public var entityType: ActivityEntityType? { ActivityEntityType(rawValue: entityTypeRaw) }

    /// `true` si l'opération porte un diff encore annulable.
    public var isUndoable: Bool { payload != nil && undoneAt == nil }
}
