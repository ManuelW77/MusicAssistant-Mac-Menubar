import Foundation
import Observation

/// Nicht-geheime Einstellungen (Server-URL, Player-Whitelist, letzter gewählter
/// Player) in UserDefaults. Der Auth-Token liegt bewusst separat im Keychain
/// (siehe KeychainTokenStore).
@MainActor
@Observable
public final class AppSettingsStore {
    private let defaults: UserDefaults

    public var serverBaseURLString: String {
        didSet { defaults.set(serverBaseURLString, forKey: Keys.serverBaseURL) }
    }

    public var allowedPlayerIDs: Set<String> {
        didSet { defaults.set(Array(allowedPlayerIDs), forKey: Keys.allowedPlayerIDs) }
    }

    public var lastSelectedPlayerID: String? {
        didSet { defaults.set(lastSelectedPlayerID, forKey: Keys.lastSelectedPlayerID) }
    }

    public var serverBaseURL: URL? {
        guard !serverBaseURLString.isEmpty else { return nil }
        return URL(string: serverBaseURLString)
    }

    private enum Keys {
        static let serverBaseURL = "mass.serverBaseURL"
        static let allowedPlayerIDs = "mass.allowedPlayerIDs"
        static let lastSelectedPlayerID = "mass.lastSelectedPlayerID"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.serverBaseURLString = defaults.string(forKey: Keys.serverBaseURL) ?? ""
        self.allowedPlayerIDs = Set(defaults.stringArray(forKey: Keys.allowedPlayerIDs) ?? [])
        self.lastSelectedPlayerID = defaults.string(forKey: Keys.lastSelectedPlayerID)
    }
}
