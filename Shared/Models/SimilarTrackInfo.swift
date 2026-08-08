import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant/controllers/music/media/tracks.py, similar_tracks()), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Bewusst schlank: der Server liefert volle Track-Objekte, für den
// Radio-Flow wird aber nur die uri gebraucht, um sie direkt in die Queue zu geben.

public struct SimilarTrackInfo: Codable, Equatable, Sendable {
    public let uri: String?

    public init(uri: String?) {
        self.uri = uri
    }
}
