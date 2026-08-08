import Foundation

/// Rohes eingehendes Frame — kann Server-Info, Event, Erfolgs- oder Fehlerantwort sein.
/// Wird zuerst geparst, um zu entscheiden, wie die Nachricht weiterzuverarbeiten ist.
struct MassRawFrame: Decodable {
    let event: String?
    let objectId: String?
    let data: JSONValue?
    let messageId: String?
    let errorCode: Int?
    let error: String?
    let translationKey: String?
    let partial: Bool?
    let result: JSONValue?

    enum CodingKeys: String, CodingKey {
        case event
        case objectId = "object_id"
        case data
        case messageId = "message_id"
        case errorCode = "error_code"
        // Server-Feldname ist "details", nicht "error" (music_assistant_models/
        // api.py, ErrorResultMessage) — vorher landete hier immer nil, daher
        // zeigte jede Fehlermeldung nur den generischen "Unbekannter Fehler"-
        // Fallback statt des echten Servertexts.
        case error = "details"
        case translationKey = "translation_key"
        case partial
        case result
    }
}

public struct MassAPIError: Error, CustomStringConvertible, Sendable {
    public let code: Int
    public let message: String
    public let translationKey: String?

    public var description: String {
        "Music-Assistant-Fehler \(code): \(message)"
    }
}
