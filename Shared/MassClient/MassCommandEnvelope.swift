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

/// Für `players/cmd/group` — fügt playerId der Gruppe von targetPlayer hinzu
/// (targetPlayer ist der Gruppenleiter, dessen Queue-ID zugleich seine
/// Player-ID ist). `players/cmd/ungroup` (Entfernen) braucht dagegen nur die
/// Player-ID des zu entfernenden Mitglieds, dafür reicht PlayerIDArgs.
public struct GroupArgs: Encodable, Sendable {
    public let playerId: String
    public let targetPlayer: String
    public init(playerId: String, targetPlayer: String) {
        self.playerId = playerId
        self.targetPlayer = targetPlayer
    }
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
/// für music/playlists/playlist_tracks, music/albums/album_tracks und die
/// Artist-Drill-down-Commands (music/artists/artist_tracks, top_tracks,
/// artist_albums) wiederverwendet — alle teilen sich exakt dieselben zwei
/// Pflichtparameter (item_id/provider_instance_id_or_domain), verifiziert
/// gegen music-assistant/server: controllers/music/media/artists.py.
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

/// Bewusst nicht PlayerIDArgs wiederverwendet: der Server-Parametername heißt
/// hier queue_id, nicht player_id — auch wenn der Wert identisch ist
/// (queue_id == player_id, siehe player_queues-Controller-README).
public struct QueueIDArgs: Encodable, Sendable {
    public let queueId: String
    public init(queueId: String) { self.queueId = queueId }
}

/// Für `config/players/save` — Fallback für Server vor
/// music-assistant/server#4373 (21.06.2026), das Crossfade von einer
/// Pro-Player- zu einer Pro-Queue-Einstellung verschoben hat. Auf diesem
/// älteren Stand ist Crossfade ein Config-Entry `smart_fades_mode`
/// (String-Enum `smart_crossfade`/`standard_crossfade`/`disabled`) auf der
/// PLAYER-Konfiguration. Ab Serverversion 2.10.0 (enthält #4373 bereits im
/// frühesten Dev-Build) wird stattdessen `QueueCrossfadeArgs` verwendet,
/// siehe `AppState.usesQueueCrossfadeAPI`.
public struct PlayerConfigSaveArgs: Encodable, Sendable {
    public let playerId: String
    public let values: [String: String]
    public init(playerId: String, values: [String: String]) {
        self.playerId = playerId
        self.values = values
    }
}

/// Für `config/players/get_value` — liest `smart_fades_mode` auf Servern vor
/// #4373 (siehe `PlayerConfigSaveArgs`).
public struct PlayerConfigGetValueArgs: Encodable, Sendable {
    public let playerId: String
    public let key: String
    public init(playerId: String, key: String) {
        self.playerId = playerId
        self.key = key
    }
}

/// Für `player_queues/crossfade` — der Bool-Toggle-Befehl auf Servern ab
/// 2.10.0 (music-assistant/server#4373), der Crossfade direkt auf der Queue
/// (queue_id == player_id) statt der Player-Config setzt.
public struct QueueCrossfadeArgs: Encodable, Sendable {
    public let queueId: String
    public let crossfadeEnabled: Bool
    public init(queueId: String, crossfadeEnabled: Bool) {
        self.queueId = queueId
        self.crossfadeEnabled = crossfadeEnabled
    }
}

/// Für `player_queues/shuffle` — der Bool-Toggle-Befehl für Zufallswiedergabe
/// auf der Queue (queue_id == player_id), analog zu `QueueCrossfadeArgs`.
public struct QueueShuffleArgs: Encodable, Sendable {
    public let queueId: String
    public let shuffleEnabled: Bool
    public init(queueId: String, shuffleEnabled: Bool) {
        self.queueId = queueId
        self.shuffleEnabled = shuffleEnabled
    }
}
