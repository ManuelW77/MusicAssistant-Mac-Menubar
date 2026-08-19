import Foundation

extension L10n {
    /// `internal` (kein `private`) — `@testable import MAMenubarLib` braucht
    /// Zugriff, um die Vollständigkeit der Tabelle gegen `Key.allCases` zu
    /// testen.
    static let table: [Key: (de: String, en: String)] = [
        .errorNoClient: (de: "Nicht mit Music Assistant verbunden", en: "Not connected to Music Assistant"),
        .errorNoCurrentTrack: (de: "Kein Titel wird aktuell abgespielt", en: "No track is currently playing"),
        .errorNoPlayer: (de: "Kein Player ausgewählt", en: "No player selected"),

        .statusDisconnected: (de: "Nicht konfiguriert", en: "Not configured"),
        .statusConnecting: (de: "Verbinde…", en: "Connecting…"),
        .statusConnected: (de: "Verbunden", en: "Connected"),

        .play: (de: "Abspielen", en: "Play"),
        .addToQueue: (de: "Zur Warteschlange hinzufügen", en: "Add to Queue"),

        .smartCrossfadeEnable: (de: "Smart Crossfade einschalten", en: "Turn on Smart Crossfade"),
        .smartCrossfadeDisable: (de: "Smart Crossfade ausschalten", en: "Turn off Smart Crossfade"),

        .favorite: (de: "Favorit", en: "Favorite"),
        .addToFavorites: (de: "Zu Favoriten hinzufügen", en: "Add to Favorites"),
        .removeFromFavorites: (de: "Aus Favoriten entfernen", en: "Remove from Favorites"),

        .startRadio: (de: "Radio starten", en: "Start Radio"),

        .noPlayback: (de: "Keine Wiedergabe", en: "No playback"),
        .addToPlaylist: (de: "Zu Playlist hinzufügen", en: "Add to Playlist"),
        .search: (de: "Suche", en: "Search"),
        .back: (de: "Zurück", en: "Back"),

        .noPlayersAllowed: (de: "Keine Player freigegeben – siehe Einstellungen", en: "No players allowed – see Settings"),

        .noTrack: (de: "Kein Titel", en: "No track"),
        .retry: (de: "Erneut versuchen", en: "Try Again"),
        .noPlaylistsFound: (de: "Keine Playlists gefunden", en: "No playlists found"),
        .createPlaylistHint: (de: "Leg unten eine neue Playlist an.", en: "Create a new playlist below."),
        .newPlaylistPlaceholder: (de: "Neue Playlist…", en: "New Playlist…"),
        .create: (de: "Erstellen", en: "Create"),

        .favoritePlaylists: (de: "Favoriten", en: "Favorites"),
        .allPlaylists: (de: "Alle Playlisten", en: "All Playlists"),

        .tracksLoadFailed: (de: "Titel konnten nicht geladen werden", en: "Failed to load tracks"),

        .mediaTypeTrack: (de: "Titel", en: "Tracks"),
        .mediaTypeAlbum: (de: "Alben", en: "Albums"),
        .mediaTypeArtist: (de: "Interpreten", en: "Artists"),
        .noCategorySelected: (de: "Keine Kategorie ausgewählt", en: "No category selected"),
        .selectAtLeastOneCategory: (de: "Wähle mindestens eine Kategorie oben aus.", en: "Select at least one category above."),
        .searchFailed: (de: "Suche fehlgeschlagen", en: "Search failed"),
        .searchPrompt: (de: "Titel, Alben, Playlists, Interpreten…", en: "Tracks, albums, playlists, artists…"),
        .source: (de: "Quelle", en: "Source"),
        .allSources: (de: "Alle Quellen", en: "All Sources"),

        .generalTabLabel: (de: "Allgemein", en: "General"),
        .startAtLogin: (de: "Bei Anmeldung starten", en: "Start at Login"),
        .about: (de: "Über", en: "About"),
        .developer: (de: "Entwickler", en: "Developer"),
        .githubRepo: (de: "GitHub-Repository", en: "GitHub Repository"),
        .checkForUpdates: (de: "Nach Updates suchen", en: "Check for Updates"),
        .upToDate: (de: "Aktuell", en: "Up to Date"),
        .serverURL: (de: "Server-URL", en: "Server URL"),
        .tokenFooter: (
            de: "Der Token wird in der Music-Assistant-Web-UI unter Profil → Access Tokens erzeugt und lokal in den App-Einstellungen gespeichert.",
            en: "The token is generated in the Music Assistant web UI under Profile → Access Tokens and stored locally in the app settings."
        ),
        .testConnection: (de: "Verbindung testen", en: "Test Connection"),
        .save: (de: "Speichern", en: "Save"),
        .selectPlayersHint: (
            de: "Wähle aus, welche Player im Menüleisten-Popover zur Auswahl stehen sollen.",
            en: "Choose which players are available in the menu bar popover."
        ),
        .noPlayersLoaded: (de: "Keine Player geladen", en: "No players loaded"),
        .connectFirstHint: (
            de: "Verbinde dich zuerst über den Server-Tab oder lade die Liste neu.",
            en: "Connect first via the Server tab or reload the list."
        ),
        .reloadPlayers: (de: "Player neu laden", en: "Reload Players"),
        .invalidURL: (de: "Ungültige URL", en: "Invalid URL"),
        .languageLabel: (de: "Sprache", en: "Language"),
        .systemLanguageOption: (de: "Systemsprache", en: "System Language"),

        .settingsEllipsis: (de: "Einstellungen…", en: "Settings…"),
        .quit: (de: "Beenden", en: "Quit"),

        .updateAvailableTitle: (de: "Update verfügbar", en: "Update Available"),
    ]
}
