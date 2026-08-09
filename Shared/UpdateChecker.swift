import Foundation

/// Prüft über die GitHub-Releases-API, ob eine neuere Version als die
/// aktuell laufende veröffentlicht ist. Reine, zustandslose Abfragefunktion —
/// den Hintergrund-Rhythmus (alle 24h) und den geteilten Ergebnis-State
/// verwaltet AppState.startUpdateChecks(), nicht diese Datei.
public enum UpdateChecker {
    public static let repository = "ManuelW77/MusicAssistant-Mac-Menubar"

    public struct UpdateInfo: Sendable, Equatable {
        public let latestVersion: String
        public let url: URL
        public let releaseNotes: String?
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: String
        let body: String?
    }

    /// Liefert Infos zur neuesten Release, falls sie neuer als `currentVersion`
    /// ist. `nil` bei bereits aktueller Version oder wenn die Anfrage fehlschlägt
    /// (kein Internet, Rate-Limit, o.ä. — bewusst kein Fehler-Signal, damit ein
    /// gescheiterter Update-Check die App nicht stört).
    public static func checkForUpdate(currentVersion: String) async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(GitHubRelease.self, from: data),
              let releaseURL = URL(string: release.htmlUrl) else {
            return nil
        }

        let latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        guard isNewer(latestVersion, than: currentVersion) else { return nil }
        return UpdateInfo(latestVersion: latestVersion, url: releaseURL, releaseNotes: release.body)
    }

    /// Rein numerischer SemVer-Vergleich (X.Y.Z, fehlende Teile zählen als 0).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let c = index < candidateParts.count ? candidateParts[index] : 0
            let cur = index < currentParts.count ? currentParts[index] : 0
            if c != cur { return c > cur }
        }
        return false
    }
}
