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
            // Ein Pending-Zustand gehört zur vorherigen Auswahl — soll nicht
            // optisch am neu gewählten Player weiterlaufen.
            clearPlayPausePending()
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

    /// Rein lokaler Pending-Zustand für den Play/Pause-Button: der Server
    /// meldet keinen "buffering"-Zwischenstatus (PlaybackState kennt nur
    /// idle/paused/playing/unknown), daher wird hier optimistisch beim
    /// Klick gesetzt und zurückgesetzt, sobald das nächste playerUpdated-
    /// Event für den gewählten Player ankommt (oder spätestens nach
    /// playPauseTimeout als Absicherung gegen ein ausbleibendes Event).
    public private(set) var isPlayPauseCommandPending = false
    private var playPauseTimeoutTask: Task<Void, Never>?
    private static let playPauseTimeout: Double = 4

    /// Server-Info von `GET /info`, für `usesQueueCrossfadeAPI` unten.
    public private(set) var serverInfo: ServerInfo?
    /// Aktuell angezeigter Fortschritt (0…1), lokal aus dem letzten
    /// Server-Anker hochgezählt, oder `nil`, wenn `currentMedia` (noch) kein
    /// `elapsedTimeLastUpdated` liefert — die UI fällt dann automatisch auf
    /// die statische Berechnung zurück (siehe MenuBarContentView.playbackProgress).
    /// Der Tick lief früher nur ab gemeldeter Serverversion ≥2.10.0, aber
    /// Dev-/Nightly-Server melden `server_version: "0.0.0"` (die echte Version
    /// wird bei music-assistant/server erst im Release-Build gesetzt), wodurch
    /// der Check dort fälschlich "zu alt" ergab und die Anzeige einfror. Der
    /// Tick läuft daher jetzt immer; ob interpoliert wird, entscheidet sich
    /// rein an den Daten.
    public private(set) var displayedPlaybackProgress: Double?

    public let settings: AppSettingsStore
    private var client: MassWebSocketClient?
    private var supervisorTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var providerIconCache: [String: String] = [:]
    private var updateCheckTask: Task<Void, Never>?
    private var progressTickTask: Task<Void, Never>?
    private static let updateCheckInterval: Double = 24 * 60 * 60

    private static let backoffSchedule: [Double] = [1, 2, 4, 8, 16, 30]
    private static let progressTickInterval: Double = 0.5

    public init(settings: AppSettingsStore) {
        self.settings = settings
        self.selectedPlayerID = settings.lastSelectedPlayerID
    }

    public convenience init() {
        self.init(settings: AppSettingsStore())
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
        stopProgressTick()
        displayedPlaybackProgress = nil
        serverInfo = nil
        connectionStatus = .disconnected
        clearPlayPausePending()
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
    ///
    /// No-op im Mac-App-Store-Build (`MAS_BUILD`, gesetzt via
    /// `make appstore`/`-Xswiftc -DMAS_BUILD`): ein eigener Update-Mechanismus
    /// außerhalb des Stores verstößt gegen Apples Review-Richtlinien, dort
    /// übernimmt der Store selbst die Update-Benachrichtigung.
    public func startUpdateChecks() {
        #if MAS_BUILD
        return
        #else
        guard updateCheckTask == nil else { return }
        UpdateNotifier.requestAuthorizationIfNeeded()
        updateCheckTask = Task { await runUpdateCheckLoop() }
        #endif
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

        // Nur einmal pro entdeckter Version benachrichtigen, nicht bei jedem
        // 24h-Hintergrund-Check erneut, solange die Version nicht installiert
        // wurde (siehe lastNotifiedUpdateVersion).
        if let updateInfo, settings.lastNotifiedUpdateVersion != updateInfo.latestVersion {
            UpdateNotifier.notify(version: updateInfo.latestVersion, language: uiLanguage)
            settings.lastNotifiedUpdateVersion = updateInfo.latestVersion
        }
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
                serverInfo = await fetchServerInfo(baseURL: baseURL)
                startProgressTick()

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
            stopProgressTick()
            displayedPlaybackProgress = nil
            serverInfo = nil
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
            if player.playerId == selectedPlayerID {
                clearPlayPausePending()
            }
            updateDisplayedPlaybackProgress()
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
            selectedPlayerID = Self.resolvedSelection(candidates: availablePlayers, currentSelection: selectedPlayerID)
        } catch {
            connectionStatus = .error(L10n.playerListLoadFailed("\(error)", uiLanguage))
        }
    }

    /// Bestimmt die zu wählende Player-ID beim Neuladen der Player-Liste:
    /// bevorzugt den ersten aktuell spielenden Player aus `candidates` (in
    /// deterministischer Listenreihenfolge, nicht Set-Reihenfolge). Spielt
    /// keiner, bleibt eine bestehende Auswahl unangetastet, solange sie noch
    /// unter den Kandidaten ist — ein Refresh soll keine manuelle Auswahl
    /// überschreiben, nur weil gerade nirgends etwas läuft. Ist die Auswahl
    /// ungültig (z. B. Whitelist geändert) oder noch keine getroffen, fällt
    /// sie auf den ersten Kandidaten zurück.
    nonisolated static func resolvedSelection(
        candidates: [MAPlayer],
        currentSelection: String?
    ) -> String? {
        if let playing = candidates.first(where: { $0.playbackState == .playing }) {
            return playing.playerId
        }
        if let currentSelection, candidates.contains(where: { $0.playerId == currentSelection }) {
            return currentSelection
        }
        return candidates.first?.playerId
    }

    // Temporäre Diagnose, um zu klären, ob der Server duration/elapsedTime für
    // currentMedia überhaupt befüllt (Grundlage für die Fortschrittsanzeige im
    // Cover) — läuft direkt beim normalen Xcode-Run mit, kein separates CLI-Tool
    // mit eigenem (langsamem) Build nötig.
    private func logCurrentMediaDebugInfo(for player: MAPlayer) {
        guard let media = player.currentMedia else { return }
        let durationText = media.duration.map { "\($0)" } ?? "nil"
        let elapsedText = media.elapsedTime.map { "\($0)" } ?? "nil"
        let updatedText = media.elapsedTimeLastUpdated.map { "\($0)" } ?? "nil"
        print("AppState: \(player.name) — duration=\(durationText) elapsed=\(elapsedText) updated=\(updatedText)")
    }

    // MARK: - Server-Version & Fortschritts-Interpolation

    /// Ruft die unauthentifizierte Server-Info ab. Fehler werden still
    /// ignoriert, damit auch ältere Server ohne `/info`-Endpoint weiterlaufen.
    private func fetchServerInfo(baseURL: URL) async -> ServerInfo? {
        do {
            let url = try MassEndpoint.infoURL(baseURL: baseURL)
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ServerInfo.self, from: data)
        } catch {
            return nil
        }
    }

    /// Vergleicht eine MA-Versionsnummer mit der 2.10.0-Grenze.
    /// Suffixe wie `b3`, `rc1` etc. werden ignoriert, damit auch Beta-Builds
    /// der 2.10.x-Reihe als „neu“ gelten.
    nonisolated static func isVersionAtLeast2_10_0(_ version: String) -> Bool {
        guard let parsed = parseVersion(version) else { return false }
        return parsed >= (2, 10, 0)
    }

    nonisolated private static func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let prefix = version.prefix { $0.isNumber || $0 == "." }
        var parts = prefix.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        while parts.count < 3 { parts.append(0) }
        guard parts.count >= 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    private func startProgressTick() {
        guard progressTickTask == nil else { return }
        progressTickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.updateDisplayedPlaybackProgress()
                try? await Task.sleep(for: .seconds(Self.progressTickInterval))
            }
        }
    }

    private func stopProgressTick() {
        progressTickTask?.cancel()
        progressTickTask = nil
    }

    private func updateDisplayedPlaybackProgress() {
        guard let media = selectedPlayer?.currentMedia,
              let duration = media.duration, duration > 0,
              let elapsed = media.elapsedTime,
              let lastUpdated = media.elapsedTimeLastUpdated else {
            displayedPlaybackProgress = nil
            return
        }
        let isPlaying = selectedPlayer?.playbackState == .playing
        displayedPlaybackProgress = Self.interpolatedProgress(
            elapsedTime: elapsed,
            elapsedTimeLastUpdated: lastUpdated,
            duration: duration,
            isPlaying: isPlaying,
            now: Date().timeIntervalSince1970
        )
    }

    /// Reine Berechnung des interpolierten Fortschritts (0…1), damit sie
    /// unit-getestet werden kann, ohne `@MainActor`/`@Observable` aufzubauen.
    nonisolated static func interpolatedProgress(
        elapsedTime: Double,
        elapsedTimeLastUpdated: Double,
        duration: Double,
        isPlaying: Bool,
        now: Double
    ) -> Double {
        let position = elapsedTime + (isPlaying ? (now - elapsedTimeLastUpdated) : 0)
        return min(max(position / duration, 0), 1)
    }

    public func playPause() {
        // Guard hier statt nur in sendPlayerCommand: sonst würde der Pending-
        // Flag auch ohne Verbindung/Auswahl gesetzt und bliebe bis zum
        // Timeout fälschlich sichtbar, obwohl gar kein Befehl gesendet wird.
        guard client != nil, selectedPlayerID != nil else { return }
        isPlayPauseCommandPending = true
        armPlayPauseTimeout()
        sendPlayerCommand("players/cmd/play_pause")
    }

    public func next() { sendPlayerCommand("players/cmd/next") }
    public func previous() { sendPlayerCommand("players/cmd/previous") }

    private func sendPlayerCommand(_ command: String) {
        guard let client, let playerId = selectedPlayerID else { return }
        Task {
            try? await client.sendRaw(command, args: PlayerIDArgs(playerId: playerId))
        }
    }

    private func armPlayPauseTimeout() {
        playPauseTimeoutTask?.cancel()
        playPauseTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.playPauseTimeout))
            guard !Task.isCancelled else { return }
            self?.isPlayPauseCommandPending = false
        }
    }

    private func clearPlayPausePending() {
        isPlayPauseCommandPending = false
        playPauseTimeoutTask?.cancel()
        playPauseTimeoutTask = nil
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
        playlists = list.sorted { $0.favorite && !$1.favorite }
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

    // Ab Serverversion 2.10.0 (music-assistant/server#4373, 21.06.2026 —
    // bereits im frühesten 2.10.0-Dev-Build enthalten, siehe
    // usesQueueCrossfadeAPI) verschiebt der Server Crossfade von der
    // Pro-Player- auf eine Pro-Queue-Einstellung: der alte Config-Weg
    // ("smart_fades_mode" via config/players/*) ist dort nur noch eine
    // einmalige Migrationsquelle, das eigentliche Setzen läuft über den
    // dedizierten Bool-Befehl "player_queues/crossfade". Auf älteren Servern
    // bleibt "smart_fades_mode" (Config-Entry auf der PLAYER-Konfiguration)
    // die einzige Quelle. Der Button heißt bewusst "Smart Crossfade", daher
    // togglet der alte Pfad zwischen "smart_crossfade" und "disabled".
    private static let crossfadeConfigKey = "smart_fades_mode"
    private static let crossfadeOnValue = "smart_crossfade"
    private static let crossfadeOffValue = "disabled"

    /// Ob der Server bereits die Queue-scoped Crossfade-API
    /// (music-assistant/server#4373) statt der alten Player-Config nutzt.
    private var usesQueueCrossfadeAPI: Bool {
        serverInfo.map { Self.isVersionAtLeast2_10_0($0.serverVersion) } ?? false
    }

    /// Lädt den aktuellen Smart-Crossfade-Status des gewählten Players.
    ///
    /// Auf Servern ab 2.10.0 liegt der Status auf der Queue selbst
    /// (`player_queues/get` → `crossfade_enabled`). Auf älteren Servern liegt
    /// er auf der Player-Config: `player_queues/get` liefert dort kein
    /// `smart_fades_active` — das Feld fehlt im JSON komplett (nicht nur
    /// `false`), das tolerante Decoding las das bislang immer stillschweigend
    /// als "aus", wodurch Ausschalten es tatsächlich immer wieder einschaltete.
    public func loadCrossfadeEnabled() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }

        if usesQueueCrossfadeAPI {
            let queue: PlayerQueueInfo = try await client.send(
                "player_queues/get",
                args: QueueIDArgs(queueId: playerId)
            )
            return queue.crossfadeEnabled ?? false
        }

        let raw = try await client.sendRaw(
            "config/players/get_value",
            args: PlayerConfigGetValueArgs(playerId: playerId, key: Self.crossfadeConfigKey)
        )
        let mode = (try? raw.decode(String.self)) ?? Self.crossfadeOffValue
        return mode == Self.crossfadeOnValue
    }

    /// Togglet Smart Crossfade für die Queue des gewählten Players und gibt
    /// den neuen Status zurück. Ein Konfigurationswechsel löst serverseitig
    /// zwar bei laufender Wiedergabe automatisch einen Stop+Resume aus
    /// (requires_reload), das reicht aber laut Nutzeranforderung nicht als
    /// alleinige Garantie — für beide API-Pfade daher zusätzlich explizit
    /// pausieren + fortsetzen.
    public func toggleCrossfade() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }
        let currentlyActive = try await loadCrossfadeEnabled()
        let newState = !currentlyActive

        if usesQueueCrossfadeAPI {
            try await client.sendRaw(
                "player_queues/crossfade",
                args: QueueCrossfadeArgs(queueId: playerId, crossfadeEnabled: newState)
            )
        } else {
            let newMode = newState ? Self.crossfadeOnValue : Self.crossfadeOffValue
            try await client.sendRaw(
                "config/players/save",
                args: PlayerConfigSaveArgs(playerId: playerId, values: [Self.crossfadeConfigKey: newMode])
            )
        }

        if selectedPlayer?.playbackState == .playing {
            try await client.sendRaw("players/cmd/play_pause", args: PlayerIDArgs(playerId: playerId))
            try await Task.sleep(for: .milliseconds(300))
            try await client.sendRaw("players/cmd/play_pause", args: PlayerIDArgs(playerId: playerId))
        }
        return newState
    }

    /// Lädt den aktuellen Zufallswiedergabe-Status der Queue des gewählten
    /// Players. Anders als Crossfade gibt es hier keine Server-Versions-
    /// abhängige Legacy-Config, `shuffle_enabled` liegt schon immer direkt auf
    /// der Queue.
    public func loadShuffleEnabled() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }
        let queue: PlayerQueueInfo = try await client.send(
            "player_queues/get",
            args: QueueIDArgs(queueId: playerId)
        )
        return queue.shuffleEnabled ?? false
    }

    /// Togglet die Zufallswiedergabe für die Queue des gewählten Players und
    /// gibt den neuen Status zurück.
    public func toggleShuffle() async throws -> Bool {
        guard let client else { throw QueueError.noClient }
        guard let playerId = selectedPlayerID else { throw QueueError.noPlayer }
        let currentlyEnabled = try await loadShuffleEnabled()
        let newState = !currentlyEnabled
        try await client.sendRaw(
            "player_queues/shuffle",
            args: QueueShuffleArgs(queueId: playerId, shuffleEnabled: newState)
        )
        return newState
    }
}

public extension AppState {
    var uiLanguage: L10n.Language { settings.language.resolved() }

    /// Kurzform für `L10n.text(key, uiLanguage)` an den vielen Call-Sites in
    /// den Views (die dort ohnehin schon `@Environment(AppState.self)` haben).
    func t(_ key: L10n.Key) -> String { L10n.text(key, uiLanguage) }
}
