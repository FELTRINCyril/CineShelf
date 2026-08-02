import CineShelfCore
import SwiftData
import Testing

/// Le test le plus rentable du projet (`docs/04` §9).
///
/// Un `ModelContainer` configuré CloudKit lève à l'initialisation si le schéma
/// viole une contrainte du miroir. Les deux erreurs les plus fréquentes — la
/// propriété non optionnelle sans valeur par défaut et la relation obligatoire
/// ajoutée par distraction — sont attrapées ici, et non après publication.
///
/// Ces tests vivent dans la cible `CineShelfTests` et non dans le package :
/// sous `swift test`, le binaire n'a pas d'identifiant de paquet et CloudKit
/// termine le processus au lieu de lever une erreur.
@Suite("Conformité CloudKit")
struct CloudKitConformanceTests {
    @Test("Le schéma complet s'initialise avec le miroir CloudKit")
    func modelStaysCloudKitCompatible() {
        let schema = Persistence.schema
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .private(Persistence.cloudKitContainerIdentifier)
        )
        #expect(throws: Never.self) {
            try ModelContainer(
                for: schema,
                migrationPlan: CineShelfMigrationPlan.self,
                configurations: [config]
            )
        }
    }

    @Test("Le schéma décrit les 17 entités du modèle")
    func schemaDescribesEveryEntity() {
        #expect(Persistence.schema.entities.count == 17)
        #expect(CineShelfSchemaV1.models.count == 17)
    }

    @Test("Aucune entité ne porte de contrainte d'unicité")
    func noUniquenessConstraint() {
        for entity in Persistence.schema.entities {
            #expect(
                entity.uniquenessConstraints.isEmpty,
                "\(entity.name) porte une contrainte d'unicité, interdite par CloudKit"
            )
        }
    }

    @Test("Toute propriété est optionnelle ou a une valeur par défaut")
    func everyAttributeIsOptionalOrDefaulted() {
        for entity in Persistence.schema.entities {
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name) n'est ni optionnelle ni pourvue d'une valeur par défaut"
                )
            }
        }
    }

    @Test("Toute relation est optionnelle et aucune n'utilise la règle .deny")
    func everyRelationshipIsOptionalAndNeverDenies() {
        for entity in Persistence.schema.entities {
            for relationship in entity.relationships {
                #expect(
                    relationship.isOptional || relationship.isToOneRelationship == false,
                    "\(entity.name).\(relationship.name) est une relation obligatoire"
                )
                #expect(
                    relationship.deleteRule != .deny,
                    "\(entity.name).\(relationship.name) utilise .deny, non supportée par CloudKit"
                )
            }
        }
    }

    @Test("Le plan de migration part de la version 1.0.0")
    func migrationPlanStartsAtVersionOne() {
        #expect(CineShelfSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(CineShelfMigrationPlan.schemas.count == 1)
        #expect(CineShelfMigrationPlan.stages.isEmpty)
    }
}
