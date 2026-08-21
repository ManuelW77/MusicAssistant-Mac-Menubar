import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, Album/MediaItem/ItemMapping), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Suchergebnisse können sowohl volle Album- als auch schlanke ItemMapping-Objekte
// sein — alle Zusatzfelder sind deshalb optional, beide Bild-Formen (siehe
// MediaThumbnail.swift) werden unterstützt.

public struct Album: Codable, Identifiable, Equatable, Sendable {
    // itemId/provider/uri optional wie bei Track.NameRef (siehe dort) — der
    // Artist-Eintrag kann bei schlanken ItemMapping-Antworten ausnahmsweise
    // fehlen, ohne dass das gesamte Album-Decoding scheitern soll.
    struct NameRef: Codable, Equatable, Sendable {
        let name: String
        let itemId: String?
        let provider: String?
        let uri: String?
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

    /// Navigierbare Referenz auf den ersten Interpreten dieses Albums
    /// (Drill-down aus AlbumDetailView zur Artist-Übersicht, siehe
    /// Track.primaryArtistRef für dasselbe Muster). Bei mehreren Interpreten
    /// bewusst nur der erste — die Kopfzeile zeigt ohnehin nur einen
    /// zusammengesetzten Namen an.
    public var primaryArtistRef: MediaItemRef? {
        guard let first = artists?.first, let itemId = first.itemId, let provider = first.provider else {
            return nil
        }
        return MediaItemRef(itemId: itemId, provider: provider, name: first.name, uri: first.uri)
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
