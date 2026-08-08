import Foundation
import MAMenubarLib

// Schritt-0-Debug-Tool: verifiziert das MA-WebSocket-Protokoll gegen einen
// echten Server, bevor die volle App darauf aufbaut.
//
// Verwendung:
//   swift run VerifyConnection https://music.fire-devils.org <TOKEN>

@main
struct VerifyConnectionMain {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3, let baseURL = URL(string: arguments[1]) else {
            print("Verwendung: VerifyConnection <server-basis-url> <token>")
            print("Beispiel:   swift run VerifyConnection https://music.fire-devils.org abc123...")
            exit(1)
        }
        let token = arguments[2]

        let client = MassWebSocketClient()
        do {
            print("Verbinde mit \(baseURL)…")
            try await client.connect(baseURL: baseURL, token: token)
            print("Authentifiziert. Lade Player-Liste…")

            let players: [MAPlayer] = try await client.send("players/all", args: NoArgs())
            print("\n\(players.count) Player gefunden:\n")
            for player in players {
                let state = player.playbackState?.rawValue ?? "?"
                let volume = player.volumeLevel.map(String.init) ?? "?"
                print("- \(player.name) [\(player.playerId)] state=\(state) volume=\(volume) available=\(player.available.map(String.init) ?? "?")")
                if let media = player.currentMedia {
                    print("    now playing: \(media.title ?? "-") — \(media.artist ?? "-")")
                    let durationText = media.duration.map { "\($0)" } ?? "nil"
                    let elapsedText = media.elapsedTime.map { "\($0)" } ?? "nil"
                    print("    duration=\(durationText) elapsed=\(elapsedText)")
                    if let imageUrl = media.imageUrl {
                        let resolved = MassEndpoint.resolveImageURL(imageUrl, serverBaseURL: baseURL)
                        print("    cover (roh): \(imageUrl)")
                        print("    cover (aufgelöst): \(resolved?.absoluteString ?? "nicht auflösbar")")
                    }
                }
            }

            print("\nLade Playlist-Liste…")
            let playlists: [Playlist] = try await client.send("music/playlists/library_items", args: NoArgs())
            print("\n\(playlists.count) Playlist(s) gefunden:\n")
            for playlist in playlists {
                print("- \(playlist.name) [item_id=\(playlist.itemId) provider=\(playlist.provider)] uri=\(playlist.uri ?? "-")")
            }

            if let uri = players.first(where: { $0.currentMedia?.uri != nil })?.currentMedia?.uri {
                print("\nLade Media-Item-Info für \(uri)…")
                let item: MediaItemInfo = try await client.send("music/item_by_uri", args: ItemByURIArgs(uri: uri))
                print("item_id=\(item.itemId) provider=\(item.provider) media_type=\(item.mediaType) favorite=\(item.favorite)")

                print("\nLade ähnliche Titel…")
                let similar: [SimilarTrackInfo] = try await client.send(
                    "music/tracks/similar_tracks",
                    args: SimilarTracksArgs(itemId: item.itemId, providerInstanceIdOrDomain: item.provider)
                )
                print("\(similar.count) ähnliche(r) Titel gefunden:\n")
                for track in similar {
                    print("- uri=\(track.uri ?? "-")")
                }
            } else {
                print("\nKein Player mit laufender Wiedergabe für den item_by_uri-Test gefunden.")
            }

            let searchQuery = players.first(where: { $0.currentMedia?.title != nil })?.currentMedia?.title
                ?? playlists.first?.name
            if let searchQuery {
                print("\nSuche nach „\(searchQuery)“…")
                let results: SearchResultsInfo = try await client.send(
                    "music/search",
                    args: SearchArgs(searchQuery: searchQuery)
                )
                print("Treffer: \(results.tracks.count) Titel, \(results.albums.count) Alben, \(results.playlists.count) Playlists, \(results.artists.count) Interpreten")
                for track in results.tracks.prefix(3) {
                    print("- Titel: \(track.name) — \(track.artistNames) [imageProxyId=\(track.imageProxyId ?? "-")]")
                }

                if let album = results.albums.first {
                    print("\nLade Titel von Album „\(album.name)“…")
                    let tracks: [Track] = try await client.send(
                        "music/albums/album_tracks",
                        args: SimilarTracksArgs(itemId: album.itemId, providerInstanceIdOrDomain: album.provider)
                    )
                    print("\(tracks.count) Titel gefunden, erste 3:")
                    for track in tracks.prefix(3) {
                        print("- \(track.name)")
                    }
                }
            } else {
                print("\nKeine Suchanfrage möglich (kein laufender Titel, keine Playlist).")
            }

            if let playlist = playlists.first {
                print("\nLade Titel von Playlist „\(playlist.name)“…")
                let tracks: [Track] = try await client.send(
                    "music/playlists/playlist_tracks",
                    args: SimilarTracksArgs(itemId: playlist.itemId, providerInstanceIdOrDomain: playlist.provider)
                )
                print("\(tracks.count) Titel gefunden, erste 3:")
                for track in tracks.prefix(3) {
                    print("- \(track.name) — \(track.artistNames)")
                }

                let domain = playlist.sourceProviderDomain ?? playlist.provider
                print("\nLade Provider-Icon für „\(playlist.name)“ (Domain: \(domain))…")
                do {
                    let dataURI: String? = try await client.send(
                        "providers/icon",
                        args: ProviderIconArgs(provider: domain)
                    )
                    if let dataURI {
                        print("Icon erhalten, Länge=\(dataURI.count), Präfix=\(dataURI.prefix(40))")
                    } else {
                        print("Server liefert kein Icon für Domain \(domain) (nil)")
                    }
                } catch {
                    print("providers/icon fehlgeschlagen: \(error)")
                }
            }

            await client.disconnect()
        } catch {
            print("Fehler: \(error)")
            exit(1)
        }
    }
}
