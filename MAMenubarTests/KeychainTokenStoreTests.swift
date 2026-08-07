import Foundation
import Testing
@testable import MAMenubarLib

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {
    // Eigener Service-Name pro Testlauf, damit Tests sich nicht gegenseitig
    // oder eine echte installierte App stören.
    private func makeStore() -> KeychainTokenStore {
        KeychainTokenStore(service: "org.fire-devils.MAMenubar.tests.\(UUID().uuidString)")
    }

    @Test("save/load/delete-Roundtrip")
    func roundtrip() throws {
        let store = makeStore()
        #expect(try store.load() == nil)

        try store.save("token-123")
        #expect(try store.load() == "token-123")

        try store.save("token-456")
        #expect(try store.load() == "token-456")

        try store.delete()
        #expect(try store.load() == nil)
    }
}
