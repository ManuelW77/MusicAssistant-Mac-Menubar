import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Playlist")
struct PlaylistTests {
    @Test("decodiert eine Playlist aus JSON")
    func decodesPlaylist() throws {
        let json = """
        {
            "item_id": "42",
            "provider": "builtin",
            "name": "Lieblingslieder",
            "uri": "playlist://builtin/42"
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.itemId == "42")
        #expect(playlist.provider == "builtin")
        #expect(playlist.name == "Lieblingslieder")
        #expect(playlist.uri == "playlist://builtin/42")
        #expect(playlist.id == "42")
    }

    @Test("decodiert eine Playlist ohne uri")
    func decodesPlaylistWithoutURI() throws {
        let json = #"{"item_id": "7", "provider": "builtin", "name": "Ohne URI"}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.uri == nil)
    }

    @Test("encoded AddPlaylistTracksArgs.dbPlaylistId als db_playlist_id")
    func encodesAddPlaylistTracksArgsSnakeCase() throws {
        let args = AddPlaylistTracksArgs(dbPlaylistId: "42", uris: ["library://track/1"])
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["db_playlist_id"] as? String == "42")
        #expect(json?["uris"] as? [String] == ["library://track/1"])
    }
}
