import AppKit

/// Referenzgezählter Helper für die LSUIElement-Aktivierungs-Policy-Dance, die
/// mehrere unabhängig öffenbare Fenster (Einstellungen, Suche) teilen müssen:
/// als Accessory-App wird ein Fenster ohne kurzzeitiges Umschalten auf
/// `.regular` + `NSApp.activate` nicht zuverlässig key/fokussiert. Ohne
/// Referenzzählung würde das Schließen eines Fensters die Aktivierung des
/// anderen kaputt machen, solange dieses noch offen ist.
@MainActor
enum WindowActivation {
    private static var openCount = 0

    static func windowDidAppear() {
        openCount += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func windowDidDisappear() {
        openCount = max(0, openCount - 1)
        if openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
