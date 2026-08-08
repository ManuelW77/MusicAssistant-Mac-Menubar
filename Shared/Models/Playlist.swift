import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, _MediaItemBase), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).

public struct Playlist: Codable, Identifiable, Equatable, Sendable {
    public let itemId: String
    public let provider: String
    public var name: String
    public var uri: String?

    public var id: String { itemId }

    public init(itemId: String, provider: String, name: String, uri: String? = nil) {
        self.itemId = itemId
        self.provider = provider
        self.name = name
        self.uri = uri
    }
}
