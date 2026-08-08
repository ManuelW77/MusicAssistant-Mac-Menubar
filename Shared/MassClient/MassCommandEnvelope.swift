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

public struct SimilarTracksArgs: Encodable, Sendable {
    public let itemId: String
    public let providerInstanceIdOrDomain: String
    public init(itemId: String, providerInstanceIdOrDomain: String) {
        self.itemId = itemId
        self.providerInstanceIdOrDomain = providerInstanceIdOrDomain
    }
}
