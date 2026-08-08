import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, Album/MediaItem/ItemMapping), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Suchergebnisse können sowohl volle Album- als auch schlanke ItemMapping-Objekte
// sein — alle Zusatzfelder sind deshalb optional, beide Bild-Formen (siehe
// MediaThumbnail.swift) werden unterstützt.

public struct Album: Codable, Identifiable, Equatable, Sendable {
    struct NameRef: Codable, Equatable, Sendable {
        let name: String
    }

    public let itemId: String
    public let provider: String
    public let name: String
    public var uri: String?
    public var year: Int?
    var artists: [NameRef]?
    var image: MediaImageRef?
    var metadata: MediaThumbnail?

    public var id: String { itemId }

    public var artistNames: String {
        (artists ?? []).map(\.name).joined(separator: ", ")
    }

    public var imageProxyId: String? {
        image?.proxyId ?? metadata?.proxyId
    }

    // Custom init nur wegen `year` (siehe FlexibleDecoding.swift — manche
    // Provider liefern hier einen String statt Int). CodingKeys wird trotz
    // des handgeschriebenen init(from:) weiterhin automatisch synthetisiert.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try container.decode(String.self, forKey: .itemId)
        provider = try container.decode(String.self, forKey: .provider)
        name = try container.decode(String.self, forKey: .name)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        year = try container.decodeFlexibleIntIfPresent(forKey: .year)
        artists = try container.decodeIfPresent([NameRef].self, forKey: .artists)
        image = try container.decodeIfPresent(MediaImageRef.self, forKey: .image)
        metadata = try container.decodeIfPresent(MediaThumbnail.self, forKey: .metadata)
    }
}
