import Foundation
import Observation

public enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    /// Parametrisiert (statt `CustomStringConvertible`/ambientem Global), da
    /// `ConnectionStatusView.body` bei einem Sprachwechsel reaktiv neu
    /// rendern muss — ein `nonisolated(unsafe)`-Read (wie in `L10n.text`
    /// für die nonisolated Error-Enum-descriptions) würde von SwiftUIs
    /// Observation-Tracking nicht erkannt.
    public func description(_ language: L10n.Language) -> String {
        switch self {
        case .disconnected: return L10n.text(.statusDisconnected, language)
        case .connecting: return L10n.text(.statusConnecting, language)
        case .connected: return L10n.text(.statusConnected, language)
        case .reconnecting(let attempt): return L10n.reconnecting(attempt: attempt, language)
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
    public private(set) var playlists: [Playlist] = []
    public private(set) var musicProviders: [ProviderInfo] = []

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

    public private(set) var updateInfo: UpdateChecker.UpdateInfo?
    public private(set) var lastUpdateCheckDate: Date?
    public private(set) var isCheckingForUpdate = false

    public let settings: AppSettingsStore
    private var client: MassWebSocketClient?
    private var supervisorTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var providerIconCache: [String: String] = [:]
    private var updateCheckTask: Task<Void, Never>?
    private static let updateCheckInterval: Double = 24 * 60 * 60

    private static let backoffSchedule: [Double] = [1, 2, 4, 8, 16, 30]

    public init(settings: AppSettingsStore = AppSettingsStore()) {
        self.settings = settings
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

    /// Startet die Update-Check-Schleife (24h-Rhythmus + Sofort-Check beim
    /// Start). Bewusst unabhängig von start()/stop()/restart() — der
    /// MA-Verbindungs-Lifecycle, an Server-URL/Token gekoppelt — damit ein
    /// Neuverbinden (z.B. nach Speichern neuer Zugangsdaten) den Update-Status
    /// nicht zurücksetzt.
    public func startUpdateChecks() {
        guard updateCheckTask == nil else { return }
        updateCheckTask = Task { await runUpdateCheckLoop() }
    }

    private func runUpdateCheckLoop() async {
        while !Task.isCancelled {
            await checkForUpdate()
            try? await Task.sleep(for: .seconds(Self.updateCheckInterval))
        }
    }

    /// Auch für den manuellen "Nach Updates suchen"-Button im Settings-Dialog.
    public func checkForUpdate() async {
        isCheckingForUpdate = true
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        updateInfo = await UpdateChecker.checkForUpdate(currentVersion: version)
        lastUpdateCheckDate = Date()
        isCheckingForUpdate = false
    }

    private func runSupervised() async {
        while !Task.isCancelled {
            guard let baseURL = settings.serverBaseURL, let token = settings.accessToken else {
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
                connectionStatus = .error(L10n.connectionFailed("\(error)", uiLanguage))
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
            logCurrentMediaDebugInfo(for: player)
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
            for player in list {
                logCurrentMediaDebugInfo(for: player)
            }
            if selectedPlayerID == nil {
                selectedPlayerID = settings.allowedPlayerIDs.first ?? list.first?.playerId
            }
        } catch {
            connectionStatus = .error(L10n.playerListLoadFailed("\(error)", uiLanguage))
        }
    }

    // Temporäre Diagnose, um zu klären, ob der Server duration/elapsedTime für
    // currentMedia überhaupt befüllt (Grundlage für die Fortschrittsanzeige im
    // Cover) — läuft direkt beim normalen Xcode-Run mit, kein separates CLI-Tool
    // mit eigenem (langsamem) Build nötig.
    private func logCurrentMediaDebugInfo(for player: MAPlayer) {
        guard let media = player.currentMedia else { return }
        let durationText = media.duration.map { "\($0)" } ?? "nil"
        let elapsedText = media.elapsedTime.map { "\($0)" } ?? "nil"
        print("AppState: \(player.name) — duration=\(durationText) elapsed=\(elapsedText)")
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

    /// Speichert Server-URL + Token dauerhaft (beides in UserDefaults, siehe
    /// AppSettingsStore für die Begründung gegen Keychain) und baut die
    /// laufende Verbindung mit den neuen Werten neu auf.
    public func saveCredentials(baseURLString: String, token: String) {
        settings.serverBaseURLString = baseURLString
        settings.accessToken = token
        restart()
    }

    /// Lädt die Player-Liste der aktuell laufenden Verbindung neu (z.B. für
    /// den "Player neu laden"-Button im Settings-Dialog).
    public func reloadPlayers() async {
        await refreshPlayers()
    }

    public enum PlaylistError: Error, CustomStringConvertible, Sendable {
        case noClient
        case noCurrentTrack

        public var description: String {
            switch self {
            case .noClient: return L10n.text(.errorNoClient, L10n.currentLanguage)
            case .noCurrentTrack: return L10n.text(.errorNoCurrentTrack, L10n.currentLanguage)
            }
        }
    }

    /// Lädt alle Library-Playlists neu. Wirft bewusst statt den globalen
    /// connectionStatus zu setzen (anders als refreshPlayers()) — ein
    /// fehlgeschlagener Playlist-Load soll nicht die ganze App als "nicht
    /// verbunden" markieren, sondern lokal in der aufrufenden View landen.
    public func loadPlaylists() async throws {
        guard let client else { throw PlaylistError.noClient }
        let list: [Playlist] = try await client.send("music/playlists/library_items", args: NoArgs())
        playlists = list
    }

    /// Legt eine neue Playlist an und übernimmt sie optimistisch in `playlists`.
    public func createPlaylist(name: String) async throws -> Playlist {
        guard let client else { throw PlaylistError.noClient }
        let playlist: Playlist = try await client.send("music/playlists/create_playlist", args: CreatePlaylistArgs(name: name))
        playlists.append(playlist)
        return playlist
    }

    /// Fügt den aktuell laufenden Titel des gewählten Players zur übergebenen
    /// Playlist hinzu.
    public func addCurrentTrackToPlaylist(_ playlist: Playlist) async throws {
        guard let client else { throw PlaylistError.noClient }
        guard let uri = selectedPlayer?.currentMedia?.uri else { throw PlaylistError.noCurrentTrack }
        try await client.sendRaw(
            "music/playlists/add_playlist_tracks",
            args: AddPlaylistTracksArgs(dbPlaylistId: playlist.itemId, uris: [uri])
        )
    }

    public enum FavoriteError: Error, CustomStringConvertible, Sendable {
        case noClient
        case noCurrentTrack

        public var description: String {
            switch self {
            case .noClient: return L10n.text(.errorNoClient, L10n.currentLanguage)
            case .noCurrentTrack: return L10n.text(.errorNoCurrentTrack, L10n.currentLanguage)
            }
        }
    }

    /// Lädt den Favoriten-Status des aktuell laufenden Titels. Es gibt kein
    /// Event für Favoriten-Änderungen, daher wird hier aktiv nachgefragt statt
    /// passiv aus dem Player-Zustand übernommen.
    public func loadFavoriteStatus() async throws -> Bool {
        guard let client else { throw FavoriteError.noClient }
        guard let uri = selectedPlayer?.currentMedia?.uri else { throw FavoriteError.noCurrentTrack }
        let item: MediaItemInfo = try await client.send("music/item_by_uri", args: ItemByURIArgs(uri: uri))
        return item.favorite
    }

    /// Togglet den Favoriten-Status des aktuell laufenden Titels und gibt den
    /// neuen Status zurück. `remove_item` braucht (anders als `add_item`) die
    /// library item_id + media_type statt der URI, daher der vorgeschaltete
    /// item_by_uri-Aufruf.
    public func toggleFavorite() async throws -> Bool {
        guard let client else { throw FavoriteError.noClient }
        guard let uri = selectedPlayer?.currentMedia?.uri else { throw FavoriteError.noCurrentTrack }
        let item: MediaItemInfo = try await client.send("music/item_by_uri", args: ItemByURIArgs(uri: uri))
        if item.favorite {
            try await client.sendRaw(
                "music/favorites/remove_item",
                args: RemoveFavoriteArgs(mediaType: item.mediaType, libraryItemId: item.itemId)
            )
            return false
        } else {
            try await client.sendRaw("music/favorites/add_item", args: AddFavoriteArgs(item: uri))
            return true
        }
    }

    public enum RadioError: Error, CustomStringConvertible, Sendable {
        case noClient
        case noCurrentTrack

        public var description: String {
            switch self {
            case .noClient: return L10n.text(.errorNoClient, L10n.currentLanguage)
            case .noCurrentTrack: return L10n.text(.errorNoCurrentTrack, L10n.currentLanguage)
            }
        }
    }

    /// Ersetzt die Queue des aktuellen Players durch den aktuell laufenden Titel
    /// gefolgt von ähnlichen Titeln (music/tracks/similar_tracks) und startet
    /// sie sofort. Bewusst nicht über eine `radio_playlist://`-URI gelöst — die
    /// scheiterte am echten Server mit "radio_playlist is not available", obwohl
    /// "Radio starten" in der MA-Web-UI für denselben Titel funktioniert hat;
    /// similar_tracks ist der providerunabhängige Mechanismus, den der
    /// radio_playlist-Provider selbst intern nutzt, also der robustere Weg.
    public func startRadio() async throws {
        guard let client else { throw RadioError.noClient }
        guard let playerId = selectedPlayerID, let uri = selectedPlayer?.currentMedia?.uri else {
            throw RadioError.noCurrentTrack
        }
        let item: MediaItemInfo = try await client.send("music/item_by_uri", args: ItemByURIArgs(uri: uri))
        let similar: [SimilarTrackInfo] = try await client.send(
            "music/tracks/similar_tracks",
            args: SimilarTracksArgs(itemId: item.itemId, providerInstanceIdOrDomain: item.provider)
        )
        let media = [uri] + similar.compactMap(\.uri).filter { $0 != uri }
        try await client.sendRaw(
            "player_queues/play_media",
            args: PlayMediaArgs(queueId: playerId, media: media, option: "replace")
        )
    }

    public enum SearchError: Error, CustomStringConvertible, Sendable {
        case noClient
        case noPlayer

        public var description: String {
            switch self {
            case .noClient: return L10n.text(.errorNoClient, L10n.currentLanguage)
            case .noPlayer: return L10n.text(.errorNoPlayer, L10n.currentLanguage)
            }
        }
    }

    /// Durchsucht die Bibliothek/Provider nach den gewählten Kategorien
    /// (Default: Titel/Alben/Playlists/Interpreten, siehe SearchArgs).
    /// `providers`: nil durchsucht alle Quellen, ein einzelnes Element
    /// schränkt auf genau diese Provider-Domain ein (Quellen-Dropdown).
    public func search(
        query: String,
        mediaTypes: [String] = ["track", "album", "playlist", "artist"],
        providers: [String]? = nil
    ) async throws -> SearchResultsInfo {
        guard let client else { throw SearchError.noClient }
        return try await client.send(
            "music/search",
            args: SearchArgs(searchQuery: query, mediaTypes: mediaTypes, providers: providers)
        )
    }

    /// Lädt die konfigurierten Musik-Provider (für das Quellen-Dropdown der Suche).
    public func loadMusicProviders() async throws {
        guard let client else { throw SearchError.noClient }
        musicProviders = try await client.send("providers", args: ProvidersArgs(providerType: "music"))
    }

    /// Ersetzt die Queue des gewählten Players durch die übergebene URI und
    /// startet sie sofort. Generische Version des letzten Schritts von
    /// startRadio(), hier für beliebige Titel/Alben/Playlists/Interpreten aus
    /// der Suche/dem Playlist-Browser.
    public func play(uri: String) async throws {
        guard let client else { throw SearchError.noClient }
        guard let playerId = selectedPlayerID else { throw SearchError.noPlayer }
        try await client.sendRaw(
            "player_queues/play_media",
            args: PlayMediaArgs(queueId: playerId, media: [uri], option: "replace")
        )
    }

    /// Hängt die übergebene URI ans Ende der Queue des gewählten Players an,
    /// ohne die laufende Wiedergabe zu unterbrechen.
    public func enqueue(uri: String) async throws {
        guard let client else { throw SearchError.noClient }
        guard let playerId = selectedPlayerID else { throw SearchError.noPlayer }
        try await client.sendRaw(
            "player_queues/play_media",
            args: PlayMediaArgs(queueId: playerId, media: [uri], option: "add")
        )
    }

    /// Lädt die Titel der übergebenen Playlist (Drill-down im Suche-Fenster).
    public func loadPlaylistTracks(_ playlist: Playlist) async throws -> [Track] {
        guard let client else { throw SearchError.noClient }
        return try await client.send(
            "music/playlists/playlist_tracks",
            args: SimilarTracksArgs(itemId: playlist.itemId, providerInstanceIdOrDomain: playlist.provider)
        )
    }

    /// Lädt die Titel des übergebenen Albums (Drill-down im Suche-Fenster).
    public func loadAlbumTracks(_ album: Album) async throws -> [Track] {
        guard let client else { throw SearchError.noClient }
        return try await client.send(
            "music/albums/album_tracks",
            args: SimilarTracksArgs(itemId: album.itemId, providerInstanceIdOrDomain: album.provider)
        )
    }

    /// Lädt das Marken-Icon eines Providers (Data-URI, direkt vom Server
    /// gerendert) für die Provider-Badge auf Playlist-Zeilen. In-Memory
    /// gecacht, damit dieselbe Domain nicht bei jedem Zeilen-Render erneut
    /// abgefragt wird.
    public func providerIcon(domain: String) async throws -> String? {
        if let cached = providerIconCache[domain] {
            return cached
        }
        guard let client else { throw SearchError.noClient }
        let dataURI: String? = try await client.send("providers/icon", args: ProviderIconArgs(provider: domain))
        if let dataURI {
            providerIconCache[domain] = dataURI
        }
        return dataURI
    }

    public enum QueueError: Error, CustomStringConvertible, Sendable {
        case noClient
        case noPlayer

        public var description: String {
            switch self {
            case .noClient: return L10n.text(.errorNoClient, L10n.currentLanguage)
            case .noPlayer: return L10n.text(.errorNoPlayer, L10n.currentLanguage)
            }
        }
    }

    // Weder "player_queues/crossfade" (Bool-Befehl) noch das neuere
    // Queue-Config-Entry "crossfade_mode" existieren auf diesem Server
    // ("Invalid command") — er läuft auf einem Stand vor
    // music-assistant/server#4373 (21.06.2026), das Crossfade von einer
    // Pro-Player- zu einer Pro-Queue-Einstellung verschoben hat. Auf diesem
    // älteren Stand ist Crossfade das Config-Entry "smart_fades_mode" auf der
    // PLAYER- (nicht Queue-)Konfiguration, verifiziert im Quellcode des
    // Commits unmittelbar vor #4373. Der Button heißt bewusst
    // "Smart Crossfade", daher togglet er zwischen "smart_crossfade" und
    // "disabled".
    private static let crossfadeConfigKey = "smart_fades_mode"
    private static let crossfadeOnValue = "smart_crossfade"
    private static let crossfadeOffValue = "disabled"

    /// Lädt den aktuellen Smart-Crossfade-Status des gewählten Players.
    ///
    /// Liest bewusst den gespeicherten Config-Wert (`config/players/get_value`)
    /// statt eines abgeleiteten Felds auf der Queue: `player_queues/get` liefert
    /// auf diesem Server kein `smart_fades_active` — das Feld fehlt im JSON
    /// komplett (nicht nur `false`), das tolerante Decoding las das bislang
    /// immer stillschweigend als "aus", wodurch Ausschalten es tatsächlich
    /// immer wieder einschaltete.
    public func loadCrossfadeEnabled() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }
        let raw = try await client.sendRaw(
            "config/players/get_value",
            args: PlayerConfigGetValueArgs(playerId: playerId, key: Self.crossfadeConfigKey)
        )
        let mode = (try? raw.decode(String.self)) ?? Self.crossfadeOffValue
        return mode == Self.crossfadeOnValue
    }

    /// Togglet Smart Crossfade für die Queue des gewählten Players und gibt
    /// den neuen Status zurück. Ein Konfigurationswechsel dieses Entries löst
    /// serverseitig zwar bei laufender Wiedergabe automatisch einen
    /// Stop+Resume aus (requires_reload), das reicht aber laut Nutzeranforderung
    /// nicht als alleinige Garantie, daher zusätzlich explizit pausieren +
    /// fortsetzen.
    public func toggleCrossfade() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }
        let currentlyActive = try await loadCrossfadeEnabled()
        let newMode = currentlyActive ? Self.crossfadeOffValue : Self.crossfadeOnValue
        try await client.sendRaw(
            "config/players/save",
            args: PlayerConfigSaveArgs(playerId: playerId, values: [Self.crossfadeConfigKey: newMode])
        )

        if selectedPlayer?.playbackState == .playing {
            try await client.sendRaw("players/cmd/play_pause", args: PlayerIDArgs(playerId: playerId))
            try await Task.sleep(for: .milliseconds(300))
            try await client.sendRaw("players/cmd/play_pause", args: PlayerIDArgs(playerId: playerId))
        }
        return !currentlyActive
    }
}

public extension AppState {
    var uiLanguage: L10n.Language { settings.language.resolved() }

    /// Kurzform für `L10n.text(key, uiLanguage)` an den vielen Call-Sites in
    /// den Views (die dort ohnehin schon `@Environment(AppState.self)` haben).
    func t(_ key: L10n.Key) -> String { L10n.text(key, uiLanguage) }
}
