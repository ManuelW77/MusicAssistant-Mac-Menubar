import Foundation

/// Repräsentation von `player_queues/get`. `crossfadeEnabled` bildet das
/// Server-Feld `crossfade_enabled` auf `PlayerQueue` ab — anders als das
/// früher fehlende `smart_fades_active` wird es auf Servern ab 2.10.0
/// (music-assistant/server#4373) immer serialisiert und ist dort die Quelle
/// der Wahrheit für den Crossfade-Status (siehe AppState.loadCrossfadeEnabled(),
/// AppState.usesQueueCrossfadeAPI). Auf älteren Servern bleibt der Wert nil
/// und AppState liest stattdessen die Player-Config (`smart_fades_mode`).
public struct PlayerQueueInfo: Codable, Equatable, Sendable {
    public let queueId: String
    public let crossfadeEnabled: Bool?

    public init(queueId: String, crossfadeEnabled: Bool? = nil) {
        self.queueId = queueId
        self.crossfadeEnabled = crossfadeEnabled
    }
}
