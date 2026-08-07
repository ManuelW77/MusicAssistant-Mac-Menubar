import Foundation

/// String-basierter Event-Typ statt eines geschlossenen Enums: unbekannte,
/// künftige Event-Namen vom Server dürfen das Decoding niemals zum Absturz bringen.
public struct MassEventType: Decodable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public static let playerAdded = MassEventType(rawValue: "player_added")
    public static let playerUpdated = MassEventType(rawValue: "player_updated")
    public static let playerRemoved = MassEventType(rawValue: "player_removed")
    public static let queueUpdated = MassEventType(rawValue: "queue_updated")

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
}

public struct MassEvent: Decodable, Sendable {
    public let event: MassEventType
    public let objectId: String?
    public let data: JSONValue?

    enum CodingKeys: String, CodingKey {
        case event
        case objectId = "object_id"
        case data
    }
}
