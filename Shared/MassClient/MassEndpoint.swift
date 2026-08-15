import Foundation

public enum MassEndpoint {
    public enum EndpointError: Error, CustomStringConvertible, Sendable {
        case invalidBaseURL

        public var description: String { "Ungültige Music-Assistant-Server-URL" }
    }

    /// Leitet aus einer HTTP(S)-Basis-URL die WebSocket-URL für die Control-API ab
    /// (Schema-Wechsel https→wss/http→ws, Pfad `/ws`).
    public static func webSocketURL(baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw EndpointError.invalidBaseURL
        }
        switch components.scheme {
        case "https": components.scheme = "wss"
        case "http": components.scheme = "ws"
        case "wss", "ws": break
        default: throw EndpointError.invalidBaseURL
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        components.path = path + "/ws"
        guard let url = components.url else { throw EndpointError.invalidBaseURL }
        return url
    }

    /// Liefert die unauthentifizierte Server-Info-URL (`<baseURL>/info`).
    public static func infoURL(baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw EndpointError.invalidBaseURL
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        components.path = path + "/info"
        guard let url = components.url else { throw EndpointError.invalidBaseURL }
        return url
    }

    /// Löst eine vom Server gelieferte (ggf. relative) Bild-URL gegen die Server-Basis-URL auf.
    ///
    /// MA gibt für den `/imageproxy`-Pfad mitunter die intern konfigurierte
    /// LAN-Adresse des Servers zurück (z.B. `192.168.x.x`) statt der öffentlich
    /// erreichbaren Basis-URL hinter einem Reverse-Proxy. macOS' Local-Network-
    /// Privacy blockt Zugriffe auf solche privaten Adressen ohnehin, daher wird
    /// der Host in diesem Fall durch die konfigurierte Server-Basis-URL ersetzt
    /// (Pfad + Query bleiben erhalten). Absolute URLs zu echten externen Hosts
    /// (z.B. Provider-CDN-Bilder) bleiben unverändert.
    public static func resolveImageURL(_ raw: String?, serverBaseURL: URL) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }

        guard let parsed = URL(string: raw), let host = parsed.host, parsed.scheme != nil else {
            return URL(string: raw, relativeTo: serverBaseURL)
        }

        guard isPrivateOrLocalHost(host) else {
            return parsed
        }

        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            return parsed
        }
        components.path = parsed.path
        components.query = parsed.query
        return components.url ?? parsed
    }

    private static func isPrivateOrLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") { return true }
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        switch octets[0] {
        case 10, 127: return true
        case 172: return (16...31).contains(octets[1])
        case 192: return octets[1] == 168
        default: return false
        }
    }
}
