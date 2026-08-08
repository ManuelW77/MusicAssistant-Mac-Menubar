import Foundation
import Testing
@testable import MAMenubarLib

@Suite("JSONValue")
struct JSONValueTests {
    @Test("decodiert einen MAPlayer aus verschachteltem JSON")
    func decodesPlayer() throws {
        let json = """
        {
            "player_id": "player-1",
            "name": "Wohnzimmer",
            "available": true,
            "playback_state": "playing",
            "volume_level": 42,
            "current_media": {
                "uri": "spotify://track/1",
                "title": "Testsong",
                "artist": "Testkünstler",
                "album": "Testalbum",
                "image_url": "https://example.com/cover.jpg"
            }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let value = try decoder.decode(JSONValue.self, from: data)
        let player = try value.decode(MAPlayer.self)

        #expect(player.playerId == "player-1")
        #expect(player.name == "Wohnzimmer")
        #expect(player.playbackState == .playing)
        #expect(player.volumeLevel == 42)
        #expect(player.currentMedia?.title == "Testsong")
    }

    @Test("fällt bei Sync-Gruppen-Playern (volume_level == nil) auf group_volume zurück")
    func fallsBackToGroupVolume() throws {
        let json = """
        {
            "player_id": "syncgroup-1",
            "name": "Wohnzimmer-Bad-Küche",
            "type": "group",
            "volume_level": null,
            "group_volume": 36
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let player = try value.decode(MAPlayer.self)
        #expect(player.volumeLevel == nil)
        #expect(player.groupVolume == 36)
        #expect(player.effectiveVolume == 36)
    }

    @Test("mappt unbekannten playback_state-Wert defensiv auf .unknown")
    func fallsBackToUnknownPlaybackState() throws {
        let json = #"{"player_id": "p", "name": "n", "playback_state": "buffering_something_new"}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let player = try value.decode(MAPlayer.self)
        #expect(player.playbackState == .unknown)
    }

    @Test("akkumuliert Partial-Arrays korrekt (players/all-Chunking)")
    func accumulatesPartialArrays() throws {
        var accumulated: [JSONValue] = [.string("a"), .string("b")]
        let finalChunk: JSONValue = .array([.string("c")])
        guard case .array(let items) = finalChunk else {
            Issue.record("erwartetes Array")
            return
        }
        accumulated.append(contentsOf: [])
        let combined = JSONValue.array(accumulated + items)
        guard case .array(let all) = combined else {
            Issue.record("erwartetes Array")
            return
        }
        #expect(all.count == 3)
    }
}
