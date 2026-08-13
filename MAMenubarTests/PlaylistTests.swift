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

    @Test("decodiert favorite: true aus JSON")
    func decodesFavoritePlaylist() throws {
        let json = #"{"item_id": "42", "provider": "builtin", "name": "Lieblingslieder", "favorite": true}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.favorite == true)
    }

    @Test("favorite defaultet auf false, wenn im JSON nicht vorhanden")
    func defaultsFavoriteToFalse() throws {
        let json = #"{"item_id": "7", "provider": "builtin", "name": "Ohne Favorite-Feld"}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.favorite == false)
    }

    @Test("Favoriten stehen nach Sortierung vorne, Rest behält Reihenfolge")
    func sortsFavoritesFirst() throws {
        let a = Playlist(itemId: "1", provider: "builtin", name: "A")
        let b = Playlist(itemId: "2", provider: "builtin", name: "B", favorite: true)
        let c = Playlist(itemId: "3", provider: "builtin", name: "C")
        let d = Playlist(itemId: "4", provider: "builtin", name: "D", favorite: true)

        let sorted = [a, b, c, d].sorted { $0.favorite && !$1.favorite }

        #expect(sorted.map(\.name) == ["B", "D", "A", "C"])
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
