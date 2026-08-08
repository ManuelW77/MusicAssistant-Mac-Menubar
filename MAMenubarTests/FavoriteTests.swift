import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Favorite")
struct FavoriteTests {
    @Test("decodiert MediaItemInfo aus JSON mit zusätzlichen Feldern")
    func decodesMediaItemInfo() throws {
        let json = """
        {
            "item_id": "123",
            "provider": "builtin",
            "media_type": "track",
            "favorite": true,
            "name": "Ein Titel",
            "duration": 210
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let item = try value.decode(MediaItemInfo.self)

        #expect(item.itemId == "123")
        #expect(item.provider == "builtin")
        #expect(item.mediaType == "track")
        #expect(item.favorite == true)
    }

    @Test("encoded RemoveFavoriteArgs als media_type/library_item_id")
    func encodesRemoveFavoriteArgsSnakeCase() throws {
        let args = RemoveFavoriteArgs(mediaType: "track", libraryItemId: "123")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["media_type"] as? String == "track")
        #expect(json?["library_item_id"] as? String == "123")
    }
}
