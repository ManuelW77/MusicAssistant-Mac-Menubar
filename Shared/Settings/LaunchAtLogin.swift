import Foundation
import ServiceManagement

/// Dünner Wrapper um SMAppService für den "Bei Anmeldung starten"-Schalter
/// in den Settings. Funktioniert nur, wenn die App als richtiges .app-Bundle
/// läuft (z.B. via `make app`) — als roher Executable aus `.build/debug`
/// heraus (Xcode-Run/`make run`) meldet SMAppService i.d.R. einen Fehler,
/// da es kein registrierbares LaunchServices-Bundle gibt.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
