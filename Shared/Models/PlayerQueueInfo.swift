import Foundation

/// Minimale Repräsentation von `player_queues/get` — dient hier nur noch als
/// Existenz-/Diagnose-Check (siehe Tools/VerifyConnection). Der eigentliche
/// Smart-Crossfade-Status wird NICHT von einem Queue-Feld gelesen: dieser
/// Server liefert dafür kein "smart_fades_active" (fehlt komplett im JSON,
/// nicht nur false) — die Quelle der Wahrheit ist stattdessen der
/// gespeicherte Config-Wert "smart_fades_mode" über
/// config/players/get_value, siehe AppState.loadCrossfadeEnabled().
public struct PlayerQueueInfo: Codable, Equatable, Sendable {
    public let queueId: String

    public init(queueId: String) {
        self.queueId = queueId
    }
}
