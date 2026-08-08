import AppKit
import SwiftUI
import MAMenubarLib

/// Kleines Marken-Badge für einen Provider (YouTube/Apple Music/Spotify/…),
/// analog zur MA-Web-UI. Der Server liefert direkt einen fertigen
/// Data-URI-String (SVG oder PNG, base64) über providers/icon.
///
/// Bewusst kein AsyncImage: Provider-Icons sind oft SVG, und AsyncImage lädt
/// Bilder über die ImageIO-Pipeline, die kein SVG rendern kann — nur
/// NSImage(data:) hat echte SVG-Unterstützung, daher wird die Data-URI hier
/// manuell decodiert statt AsyncImage(url:) zu nutzen.
struct ProviderIconView: View {
    let domain: String?
    var size: CGFloat = 16

    @Environment(AppState.self) private var appState
    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(Circle().fill(.background))
                    .padding(2)
            } else if let domain, let symbol = Self.fallbackSymbol(for: domain) {
                // Server-Icon nicht verfügbar (z.B. MA-Server zu alt für
                // providers/icon, siehe catch unten) — lokales SF-Symbol als
                // grobe, aber immerhin unterscheidbare Ersatzdarstellung.
                // Kein Fallback für library/builtin, siehe fallbackSymbol.
                Image(systemName: symbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
                    .frame(width: size, height: size)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Self.fallbackColor(for: domain)))
                    .padding(2)
            }
            // Sonst (z.B. rein lokale Bibliotheks-Playlist ohne externen
            // Provider) → gar nichts anzeigen.
        }
        .task(id: domain) {
            guard let domain else {
                nsImage = nil
                return
            }
            do {
                let dataURI = try await appState.providerIcon(domain: domain)
                nsImage = dataURI.flatMap(Self.decodeDataURI)
                if dataURI != nil, nsImage == nil {
                    print("ProviderIconView: Data-URI für \(domain) konnte nicht als NSImage decodiert werden")
                }
            } catch {
                // error_code 12 (InvalidCommand) mit "Invalid command: providers/icon"
                // bedeutet: der MA-Server kennt diesen Command nicht — er wurde erst
                // am 2026-07-22 im music-assistant/server-Quellcode eingeführt
                // (Commit "Serve provider icons on demand..."). Auf älteren
                // Server-Versionen bleibt das Icon dauerhaft leer, das ist kein
                // Bug in dieser App — der SF-Symbol-Fallback oben springt dann ein.
                print("ProviderIconView: Icon-Laden für \(domain) fehlgeschlagen (ggf. MA-Server zu alt für providers/icon): \(error)")
                nsImage = nil
            }
        }
    }

    private static func decodeDataURI(_ dataURI: String) -> NSImage? {
        guard let commaIndex = dataURI.firstIndex(of: ",") else { return nil }
        let base64 = dataURI[dataURI.index(after: commaIndex)...]
        guard let data = Data(base64Encoded: String(base64)) else { return nil }
        return NSImage(data: data)
    }

    /// Grobe, nicht markenrechtlich exakte Ersatz-Icons für bekannte Domains —
    /// nur zur visuellen Unterscheidung "kommt von woanders", solange der
    /// echte Server-Abruf fehlschlägt. library/builtin bewusst ohne Icon
    /// (rein lokale Playlist, dafür ist kein Provider-Hinweis sinnvoll).
    private static func fallbackSymbol(for domain: String) -> String? {
        switch domain {
        case "library", "builtin":
            return nil
        case "apple_music":
            return "music.note"
        case "spotify":
            return "waveform"
        case "youtube_music", "ytmusic", "youtube":
            return "play.rectangle.fill"
        case "tidal":
            return "drop.fill"
        case "deezer":
            return "music.quarternote.3"
        case "soundcloud":
            return "cloud.fill"
        case "radio_playlist":
            return "dot.radiowaves.left.and.right"
        default:
            return "globe"
        }
    }

    /// Grobe, an den jeweiligen Markenauftritt angelehnte Hintergrundfarbe für
    /// das Fallback-Icon (bessere Sichtbarkeit als reines .secondary-Grau).
    private static func fallbackColor(for domain: String) -> Color {
        switch domain {
        case "apple_music": return .pink
        case "spotify": return .green
        case "youtube_music", "ytmusic", "youtube": return .red
        case "tidal": return .black
        case "deezer": return .purple
        case "soundcloud": return .orange
        case "radio_playlist": return .blue
        default: return .gray
        }
    }
}
