import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, Track/MediaItem/ItemMapping), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Suchergebnisse können sowohl volle Track- als auch schlanke ItemMapping-Objekte
// sein — alle Zusatzfelder sind deshalb optional, beide Bild-Formen (siehe
// MediaThumbnail.swift) werden unterstützt.

public struct Track: Codable, Identifiable, Equatable, Sendable {
    struct NameRef: Codable, Equatable, Sendable {
        let name: String
    }

    public let itemId: String
    public let provider: String
    public let name: String
    public var uri: String?
    // Double statt Int, siehe custom init(from:) unten für die Begründung.
    public var duration: Double?
    var artists: [NameRef]?
    var album: NameRef?
    var image: MediaImageRef?
    var metadata: MediaThumbnail?

    public var id: String { itemId }

    public var artistNames: String {
        (artists ?? []).map(\.name).joined(separator: ", ")
    }

    public var albumName: String? {
        album?.name
    }

    public var imageProxyId: String? {
        image?.proxyId ?? metadata?.proxyId
    }

    // Custom init nur wegen `duration` (siehe FlexibleDecoding.swift — der
    // Server deklariert das Feld als int, manche Provider liefern aber Floats
    // oder Strings). CodingKeys wird trotz des handgeschriebenen init(from:)
    // weiterhin automatisch synthetisiert.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try container.decode(String.self, forKey: .itemId)
        provider = try container.decode(String.self, forKey: .provider)
        name = try container.decode(String.self, forKey: .name)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        duration = try container.decodeFlexibleDoubleIfPresent(forKey: .duration)
        artists = try container.decodeIfPresent([NameRef].self, forKey: .artists)
        album = try container.decodeIfPresent(NameRef.self, forKey: .album)
        image = try container.decodeIfPresent(MediaImageRef.self, forKey: .image)
        metadata = try container.decodeIfPresent(MediaThumbnail.self, forKey: .metadata)
    }
}
