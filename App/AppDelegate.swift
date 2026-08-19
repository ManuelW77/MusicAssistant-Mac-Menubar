import AppKit
import SwiftUI
import UserNotifications
import MAMenubarLib

/// Verwaltet das Menüleisten-Icon manuell über NSStatusItem statt über
/// SwiftUIs MenuBarExtra: Linksklick öffnet ein Popover mit Cover/Controls,
/// Rechtsklick zeigt ein Menü mit Einstellungen/Beenden. MenuBarExtra
/// unterscheidet Klick-Buttons nicht, daher der AppKit-Weg.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private let popoverNavigationState = PopoverNavigationState()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    // Zwei Monitore statt einem: der globale sieht nur Klicks in fremden
    // Apps/Fenstern, der lokale nur Klicks innerhalb der eigenen App (z.B.
    // auf das gleichzeitig offene Settings-Fenster) — zusammen decken sie
    // jeden Außenklick ab, egal wo.
    private var localOutsideClickMonitor: Any?
    private var globalOutsideClickMonitor: Any?

    // Bewusst kein SPM-Resource/Bundle.module: dessen generierter Accessor
    // sucht das Resource-Bundle auf der Bundle-Wurzel (neben Contents/),
    // aber codesign verweigert lose Inhalte genau dort ("unsealed contents
    // present in the bundle root"). Stattdessen wie AppIcon.icns behandelt:
    // App/MenubarIcon.png ist von der SPM-Quellerkennung ausgeschlossen
    // (Package.swift `exclude:`), `make app` kopiert es nach
    // Contents/Resources/ — dort findet Bundle.main es ganz normal. Für
    // lokale Debug-Runs ohne echtes .app-Bundle (Xcode-Run/`make run`) gibt
    // es einen Fallback direkt aus dem Source-Tree.
    private static let menuBarIcon: NSImage? = {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            let sourceDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            image = NSImage(contentsOf: sourceDir.appendingPathComponent("MenubarIcon.png"))
        }
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Muss vor dem ersten Update-Check gesetzt sein, sonst laufen
        // willPresent/didReceive für eine bereits gepostete Benachrichtigung
        // ins Leere.
        UNUserNotificationCenter.current().delegate = self

        appState.start()
        appState.startUpdateChecks()
        setupStatusItem()
        openSettingsWindowIfNeeded()

        // Nach Mac-Schlaf ist die TCP-Verbindung oft lautlos tot (kein Close-
        // Frame), ohne aktiven Traffic bemerkt receive() das ggf. sehr lange
        // nicht — daher hier proaktiv beim Aufwachen neu verbinden, statt
        // darauf zu warten, dass ein Button-Klick den toten Socket aufdeckt.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main garantiert nur die Ausführung auf dem Main-Thread,
            // isoliert den Closure-Typ selbst aber nicht auf MainActor —
            // daher der explizite Hop für den Zugriff auf appState.restart().
            guard let self else { return }
            Task { @MainActor in
                self.appState.restart()
            }
        }
    }

    // Reine Menüleisten-App: Schließen des Suche- oder Einstellungen-Fensters
    // darf die App nicht beenden, sie soll im Hintergrund weiterlaufen (das
    // Standardverhalten ohne diese Methode ist "letztes Fenster zu = App zu").
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Öffnet das Settings-Fenster gezielt beim Start, aber nur ohne gültige
    /// Zugangsdaten (Ersteinrichtung) — openSettings/SettingsLink sind nur
    /// aus echtem SwiftUI-Kontext aufrufbar, nicht aus AppDelegate, und der
    /// klassische showSettingsWindow:-Selector-Trick funktioniert auf dieser
    /// macOS-Version nicht mehr zuverlässig. Wiederverwendet stattdessen
    /// denselben SettingsLink-Mechanismus wie das Rechtsklick-Kontextmenü,
    /// nur ohne sichtbaren Klick über die dokumentierte AppKit-API
    /// NSMenu.performActionForItem(at:) ("simulates the user selecting the
    /// menu item ... without visibly displaying the menu").
    private func openSettingsWindowIfNeeded() {
        guard appState.settings.serverBaseURL == nil || appState.settings.accessToken == nil else { return }
        openSettingsWindow()
    }

    /// Wiederverwendet von openSettingsWindowIfNeeded() (Ersteinrichtung) und
    /// vom Klick auf eine Update-Benachrichtigung (siehe
    /// UNUserNotificationCenterDelegate-Erweiterung unten) — derselbe
    /// SettingsLink-Mechanismus, unbedingt.
    private func openSettingsWindow() {
        let menu = NSHostingMenu(rootView: SettingsLink { Text(appState.t(.settingsEllipsis)) })
        menu.performActionForItem(at: 0)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.menuBarIcon
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let hostingController = NSHostingController(
            rootView: MenuBarContentView()
                .environment(appState)
                .environment(popoverNavigationState)
        )
        hostingController.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        // .transient statt .applicationDefined würde AppKits eigenen
        // Outside-Click-Monitor übernehmen lassen — der bricht aber
        // zuverlässig, sobald im Popover-Inhalt einmal ein NSMenu
        // getrackt wurde (z.B. das Aufklappen des SwiftUI-Pickers für die
        // Player-Auswahl, der intern über NSPopUpButton läuft): danach
        // schließt das Popover bei Außenklicks nicht mehr. Mit
        // .applicationDefined übernehmen die eigenen Event-Monitore in
        // startOutsideClickMonitor()/closePopover() das komplett und
        // zuverlässig selbst.
        popover.behavior = .applicationDefined
        popover.contentViewController = hostingController
        self.popover = popover
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Muss vor popover.show() passieren: ohne echte App-Aktivierung
            // startet das native NSPopUpButton-Tracking des SwiftUI-Pickers
            // (prüft NSApp.isActive) beim ersten Klick nicht zuverlässig
            // (Dropdown öffnet kurz und schließt sofort wieder). Bewusst
            // kein Policy-Wechsel auf .regular wie bei WindowActivation
            // (Settings/Suche) — als .accessory-App zeigt sie laut
            // Apple-Doku auch aktiviert kein Dock-Icon, das
            // Policy-Umschalten dort ist es, was das Dock-Icon erzeugt,
            // nicht NSApp.activate() allein.
            popoverNavigationState.notifyWillOpen()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ohne das bleibt das Popover-Fenster "nicht key" (Controls wie
            // der Play-Button rendern inaktiv), bis man reinklickt.
            popover.contentViewController?.view.window?.makeKey()
            startOutsideClickMonitor()
            // Leichtgewichtiger Sicherheitsnetz-Refresh beim Öffnen (z.B. für
            // verpasste Events) — no-op, falls gerade kein Client verbunden ist.
            Task { await appState.reloadPlayers() }
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        stopOutsideClickMonitor()
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        localOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopoverIfClickOutside(event)
            return event
        }
        globalOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Ein globaler Monitor sieht nur Klicks außerhalb der eigenen
            // App, kann also nie den Status-Item-Button selbst treffen —
            // hier ist ein Schließen immer korrekt.
            self?.closePopover()
        }
    }

    private func stopOutsideClickMonitor() {
        if let localOutsideClickMonitor {
            NSEvent.removeMonitor(localOutsideClickMonitor)
        }
        localOutsideClickMonitor = nil
        if let globalOutsideClickMonitor {
            NSEvent.removeMonitor(globalOutsideClickMonitor)
        }
        globalOutsideClickMonitor = nil
    }

    private func closePopoverIfClickOutside(_ event: NSEvent) {
        // Klicks innerhalb des Popovers selbst ignorieren (sonst würde
        // jeder Klick auf Play/Slider/Dropdown das Popover sofort wieder
        // schließen). Klicks auf den Status-Item-Button ebenfalls
        // ignorieren: dessen eigener button.action (statusItemClicked)
        // übernimmt das Toggle bereits — würde der Monitor hier zusätzlich
        // schließen, öffnet der anschließende Klick das Popover sofort
        // wieder (Flackern statt sauberem Schließen).
        if event.window === popover?.contentViewController?.view.window { return }
        if event.window === statusItem?.button?.window { return }
        closePopover()
    }

    private func showContextMenu() {
        // NSMenu + der klassische `sendAction(Selector(("showSettingsWindow:")))`-
        // Trick wird von neueren macOS-Versionen für das Öffnen der Settings-
        // Scene nicht mehr zuverlässig unterstützt ("Please use SettingsLink").
        // NSHostingMenu übersetzt SwiftUI-Menüinhalt (inkl. SettingsLink) in
        // ein natives NSMenu, dadurch funktioniert SettingsLink korrekt.
        let menu = NSHostingMenu(rootView: ContextMenuContent(
            settingsLabel: appState.t(.settingsEllipsis),
            quitLabel: appState.t(.quit)
        ))

        // Menü nur für diesen einen Klick setzen: Ist statusItem.menu dauerhaft
        // gesetzt, übernimmt AppKit die Klick-Behandlung komplett und der
        // normale button.action (für Linksklick/Popover) feuert nie wieder.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
}

