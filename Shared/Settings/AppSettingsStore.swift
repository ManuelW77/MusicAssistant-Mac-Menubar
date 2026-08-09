import Foundation
import Observation

/// Alle App-Einstellungen (Server-URL, Access-Token, Player-Whitelist, letzter
/// gewählter Player) in UserDefaults.
///
/// Der Token liegt bewusst NICHT in der Keychain: jede App, die zum ersten Mal
/// ein Secret in der Keychain ablegt, löst einen vom System erzwungenen
/// "App möchte auf deinen Schlüsselbund zugreifen"-Dialog aus (nicht
/// unterdrückbar, harte macOS-Sicherheitsgrenze). Bewusste Nutzerentscheidung,
/// diesen einmaligen Dialog zugunsten einer reibungslosen Ersteinrichtung zu
/// vermeiden — der Token liegt dadurch unverschlüsselt in UserDefaults.
@MainActor
@Observable
public final class AppSettingsStore {
    private let defaults: UserDefaults

    public var serverBaseURLString: String {
        didSet { defaults.set(serverBaseURLString, forKey: Keys.serverBaseURL) }
    }

    public var accessToken: String? {
        didSet { defaults.set(accessToken, forKey: Keys.accessToken) }
    }

    public var allowedPlayerIDs: Set<String> {
        didSet { defaults.set(Array(allowedPlayerIDs), forKey: Keys.allowedPlayerIDs) }
    }

    public var lastSelectedPlayerID: String? {
        didSet { defaults.set(lastSelectedPlayerID, forKey: Keys.lastSelectedPlayerID) }
    }

    public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            L10n.currentLanguage = language.resolved()
        }
    }

    /// Version, für die zuletzt eine Update-Benachrichtigung gepostet wurde —
    /// verhindert, dass AppState.checkForUpdate() bei jedem 24h-Hintergrund-
    /// Check für dieselbe, weiterhin nicht installierte Version erneut
    /// benachrichtigt.
    public var lastNotifiedUpdateVersion: String? {
        didSet { defaults.set(lastNotifiedUpdateVersion, forKey: Keys.lastNotifiedUpdateVersion) }
    }

    public var serverBaseURL: URL? {
        guard !serverBaseURLString.isEmpty else { return nil }
        return URL(string: serverBaseURLString)
    }

    private enum Keys {
        static let serverBaseURL = "mass.serverBaseURL"
        static let accessToken = "mass.accessToken"
        static let allowedPlayerIDs = "mass.allowedPlayerIDs"
        static let lastSelectedPlayerID = "mass.lastSelectedPlayerID"
        static let language = "mass.language"
        static let lastNotifiedUpdateVersion = "mass.lastNotifiedUpdateVersion"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.serverBaseURLString = defaults.string(forKey: Keys.serverBaseURL) ?? ""
        self.accessToken = defaults.string(forKey: Keys.accessToken)
        self.allowedPlayerIDs = Set(defaults.stringArray(forKey: Keys.allowedPlayerIDs) ?? [])
        self.lastSelectedPlayerID = defaults.string(forKey: Keys.lastSelectedPlayerID)
        self.language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        self.lastNotifiedUpdateVersion = defaults.string(forKey: Keys.lastNotifiedUpdateVersion)
        // didSet feuert bei self.x = … innerhalb des eigenen init nicht —
        // L10n.currentLanguage muss hier explizit synchronisiert werden.
        L10n.currentLanguage = self.language.resolved()
    }
}
