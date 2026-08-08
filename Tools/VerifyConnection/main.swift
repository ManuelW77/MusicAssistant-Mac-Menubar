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
                    if let imageUrl = media.imageUrl {
                        let resolved = MassEndpoint.resolveImageURL(imageUrl, serverBaseURL: baseURL)
                        print("    cover (roh): \(imageUrl)")
                        print("    cover (aufgelöst): \(resolved?.absoluteString ?? "nicht auflösbar")")
                    }
                }
            }

            await client.disconnect()
        } catch {
            print("Fehler: \(error)")
            exit(1)
        }
    }
}
