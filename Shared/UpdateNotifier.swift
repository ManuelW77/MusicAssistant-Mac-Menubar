import Foundation
import UserNotifications

/// Postet eine lokale macOS-Benachrichtigung, wenn eine neue Version
/// gefunden wurde. Getrennt von `UpdateChecker` (das bleibt eine reine,
/// zustandslose HTTP-Abfrage) — dieser Typ übernimmt den Seiteneffekt
/// "Nutzer aktiv informieren", da `AppState.updateInfo` bislang nur passiv
/// im Settings-Fenster sichtbar war (kein Popup/Badge, siehe README).
public enum UpdateNotifier {
    /// Einmalig (pro Prozessstart reicht) aufrufen, bevor `notify` genutzt
    /// wird — ohne erteilte Berechtigung verwirft macOS die Anfrage
    /// stillschweigend. Fragt beim Nutzer nur einmalig nach; wiederholte
    /// Aufrufe nach einer bereits getroffenen Entscheidung zeigen keinen
    /// erneuten Prompt.
    public static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Notification-Identifier sind bewusst versionsspezifisch
    /// ("update-1.2.0"), damit AppState.checkForUpdate() anhand von
    /// `AppSettingsStore.lastNotifiedUpdateVersion` für dieselbe Version nicht
    /// bei jedem 24h-Hintergrund-Check erneut benachrichtigt.
    public static func notify(version: String, language: L10n.Language) {
        let content = UNMutableNotificationContent()
        content.title = L10n.text(.updateAvailableTitle, language)
        content.body = L10n.updateAvailableBody(version, language)
        content.sound = .default

        let request = UNNotificationRequest(identifier: "update-\(version)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
