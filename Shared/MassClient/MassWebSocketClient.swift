import Foundation

/// Dünner async/await-Client für die Music-Assistant-WebSocket-API.
///
/// Protokoll (siehe Plan-Recherche, noch nicht 100% gegen den echten Server
/// verifiziert — dafür existiert das VerifyConnection-CLI-Tool):
/// Request:  {"message_id": "...", "command": "...", "args": {...}}
/// Erfolg:   {"message_id": "...", "result": ...}  (ggf. über mehrere
///           Nachrichten mit "partial": true verteilt, bei Listen-Commands)
/// Fehler:   {"message_id": "...", "error_code": ..., "error": "..."}
/// Event:    {"event": "...", "object_id": "...", "data": {...}}
public actor MassWebSocketClient {
    public enum ClientError: Error, CustomStringConvertible, Sendable {
        case notConnected
        case connectionClosed
        case encodingFailed

        public var description: String {
            switch self {
            case .notConnected: return "Nicht mit Music Assistant verbunden"
            case .connectionClosed: return "Verbindung zu Music Assistant wurde getrennt"
            case .encodingFailed: return "Anfrage konnte nicht codiert werden"
            }
        }
    }

    private final class PendingCommand {
        var accumulated: [JSONValue] = []
        let continuation: CheckedContinuation<JSONValue, Error>
        init(continuation: CheckedContinuation<JSONValue, Error>) {
            self.continuation = continuation
        }
    }

    private var task: URLSessionWebSocketTask?
    private var pending: [String: PendingCommand] = [:]
    private var receiveTask: Task<Void, Never>?
    private let eventStream: AsyncStream<MassEvent>
    private let eventContinuation: AsyncStream<MassEvent>.Continuation

    public private(set) var isConnected = false

    public init() {
        var continuation: AsyncStream<MassEvent>.Continuation!
        eventStream = AsyncStream { continuation = $0 }
        eventContinuation = continuation
    }

    public func events() -> AsyncStream<MassEvent> {
        eventStream
    }

    public func connect(baseURL: URL, token: String) async throws {
        let wsURL = try MassEndpoint.webSocketURL(baseURL: baseURL)
        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: wsURL)
        wsTask.resume()
        task = wsTask

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        // Erste Server-Nachricht ist üblicherweise Server-Info ohne message_id/event
        // und wird von receiveLoop()/handle() stillschweigend ignoriert.
        _ = try await sendRaw("auth", args: AuthArgs(token: token))
        isConnected = true
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        failAllPending(with: ClientError.connectionClosed)
        eventContinuation.finish()
    }

    /// Sendet einen Befehl und decodiert das Ergebnis in den gewünschten Typ.
    public func send<Args: Encodable, Result: Decodable>(_ command: String, args: Args) async throws -> Result {
        let raw = try await sendRaw(command, args: args)
        return try raw.decode(Result.self)
    }

    /// Sendet einen Befehl und liefert das rohe Ergebnis, ohne es zu decodieren
    /// (für Fire-and-forget-Player-Kommandos, deren Erfolgs-Payload uns nicht interessiert).
    @discardableResult
    public func sendRaw<Args: Encodable>(_ command: String, args: Args) async throws -> JSONValue {
        guard let task else { throw ClientError.notConnected }

        let messageId = UUID().uuidString
        let envelope = MassCommandEnvelope(messageId: messageId, command: command, args: args)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let payload: Data
        do {
            payload = try encoder.encode(envelope)
        } catch {
            throw ClientError.encodingFailed
        }
        guard let text = String(data: payload, encoding: .utf8) else {
            throw ClientError.encodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[messageId] = PendingCommand(continuation: continuation)
            let sendTask = task
            Task {
                do {
                    try await sendTask.send(.string(text))
                } catch {
                    self.failPending(messageId, error: error)
                }
            }
        }
    }

    private func receiveLoop() async {
        guard let task else { return }
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                isConnected = false
                failAllPending(with: ClientError.connectionClosed)
                eventContinuation.finish()
                return
            }
            handle(message)
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let value): data = value
        case .string(let value): data = Data(value.utf8)
        @unknown default: return
        }

        guard let frame = try? JSONDecoder().decode(MassRawFrame.self, from: data) else { return }

        if let eventName = frame.event {
            let event = MassEvent(event: MassEventType(rawValue: eventName), objectId: frame.objectId, data: frame.data)
            eventContinuation.yield(event)
            return
        }

        guard let messageId = frame.messageId, let command = pending[messageId] else { return }

        if let errorCode = frame.errorCode {
            command.continuation.resume(throwing: MassAPIError(
                code: errorCode,
                message: frame.error ?? "Unbekannter Fehler",
                translationKey: frame.translationKey
            ))
            pending.removeValue(forKey: messageId)
            return
        }

        if frame.partial == true {
            if case .array(let items)? = frame.result {
                command.accumulated.append(contentsOf: items)
            }
            return
        }

        var finalResult = frame.result ?? .null
        if !command.accumulated.isEmpty, case .array(let items)? = frame.result {
            finalResult = .array(command.accumulated + items)
        } else if !command.accumulated.isEmpty {
            finalResult = .array(command.accumulated)
        }

        command.continuation.resume(returning: finalResult)
        pending.removeValue(forKey: messageId)
    }

    private func failPending(_ messageId: String, error: Error) {
        if let command = pending.removeValue(forKey: messageId) {
            command.continuation.resume(throwing: error)
        }
    }

    private func failAllPending(with error: Error) {
        for command in pending.values {
            command.continuation.resume(throwing: error)
        }
        pending.removeAll()
    }
}
