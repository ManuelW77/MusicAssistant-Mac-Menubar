import AppKit
import Observation
import SwiftUI
import MAMenubarLib

/// Verwaltet das Menüleisten-Icon manuell über NSStatusItem statt über
/// SwiftUIs MenuBarExtra: Linksklick öffnet ein Popover mit Cover/Controls,
/// Rechtsklick zeigt ein Menü mit Einstellungen/Beenden. MenuBarExtra
/// unterscheidet Klick-Buttons nicht, daher der AppKit-Weg.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()
        setupStatusItem()
        observeConnectionStatus()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = statusIcon(for: appState.connectionStatus)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let hostingController = NSHostingController(rootView: MenuBarContentView().environment(appState))
        hostingController.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.behavior = .transient
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
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        // NSMenu + der klassische `sendAction(Selector(("showSettingsWindow:")))`-
        // Trick wird von neueren macOS-Versionen für das Öffnen der Settings-
        // Scene nicht mehr zuverlässig unterstützt ("Please use SettingsLink").
        // NSHostingMenu übersetzt SwiftUI-Menüinhalt (inkl. SettingsLink) in
        // ein natives NSMenu, dadurch funktioniert SettingsLink korrekt.
        let menu = NSHostingMenu(rootView: ContextMenuContent())

        // Menü nur für diesen einen Klick setzen: Ist statusItem.menu dauerhaft
        // gesetzt, übernimmt AppKit die Klick-Behandlung komplett und der
        // normale button.action (für Linksklick/Popover) feuert nie wieder.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func observeConnectionStatus() {
        withObservationTracking {
            _ = appState.connectionStatus
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.statusItem?.button?.image = self?.statusIcon(for: self?.appState.connectionStatus ?? .disconnected)
                self?.observeConnectionStatus()
            }
        }
    }

    private func statusIcon(for status: ConnectionStatus) -> NSImage? {
        let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: "MA Menubar")
        image?.isTemplate = true
        return image
    }
}

/// Inhalt des Rechtsklick-Kontextmenüs, gehostet über NSHostingMenu.
/// SettingsLink ist der von macOS vorgeschriebene Weg, um die Settings-Scene
/// programmatisch zu öffnen (der alte showSettingsWindow:-Selector-Trick
/// wird nicht mehr zuverlässig unterstützt).
private struct ContextMenuContent: View {
    var body: some View {
        SettingsLink {
            Text("Einstellungen…")
        }
        Divider()
        Button("Beenden") {
            NSApp.terminate(nil)
        }
    }
}
