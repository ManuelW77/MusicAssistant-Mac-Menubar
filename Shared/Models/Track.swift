import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, Track/MediaItem/ItemMapping), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Suchergebnisse können sowohl volle Track- als auch schlanke ItemMapping-Objekte
// sein — alle Zusatzfelder sind deshalb optional, beide Bild-Formen (siehe
// MediaThumbnail.swift) werden unterstützt.

public struct Track: Codable, Identifiable, Equatable, Sendable {
    // itemId/provider sind wie beim vollen Track ItemMapping-Pflichtfelder
    // (siehe _MediaItemBase in music-assistant/models) und daher bei
    // Suchergebnissen immer vorhanden — trotzdem optional decodiert, um bei
    // unerwartet schlanken Provider-Antworten nicht das gesamte Track-Decoding
    // scheitern zu lassen (siehe Datei-Kommentar oben).
    struct NameRef: Codable, Equatable, Sendable {
        let name: String
        let itemId: String?
        let provider: String?
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

    /// Navigierbare Referenz auf das Album dieses Tracks (Drill-down aus dem
    /// aktuell laufenden Titel im Menüleisten-Popover, siehe
    /// MenuBarContentView/SearchDestination). `nil`, wenn der Server kein
    /// Album mitliefert oder es die schlanken Pflichtfelder ausnahmsweise nicht hat.
    public var albumRef: MediaItemRef? {
        guard let album, let itemId = album.itemId, let provider = album.provider else { return nil }
        return MediaItemRef(itemId: itemId, provider: provider, name: album.name)
    }

    /// Navigierbare Referenz auf den ersten Interpreten dieses Tracks (siehe
    /// albumRef). Bei mehreren Interpreten bewusst nur der erste — das
    /// Popover zeigt ohnehin nur einen zusammengesetzten Namen an.
    public var primaryArtistRef: MediaItemRef? {
        guard let first = artists?.first, let itemId = first.itemId, let provider = first.provider else {
            return nil
        }
        return MediaItemRef(itemId: itemId, provider: provider, name: first.name)
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
