import Foundation
import SwiftData

/// La version 1 du schéma — **fermée**.
///
/// Le plan de migration existe dès la v1, même vide : ajouter une propriété
/// après publication sans plan de migration casse les installations.
///
/// > **Le schéma est fermé depuis la passe du 2026-08-03.** Dix-neuf entités, et la
/// > fenêtre où l'on pouvait ajouter un champ en effaçant le magasin est close. Toute
/// > modification ultérieure — un champ, un renommage, une relation — exige un
/// > `VersionedSchema` **nouveau** et un `MigrationStage` qui l'atteint depuis
/// > celui-ci. Pas d'exception « c'est juste un champ optionnel » : c'est précisément
/// > la forme que prend la première migration oubliée.
/// >
/// > L'inventaire qui a précédé la fermeture, et les six manques qu'il a trouvés, sont
/// > dans `docs/journal.md` et sur les fiches `L11`, `L13` et `L20`.
public enum CineShelfSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Library.self, Profile.self,
            TitleFlag.self, PersonFlag.self, MediaFlag.self,
            Title.self, Person.self, SocialHandle.self,
            TitleCollection.self, Genre.self, Credit.self,
            MediaAsset.self, MediaAttachment.self, MediaCrop.self,
            ResourceLink.self, SavedLink.self, ActivityEntry.self,
            ImportMapping.self, LegacyRecord.self
        ]
    }
}

public enum CineShelfMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [CineShelfSchemaV1.self] }

    public static var stages: [MigrationStage] { [] }
}
