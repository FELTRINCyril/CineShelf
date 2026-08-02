import Testing

@testable import DesignSystem

@Test("Le bundle de ressources du package est accessible")
func resourceBundleIsReachable() {
    #expect(DesignSystem.bundle.bundleURL.lastPathComponent.isEmpty == false)
}
