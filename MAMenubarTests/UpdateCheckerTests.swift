import Testing
@testable import MAMenubarLib

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    @Test("erkennt eine neuere Patch-/Minor-/Major-Version")
    func detectsNewerVersions() {
        #expect(UpdateChecker.isNewer("1.0.1", than: "1.0.0"))
        #expect(UpdateChecker.isNewer("1.1.0", than: "1.0.9"))
        #expect(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
    }

    @Test("erkennt gleiche oder ältere Versionen nicht als neuer")
    func doesNotFlagSameOrOlderVersions() {
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.1"))
        #expect(!UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    @Test("behandelt fehlende Versionsteile als 0")
    func handlesMissingComponents() {
        #expect(UpdateChecker.isNewer("1.1", than: "1.0.5"))
        #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
    }
}
