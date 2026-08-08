import Foundation
import Testing
@testable import MAMenubarLib

@Suite("AppSettingsStore", .serialized)
@MainActor
struct AppSettingsStoreTests {
    private func makeStore() -> AppSettingsStore {
        let suiteName = "MAMenubarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppSettingsStore(defaults: defaults)
    }

    @Test("persistiert Server-URL, Whitelist und letzten Player über eine neue Instanz hinweg")
    func roundtrip() {
        let suiteName = "MAMenubarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let store = AppSettingsStore(defaults: defaults)
        store.serverBaseURLString = "https://music.fire-devils.org"
        store.accessToken = "secret-token"
        store.allowedPlayerIDs = ["player-1", "player-2"]
        store.lastSelectedPlayerID = "player-1"

        let reloaded = AppSettingsStore(defaults: defaults)
        #expect(reloaded.serverBaseURLString == "https://music.fire-devils.org")
        #expect(reloaded.accessToken == "secret-token")
        #expect(reloaded.allowedPlayerIDs == ["player-1", "player-2"])
        #expect(reloaded.lastSelectedPlayerID == "player-1")
        #expect(reloaded.serverBaseURL == URL(string: "https://music.fire-devils.org"))
    }

    @Test("fehlender Token ergibt nil")
    func missingTokenIsNil() {
        let store = makeStore()
        #expect(store.accessToken == nil)
    }

    @Test("leere Server-URL ergibt keine gültige URL")
    func emptyURL() {
        let store = makeStore()
        #expect(store.serverBaseURL == nil)
    }
}
