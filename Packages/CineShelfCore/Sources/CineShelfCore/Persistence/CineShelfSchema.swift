import Foundation
import SwiftData

/// La version 1 du schéma.
///
/// Le plan de migration existe dès la v1, même vide : ajouter une propriété
/// après publication sans plan de migration casse les installations.
public enum CineShelfSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Library.self, Profile.self,
            TitleFlag.self, PersonFlag.self, MediaFlag.self,
            Title.self, Person.self, SocialHandle.self,
            TitleCollection.self, Genre.self, Credit.self,
            MediaAsset.self, MediaAttachment.self, MediaCrop.self,
            ResourceLink.self, SavedLink.self, ActivityEntry.self
        ]
    }
}

public enum CineShelfMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [CineShelfSchemaV1.self] }

    public static var stages: [MigrationStage] { [] }
}
