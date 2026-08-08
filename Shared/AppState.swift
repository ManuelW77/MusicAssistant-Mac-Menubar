import Foundation
import Observation

public enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    public var description: String {
        switch self {
        case .disconnected: return "Nicht konfiguriert"
        case .connecting: return "Verbinde…"
        case .connected: return "Verbunden"
        case .reconnecting(let attempt): return "Erneuter Versuch (\(attempt))…"
        case .error(let message): return message
        }
    }
}

/// Orchestriert die Verbindung zu Music Assistant: Connect-Lifecycle,
/// Reconnect mit Backoff, Event-Konsum und die Player-Kommandos für die UI.
@MainActor
@Observable
public final class AppState {
    public private(set) var connectionStatus: ConnectionStatus = .disconnected
    public private(set) var players: [MAPlayer] = []

    public var selectedPlayerID: String? {
        didSet {
            guard selectedPlayerID != oldValue else { return }
            settings.lastSelectedPlayerID = selectedPlayerID
        }
    }

    public var availablePlayers: [MAPlayer] {
        players.filter { settings.allowedPlayerIDs.contains($0.playerId) }
    }

    public var selectedPlayer: MAPlayer? {
        players.first { $0.playerId == selectedPlayerID }
    }

    public let settings: AppSettingsStore
    private let tokenStore: KeychainTokenStore
    private var client: MassWebSocketClient?
    private var supervisorTask: Task<Void, Never>?
    private var reconnectAttempt = 0

    private static let backoffSchedule: [Double] = [1, 2, 4, 8, 16, 30]

    public init(settings: AppSettingsStore = AppSettingsStore(), tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.settings = settings
        self.tokenStore = tokenStore
        self.selectedPlayerID = settings.lastSelectedPlayerID
    }

    public func start() {
        guard supervisorTask == nil else { return }
        supervisorTask = Task { await runSupervised() }
    }

    public func stop() {
        supervisorTask?.cancel()
        supervisorTask = nil
        let current = client
        client = nil
        connectionStatus = .disconnected
        Task { await current?.disconnect() }
    }

    /// Wird nach Änderungen an Server-URL/Token im Settings-Dialog aufgerufen,
    /// um die laufende Verbindung mit den neuen Werten neu aufzubauen.
    public func restart() {
        stop()
        reconnectAttempt = 0
        start()
    }

    private func runSupervised() async {
        while !Task.isCancelled {
            guard let baseURL = settings.serverBaseURL, let token = try? tokenStore.load() else {
                connectionStatus = .disconnected
                try? await Task.sleep(for: .seconds(5))
                continue
            }

            connectionStatus = reconnectAttempt == 0 ? .connecting : .reconnecting(attempt: reconnectAttempt)
            let newClient = MassWebSocketClient()
            do {
                try await newClient.connect(baseURL: baseURL, token: token)
                client = newClient
                connectionStatus = .connected
                reconnectAttempt = 0
                await refreshPlayers()
                await consumeEvents(from: newClient)
            } catch {
                connectionStatus = .error("Verbindung fehlgeschlagen: \(error)")
            }

            client = nil
            if Task.isCancelled { break }
            let delayIndex = min(reconnectAttempt, Self.backoffSchedule.count - 1)
            reconnectAttempt += 1
            try? await Task.sleep(for: .seconds(Self.backoffSchedule[delayIndex]))
        }
    }

    private func consumeEvents(from client: MassWebSocketClient) async {
        for await event in await client.events() {
            handle(event)
        }
    }

    private func handle(_ event: MassEvent) {
        switch event.event {
        case .playerAdded, .playerUpdated:
            guard let data = event.data, let player = try? data.decode(MAPlayer.self) else { return }
            if let index = players.firstIndex(where: { $0.playerId == player.playerId }) {
                players[index] = player
            } else {
                players.append(player)
            }
        case .playerRemoved:
            guard let removedId = event.objectId else { return }
            players.removeAll { $0.playerId == removedId }
        default:
            break
        }
    }

    private func refreshPlayers() async {
        guard let client else { return }
        do {
            let list: [MAPlayer] = try await client.send("players/all", args: NoArgs())
            players = list
            if selectedPlayerID == nil {
                selectedPlayerID = settings.allowedPlayerIDs.first ?? list.first?.playerId
            }
        } catch {
            connectionStatus = .error("Player-Liste konnte nicht geladen werden: \(error)")
        }
    }

    public func playPause() { sendPlayerCommand("players/cmd/play_pause") }
    public func next() { sendPlayerCommand("players/cmd/next") }
    public func previous() { sendPlayerCommand("players/cmd/previous") }

    private func sendPlayerCommand(_ command: String) {
        guard let client, let playerId = selectedPlayerID else { return }
        Task {
            try? await client.sendRaw(command, args: PlayerIDArgs(playerId: playerId))
        }
    }

    public func setVolume(_ level: Int) {
        guard let client, let playerId = selectedPlayerID else { return }
        let clamped = min(max(level, 0), 100)
        Task {
            try? await client.sendRaw("players/cmd/volume_set", args: VolumeArgs(playerId: playerId, volumeLevel: clamped))
        }
    }

    /// Für den "Verbindung testen"-Button im Settings-Dialog: baut eine eigene,
    /// kurzlebige Verbindung auf, ohne den laufenden Client zu beeinflussen.
    public func testConnection(baseURL: URL, token: String) async throws -> [MAPlayer] {
        let testClient = MassWebSocketClient()
        try await testClient.connect(baseURL: baseURL, token: token)
        defer { Task { await testClient.disconnect() } }
        return try await testClient.send("players/all", args: NoArgs())
    }

    /// Speichert Server-URL + Token dauerhaft (URL in UserDefaults, Token im
    /// Keychain) und baut die laufende Verbindung mit den neuen Werten neu auf.
    public func saveCredentials(baseURLString: String, token: String) throws {
        settings.serverBaseURLString = baseURLString
        try tokenStore.save(token)
        restart()
    }

    /// Lädt die Player-Liste der aktuell laufenden Verbindung neu (z.B. für
    /// den "Player neu laden"-Button im Settings-Dialog).
    public func reloadPlayers() async {
        await refreshPlayers()
    }
}
