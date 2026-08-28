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
        // Ohne .moveToActiveSpace ordnet macOS ein neu erschienenes Fenster
        // standardmäßig auf dem Space ein, auf dem die App zuletzt aktiv war
        // (i.d.R. der erste Desktop, wo die LSUIElement-App beim Login
        // startet) statt auf dem gerade aktiven Space des Nutzers. Das Flag
        // wirkt erst beim nächsten orderFront/makeKeyAndOrderFront, muss also
        // hier (vor jedem Erscheinen) statt einmalig bei Fenstererzeugung
        // gesetzt werden — SwiftUIs `Window`-Szene gibt keinen direkten
        // NSWindow-Zugriff zur Erzeugungszeit her.
        for window in NSApp.windows {
            // .canJoinAllSpaces und .moveToActiveSpace sind laut
            // NSWindowCollectionBehavior gegenseitig exklusive "primary
            // options" — beide gleichzeitig gesetzt lässt
            // -[NSWindow _validateCollectionBehavior:] eine Exception werfen.
            // NSApp.windows enthält u.a. das interne NSStatusBarWindow des
            // Menüleisten-Icons, das bereits .canJoinAllSpaces trägt (damit
            // es auf jedem Space sichtbar bleibt) — das hat genau diesen
            // Crash beim Öffnen der Einstellungen über das Kontextmenü
            // ausgelöst.
            guard !window.collectionBehavior.contains(.canJoinAllSpaces) else { continue }
            window.collectionBehavior.insert(.moveToActiveSpace)
        }
    }

    static func windowDidDisappear() {
        openCount = max(0, openCount - 1)
        if openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
