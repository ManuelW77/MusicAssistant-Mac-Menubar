import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/__init__.py, SearchResults), aber noch
// nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Server sendet dank field(default_factory=list) immer Arrays (nie fehlende
// Keys) für alle Kategorien — hier werden nur die vier für dieses Projekt
// relevanten Kategorien decodiert, genres/radio/audiobooks/podcasts/
// sound_effects werden ignoriert (music/search wird mit passendem
// media_types-Filter aufgerufen, sodass diese ohnehin leer zurückkommen).

public struct SearchResultsInfo: Codable, Equatable, Sendable {
    public let tracks: [Track]
    public let albums: [Album]
    public let playlists: [Playlist]
    public let artists: [Artist]

    public init(tracks: [Track], albums: [Album], playlists: [Playlist], artists: [Artist]) {
        self.tracks = tracks
        self.albums = albums
        self.playlists = playlists
        self.artists = artists
    }
}
