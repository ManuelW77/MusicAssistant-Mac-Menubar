import AppKit
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

    private static let menuBarIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "MenubarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()
        setupStatusItem()
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
            // Ohne das bleibt das Popover-Fenster "nicht key" (Controls wie
            // der Play-Button rendern inaktiv), bis man reinklickt. Bewusst
            // kein NSApp.activate()/.regular-Policy-Wechsel wie bei den
            // Settings — das würde bei jedem Icon-Klick kurz ein Dock-Icon
            // aufblitzen lassen.
            popover.contentViewController?.view.window?.makeKey()
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
