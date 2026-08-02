import Testing

@testable import MediaKit

@Test("Le pipeline suit la version de schéma du cœur métier")
func pipelineTracksCoreSchema() {
    #expect(MediaKit.supportedSchemaVersion == 1)
}

@Test("Le format de cache démarre en version 1")
func cacheFormatVersionIsOne() {
    #expect(MediaKit.cacheFormatVersion == 1)
}
