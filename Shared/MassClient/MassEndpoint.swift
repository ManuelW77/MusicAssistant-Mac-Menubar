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

    /// Löst eine vom Server gelieferte (ggf. relative) Bild-URL gegen die Server-Basis-URL auf.
    public static func resolveImageURL(_ raw: String?, serverBaseURL: URL) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }
        return URL(string: raw, relativeTo: serverBaseURL)
    }
}
