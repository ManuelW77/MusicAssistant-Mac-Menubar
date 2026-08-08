import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, Artist/MediaItem/ItemMapping), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Suchergebnisse können sowohl volle Artist- als auch schlanke ItemMapping-Objekte
// sein — beide Bild-Formen (siehe MediaThumbnail.swift) werden unterstützt.

public struct Artist: Codable, Identifiable, Equatable, Sendable {
    public let itemId: String
    public let provider: String
    public let name: String
    public var uri: String?
    var image: MediaImageRef?
    var metadata: MediaThumbnail?

    public var id: String { itemId }

    public var imageProxyId: String? {
        image?.proxyId ?? metadata?.proxyId
    }
}
