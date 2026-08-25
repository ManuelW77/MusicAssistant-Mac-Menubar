import Foundation

// Feldnamen sind aus der Music-Assistant-Recherche abgeleitet, aber noch nicht
// gegen den echten Server verifiziert (siehe Tools/VerifyConnection). Falls das
// Decoding in Schritt 0 fehlschlägt, hier zuerst nachjustieren.

public struct MAPlayer: Codable, Identifiable, Equatable, Sendable {
    public let playerId: String
    public var name: String
    public var available: Bool?
    public var playbackState: PlaybackState?
    public var currentMedia: PlayerMedia?
    public var volumeLevel: Int?
    /// Bei Sync-Gruppen-Playern (type == "group") liefert der Server für
    /// volumeLevel null; der aggregierte Wert steckt stattdessen hier.
    public var groupVolume: Int?
    /// Mitglieder-IDs einer Sync-/Gruppen-Player-Queue, primäre Quelle für
    /// AppState.groupMembers(for:) (siehe dort — analog zu resolveGroupMembers()
    /// im HTML-Player unter ../ma-html-player/ma-dashboard.html: manche
    /// MA-Player melden das über group_members, andere über group_childs).
    public var groupMembers: [String]?
    public var groupChilds: [String]?
    /// Fallback, falls die Mitgliedschaft nur auf dem Mitglied selbst steht
    /// statt beim Gruppenleiter (group_members/group_childs).
    public var syncedTo: String?
    public var activeGroup: String?
    public var supportedFeatures: [String]?
    /// "none" bedeutet: dieser Player hat keinen eigenen Lautstärkeregler
    /// (z.B. ein reiner Gruppenleiter-Eintrag ohne echtes Ausgabegerät).
    public var volumeControl: String?

    public var id: String { playerId }

    /// Anzuzeigende Lautstärke unabhängig davon, ob es sich um einen
    /// einzelnen Player oder eine Sync-Gruppe handelt.
    public var effectiveVolume: Int? { volumeLevel ?? groupVolume }

    /// Ob dieser Player einen eigenen Lautstärkeregler hat — Filter für
    /// AppState.groupMembers(for:), analog zum filterVolume-Parameter von
    /// resolveGroupMembers() im HTML-Player.
    public var supportsVolumeControl: Bool {
        if volumeControl == "none" { return false }
        if let supportedFeatures, !supportedFeatures.contains("volume_set") { return false }
        return true
    }

    public init(
        playerId: String,
        name: String,
        available: Bool? = nil,
        playbackState: PlaybackState? = nil,
        currentMedia: PlayerMedia? = nil,
        volumeLevel: Int? = nil,
        groupVolume: Int? = nil,
        groupMembers: [String]? = nil,
        groupChilds: [String]? = nil,
        syncedTo: String? = nil,
        activeGroup: String? = nil,
        supportedFeatures: [String]? = nil,
        volumeControl: String? = nil
    ) {
        self.playerId = playerId
        self.name = name
        self.available = available
        self.playbackState = playbackState
        self.currentMedia = currentMedia
        self.volumeLevel = volumeLevel
        self.groupVolume = groupVolume
        self.groupMembers = groupMembers
        self.groupChilds = groupChilds
        self.syncedTo = syncedTo
        self.activeGroup = activeGroup
        self.supportedFeatures = supportedFeatures
        self.volumeControl = volumeControl
    }
}

public enum PlaybackState: String, Codable, Equatable, Sendable {
    case idle
    case paused
    case playing
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlaybackState(rawValue: raw) ?? .unknown
    }
}

public struct PlayerMedia: Codable, Equatable, Sendable {
    public let uri: String?
    public let title: String?
    public let artist: String?
    public let album: String?
    public let imageUrl: String?
    public let duration: Double?
    public let elapsedTime: Double?
    /// Server-Zeitstempel (Unix-Sekunden) des letzten `elapsedTime`-Updates.
    /// In MA ≥ 2.10.0 ändert sich `elapsedTime` nur noch bei Zustandsänderungen;
    /// für einen live laufenden Balken muss der Client selbst zwischen den
    /// Ankern interpolieren.
    public let elapsedTimeLastUpdated: Double?

    public init(
        uri: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        imageUrl: String? = nil,
        duration: Double? = nil,
        elapsedTime: Double? = nil,
        elapsedTimeLastUpdated: Double? = nil
    ) {
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.imageUrl = imageUrl
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.elapsedTimeLastUpdated = elapsedTimeLastUpdated
    }
}
