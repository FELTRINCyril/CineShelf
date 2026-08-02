import CineShelfCore
import MediaKit
import Testing

@Test("Le pipeline médias et le cœur métier partagent la même version de schéma")
func schemaVersionsAgree() {
    #expect(MediaKit.supportedSchemaVersion == CineShelfCore.schemaVersion)
}

@Test("CloudKit reste désactivé tant que les entitlements ne sont pas en place")
func cloudKitStaysDisabled() {
    #expect(FeatureFlags.cloudKitEnabled == false)
}
