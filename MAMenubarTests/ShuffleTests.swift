import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Shuffle")
struct ShuffleTests {
    @Test("encoded QueueShuffleArgs als queue_id/shuffle_enabled")
    func encodesQueueShuffleArgsSnakeCase() throws {
        let args = QueueShuffleArgs(queueId: "player-1", shuffleEnabled: true)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["queue_id"] as? String == "player-1")
        #expect(json?["shuffle_enabled"] as? Bool == true)
    }

    @Test("decodiert PlayerQueueInfo mit shuffle_enabled aus JSON mit zusätzlichen Feldern")
    func decodesPlayerQueueInfoShuffleEnabled() throws {
        let json = """
        {
            "queue_id": "player-1",
            "active": true,
            "display_name": "Wohnzimmer",
            "available": true,
            "items": 12,
            "shuffle_enabled": true
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let queue = try value.decode(PlayerQueueInfo.self)

        #expect(queue.queueId == "player-1")
        #expect(queue.shuffleEnabled == true)
    }
}