/// Reagiert auf Klicks auf die Update-Benachrichtigung (UpdateNotifier in
/// MAMenubarLib postet sie, öffnen der Settings ist aber AppKit-/UI-Code und
/// gehört daher hierher). Beide Requirements sind laut Protokoll nonisolated
/// (das System ruft sie von beliebigem Thread auf) — Zugriff auf
/// @MainActor-Zustand (appState, openSettingsWindow()) daher über einen
/// expliziten Hop, analog zum didWakeNotification-Observer oben.
extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Ohne das würde macOS eine Benachrichtigung unterdrücken, solange
        // die App im Vordergrund ist — bei einer Menüleisten-App soll sie
        // aber immer sichtbar werden.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // completionHandler ist kein @Sendable-Closure — nicht mit in den
        // Task { @MainActor in ... }-Block einfangen (Swift-6-Data-Race-
        // Fehler), stattdessen sofort synchron aufrufen. Das UI-Öffnen muss
        // darauf ohnehin nicht warten, das System braucht die Bestätigung nur
        // als "Verarbeitung abgeschlossen"-Signal.
        let identifier = response.notification.request.identifier
        if identifier.hasPrefix("update-") {
            Task { @MainActor in
                self.openSettingsWindow()
            }
        }
        completionHandler()
    }
}

/// Inhalt des Rechtsklick-Kontextmenüs, gehostet über NSHostingMenu.
/// SettingsLink ist der von macOS vorgeschriebene Weg, um die Settings-Scene
/// programmatisch zu öffnen (der alte showSettingsWindow:-Selector-Trick
/// wird nicht mehr zuverlässig unterstützt).
private struct ContextMenuContent: View {
    // Plain Strings statt @Environment(AppState.self): dieses Menü wird über
    // ein frisches NSHostingMenu ohne .environment(appState)-Injection
    // gehostet (siehe showContextMenu()), ein Environment-Lookup würde daher
    // fehlschlagen. Da das Menü bei jedem Rechtsklick neu gebaut wird
    // (kein persistenter View wie das Popover), ist das unproblematisch.
    let settingsLabel: String
    let quitLabel: String

    var body: some View {
        SettingsLink {
            Text(settingsLabel)
        }
        Divider()
        Button(quitLabel) {
            NSApp.terminate(nil)
        }
    }
}
