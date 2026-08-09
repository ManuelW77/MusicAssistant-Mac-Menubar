import Foundation

/// Format-Strings mit Interpolation — reine Sprachumschaltung, kein
/// generisches Platzhalter-Templating nötig für nur zwei Sprachen.
public extension L10n {
    static func reconnecting(attempt: Int, _ language: Language) -> String {
        language == .de ? "Erneuter Versuch (\(attempt))…" : "Retry attempt \(attempt)…"
    }

    static func connectionFailed(_ detail: String, _ language: Language) -> String {
        language == .de ? "Verbindung fehlgeschlagen: \(detail)" : "Connection failed: \(detail)"
    }

    static func playerListLoadFailed(_ detail: String, _ language: Language) -> String {
        language == .de
            ? "Player-Liste konnte nicht geladen werden: \(detail)"
            : "Failed to load player list: \(detail)"
    }

    static func versionAvailable(_ version: String, _ language: Language) -> String {
        language == .de ? "Version \(version) verfügbar" : "Version \(version) available"
    }

    static func connectedPlayersFound(_ count: Int, _ language: Language) -> String {
        language == .de ? "Verbunden – \(count) Player gefunden" : "Connected – \(count) players found"
    }

    static func addedToPlaylist(_ name: String, _ language: Language) -> String {
        language == .de ? "Zu „\(name)“ hinzugefügt" : "Added to \"\(name)\""
    }

    static func genericError(_ detail: String, _ language: Language) -> String {
        language == .de ? "Fehler: \(detail)" : "Error: \(detail)"
    }

    static func updateAvailableBody(_ version: String, _ language: Language) -> String {
        language == .de
            ? "Version \(version) ist verfügbar. Klicken, um die Einstellungen zu öffnen."
            : "Version \(version) is available. Click to open Settings."
    }
}
