import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Crossfade")
struct CrossfadeTests {
    @Test("encoded PlayerConfigSaveArgs als player_id/values")
    func encodesPlayerConfigSaveArgsSnakeCase() throws {
        let args = PlayerConfigSaveArgs(playerId: "player-1", values: ["smart_fades_mode": "smart_crossfade"])
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["player_id"] as? String == "player-1")
        let values = json?["values"] as? [String: String]
        #expect(values?["smart_fades_mode"] == "smart_crossfade")
    }

    @Test("encoded QueueIDArgs als queue_id")
    func encodesQueueIDArgsSnakeCase() throws {
        let args = QueueIDArgs(queueId: "player-1")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["queue_id"] as? String == "player-1")
    }

    @Test("decodiert PlayerQueueInfo aus JSON mit zusätzlichen Feldern")
    func decodesPlayerQueueInfo() throws {
        let json = """
        {
            "queue_id": "player-1",
            "active": true,
            "display_name": "Wohnzimmer",
            "available": true,
            "items": 12
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let queue = try value.decode(PlayerQueueInfo.self)

        #expect(queue.queueId == "player-1")
    }

    @Test("encoded PlayerConfigGetValueArgs als player_id/key")
    func encodesPlayerConfigGetValueArgsSnakeCase() throws {
        let args = PlayerConfigGetValueArgs(playerId: "player-1", key: "smart_fades_mode")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["player_id"] as? String == "player-1")
        #expect(json?["key"] as? String == "smart_fades_mode")
    }
}
