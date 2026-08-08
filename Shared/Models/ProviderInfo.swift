import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant/models/provider.py, Provider.to_dict()), aber noch nicht
// gegen den echten Server verifiziert (siehe Tools/VerifyConnection).

public struct ProviderInfo: Codable, Identifiable, Equatable, Sendable {
    public let type: String
    public let domain: String
    public let name: String
    public let instanceId: String
    public var available: Bool?

    public var id: String { instanceId }

    public init(type: String, domain: String, name: String, instanceId: String, available: Bool? = nil) {
        self.type = type
        self.domain = domain
        self.name = name
        self.instanceId = instanceId
        self.available = available
    }
}
