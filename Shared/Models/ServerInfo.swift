import Foundation

/// Unauthentifizierte Server-Informationen von `GET <baseURL>/info`.
public struct ServerInfo: Codable, Equatable, Sendable {
    public let serverVersion: String
    public let schemaVersion: Int?
    public let baseUrl: String?
    public let serverId: String?
    public let homeassistantAddon: Bool?
    public let onboardDone: Bool?

    public init(
        serverVersion: String,
        schemaVersion: Int? = nil,
        baseUrl: String? = nil,
        serverId: String? = nil,
        homeassistantAddon: Bool? = nil,
        onboardDone: Bool? = nil
    ) {
        self.serverVersion = serverVersion
        self.schemaVersion = schemaVersion
        self.baseUrl = baseUrl
        self.serverId = serverId
        self.homeassistantAddon = homeassistantAddon
        self.onboardDone = onboardDone
    }
}
