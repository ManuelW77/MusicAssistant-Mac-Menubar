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
