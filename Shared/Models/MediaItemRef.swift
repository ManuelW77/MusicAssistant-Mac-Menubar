import Foundation

/// Schlanke Referenz auf ein verschachteltes Item (z.B. den Artist oder das
/// Album eines Track) für Navigationszwecke. Entspricht dem MA-Servermodell
/// `ItemMapping`, das `item_id`/`provider` immer mitliefert (siehe
/// `_MediaItemBase` in music-assistant/models) — reicht aus, um die Detail-
/// bzw. Titel-Kommandos (z.B. `music/albums/album_tracks`) ohne einen
/// separaten Nachlade-Schritt aufzurufen.
public struct MediaItemRef: Equatable, Sendable {
    public let itemId: String
    public let provider: String
    public let name: String

    public init(itemId: String, provider: String, name: String) {
        self.itemId = itemId
        self.provider = provider
        self.name = name
    }
}
