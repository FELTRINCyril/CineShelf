import Testing

@testable import CineShelfCore

@Test("Le schéma démarre en version 1")
func schemaVersionIsOne() {
    #expect(CineShelfCore.schemaVersion == 1)
}

@Test("CloudKit est désactivé tant que l'abonnement développeur n'est pas en place")
func cloudKitIsDisabled() {
    #expect(FeatureFlags.cloudKitEnabled == false)
}
