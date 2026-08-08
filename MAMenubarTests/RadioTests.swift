import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Radio")
struct RadioTests {
    @Test("encoded PlayMediaArgs als queue_id/media/option")
    func encodesPlayMediaArgsSnakeCase() throws {
        let args = PlayMediaArgs(
            queueId: "player-1",
            media: ["library://track/42", "library://track/43"],
            option: "replace"
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["queue_id"] as? String == "player-1")
        #expect(json?["media"] as? [String] == ["library://track/42", "library://track/43"])
        #expect(json?["option"] as? String == "replace")
    }

    @Test("encoded SimilarTracksArgs als item_id/provider_instance_id_or_domain")
    func encodesSimilarTracksArgsSnakeCase() throws {
        let args = SimilarTracksArgs(itemId: "42", providerInstanceIdOrDomain: "library")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["item_id"] as? String == "42")
        #expect(json?["provider_instance_id_or_domain"] as? String == "library")
    }

    @Test("decodiert SimilarTrackInfo aus JSON mit zusätzlichen Feldern")
    func decodesSimilarTrackInfo() throws {
        let json = """
        {
            "item_id": "99",
            "provider": "builtin",
            "name": "Ein ähnlicher Titel",
            "uri": "library://track/99"
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(SimilarTrackInfo.self)

        #expect(track.uri == "library://track/99")
    }
}
