import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/media_item.py, _MediaItemBase), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).

public struct Playlist: Codable, Identifiable, Equatable, Sendable {
    struct ProviderMappingRef: Codable, Equatable, Sendable {
        let providerDomain: String
    }

    public let itemId: String
    public let provider: String
    public var name: String
    public var uri: String?
    var image: MediaImageRef? = nil
    var metadata: MediaThumbnail? = nil
    var providerMappings: [ProviderMappingRef]? = nil

    public var id: String { itemId }

    public var imageProxyId: String? {
        image?.proxyId ?? metadata?.proxyId
    }

    /// Für Playlists zeigt die MA-Web-UI bewusst das Icon des Quell-Providers
    /// (YouTube/Apple Music/Spotify/…) statt "library" — gelesen aus dem
    /// ersten provider_mappings-Eintrag, mit provider als Fallback (z.B. für
    /// schlanke ItemMapping-Suchergebnisse ohne provider_mappings).
    public var sourceProviderDomain: String? {
        providerMappings?.first?.providerDomain ?? provider
    }

    public init(itemId: String, provider: String, name: String, uri: String? = nil) {
        self.itemId = itemId
        self.provider = provider
        self.name = name
        self.uri = uri
    }
}
