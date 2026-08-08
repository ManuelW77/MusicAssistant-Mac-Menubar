import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, MediaItem/_MediaItemBase), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Bewusst schlank: der Server liefert über music/item_by_uri deutlich mehr Felder
// (name, images, artists, …), aber für den Favoriten-Flow werden nur diese vier
// gebraucht. Überzählige JSON-Felder werden beim Decodieren automatisch ignoriert.

public struct MediaItemInfo: Codable, Equatable, Sendable {
    public let itemId: String
    public let provider: String
    public let mediaType: String
    public var favorite: Bool

    public init(itemId: String, provider: String, mediaType: String, favorite: Bool) {
        self.itemId = itemId
        self.provider = provider
        self.mediaType = mediaType
        self.favorite = favorite
    }
}
