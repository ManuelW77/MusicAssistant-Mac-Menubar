import Foundation

/// Übersetzungen leben als reiner Swift-Code (kein .lproj/.xcstrings/
/// Bundle.module): dieses Projekt hat bewusst keine SPM-`resources:` für das
/// MAMenubar-Target (siehe Kommentar in App/AppDelegate.swift zu
/// MenubarIcon.png — Bundle.module wurde wegen eines Codesign-Fehlers
/// "unsealed contents present in the bundle root" bewusst verworfen). Ein
/// reines Swift-Dictionary umgeht das komplett und funktioniert identisch im
/// nackten Executable (Xcode/`swift run`) wie im `make app`-Bundle.
public enum L10n {
    public enum Language: Sendable {
        case de, en
    }

    public enum Key: String, CaseIterable, Sendable {
        // Fehler (Shared/AppState.swift Error-Enums)
        case errorNoClient
        case errorNoCurrentTrack
        case errorNoPlayer

        // ConnectionStatus
        case statusDisconnected
        case statusConnecting
        case statusConnected

        // Row-Kontextmenüs (Album/Artist/Playlist/Track)
        case play
        case addToQueue

        // CrossfadeButtonView
        case smartCrossfadeEnable
        case smartCrossfadeDisable

        // ShuffleButtonView
        case shuffleEnable
        case shuffleDisable

        // FavoriteButtonView
        case favorite
        case addToFavorites
        case removeFromFavorites

        // RadioButtonView
        case startRadio

        // MenuBarContentView
        case noPlayback
        case addToPlaylist
        case search
        case back

        // PlayerPickerView
        case noPlayersAllowed

        // AddToPlaylistView
        case noTrack
        case retry
        case noPlaylistsFound
        case createPlaylistHint
        case newPlaylistPlaceholder
        case create

        // Playlist-Sections (AddToPlaylistView / SearchView)
        case favoritePlaylists
        case allPlaylists

        // MediaDetailView
        case tracksLoadFailed

        // SearchView
        case mediaTypeTrack
        case mediaTypeAlbum
        case mediaTypeArtist

        // ArtistDetailView
        case topTracks
        case noCategorySelected
        case selectAtLeastOneCategory
        case searchFailed
        case searchPrompt
        case source
        case allSources

        // SettingsView
        case generalTabLabel
        case startAtLogin
        case about
        case developer
        case githubRepo
        case checkForUpdates
        case upToDate
        case serverURL
        case tokenFooter
        case testConnection
        case save
        case selectPlayersHint
        case noPlayersLoaded
        case connectFirstHint
        case reloadPlayers
        case invalidURL
        case languageLabel
        case systemLanguageOption

        // AppDelegate Kontextmenü
        case settingsEllipsis
        case quit

        // UpdateNotifier (lokale Benachrichtigung)
        case updateAvailableTitle
    }

    public static func text(_ key: Key, _ language: Language) -> String {
        guard let entry = table[key] else {
            assertionFailure("L10n: fehlender Eintrag für \(key)")
            return key.rawValue
        }
        return language == .de ? entry.de : entry.en
    }

    /// Ausschließlich für Stellen ohne AppState-Zugriff: die
    /// `description`-Requirement von `CustomStringConvertible` ist
    /// `nonisolated` und kann daher keinen `@MainActor`-Wert lesen.
    /// `nonisolated(unsafe)` ist hier bewusst vertretbar — worst case bei
    /// einer theoretischen Race ist eine kurzzeitig falschsprachige
    /// Fehlermeldung, kein Crash/keine Datenkorruption. Wird von
    /// `AppSettingsStore` bei jeder Sprachänderung (init + didSet) aktuell
    /// gehalten.
    public nonisolated(unsafe) static var currentLanguage: Language = AppLanguage.system.resolved()
}
