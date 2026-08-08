import Foundation

/// Request-Umschlag für die Music-Assistant-WebSocket-API:
/// `{"message_id": "...", "command": "...", "args": {...}}`.
struct MassCommandEnvelope<Args: Encodable>: Encodable {
    let messageId: String
    let command: String
    let args: Args
}

/// Leere Argumente für Befehle ohne Parameter (z.B. `players/all`).
public struct NoArgs: Encodable, Sendable {
    public init() {}
}

public struct AuthArgs: Encodable, Sendable {
    public let token: String
    public init(token: String) { self.token = token }
}

public struct PlayerIDArgs: Encodable, Sendable {
    public let playerId: String
    public init(playerId: String) { self.playerId = playerId }
}

public struct VolumeArgs: Encodable, Sendable {
    public let playerId: String
    public let volumeLevel: Int
    public init(playerId: String, volumeLevel: Int) {
        self.playerId = playerId
        self.volumeLevel = volumeLevel
    }
}

public struct CreatePlaylistArgs: Encodable, Sendable {
    public let name: String
    public init(name: String) { self.name = name }
}

public struct AddPlaylistTracksArgs: Encodable, Sendable {
    public let dbPlaylistId: String
    public let uris: [String]
    public init(dbPlaylistId: String, uris: [String]) {
        self.dbPlaylistId = dbPlaylistId
        self.uris = uris
    }
}

public struct ItemByURIArgs: Encodable, Sendable {
    public let uri: String
    public init(uri: String) { self.uri = uri }
}

/// Feldname bewusst `item`, nicht `uri` — so heißt der Server-Parameter von
/// `music/favorites/add_item` (akzeptiert dort auch einen reinen URI-String).
public struct AddFavoriteArgs: Encodable, Sendable {
    public let item: String
    public init(item: String) { self.item = item }
}

public struct RemoveFavoriteArgs: Encodable, Sendable {
    public let mediaType: String
    public let libraryItemId: String
    public init(mediaType: String, libraryItemId: String) {
        self.mediaType = mediaType
        self.libraryItemId = libraryItemId
    }
}

public struct PlayMediaArgs: Encodable, Sendable {
    public let queueId: String
    public let media: [String]
    public let option: String
    public init(queueId: String, media: [String], option: String) {
        self.queueId = queueId
        self.media = media
        self.option = option
    }
}

/// Ursprünglich nur für music/tracks/similar_tracks angelegt, mittlerweile auch
/// für music/playlists/playlist_tracks und music/albums/album_tracks
/// wiederverwendet — alle drei Commands teilen sich exakt dieselben zwei
/// Pflichtparameter (item_id/provider_instance_id_or_domain).
public struct SimilarTracksArgs: Encodable, Sendable {
    public let itemId: String
    public let providerInstanceIdOrDomain: String
    public init(itemId: String, providerInstanceIdOrDomain: String) {
        self.itemId = itemId
        self.providerInstanceIdOrDomain = providerInstanceIdOrDomain
    }
}

public struct SearchArgs: Encodable, Sendable {
    public let searchQuery: String
    public let mediaTypes: [String]
    // nil → Feld wird beim Encoden weggelassen (Swifts synthesize-Encode nutzt
    // encodeIfPresent für Optionals) → entspricht Pythons Default None ("alle
    // Quellen durchsuchen"). Ein einzelnes Element schränkt auf genau diese
    // Provider-Domain/Instance-ID ein.
    public let providers: [String]?
    public init(
        searchQuery: String,
        mediaTypes: [String] = ["track", "album", "playlist", "artist"],
        providers: [String]? = nil
    ) {
        self.searchQuery = searchQuery
        self.mediaTypes = mediaTypes
        self.providers = providers
    }
}

public struct ProviderIconArgs: Encodable, Sendable {
    public let provider: String
    public let variant: String
    public init(provider: String, variant: String = "default") {
        self.provider = provider
        self.variant = variant
    }
}

public struct ProvidersArgs: Encodable, Sendable {
    public let providerType: String
    public init(providerType: String) {
        self.providerType = providerType
    }
}
