import AppKit
import SwiftUI
import MAMenubarLib

@main
struct MAMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(appDelegate.appState)
        } label: {
            Image(systemName: appDelegate.appState.connectionStatus.symbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }
    }
}

/// Startet AppState zuverlässig genau einmal beim App-Start — ein `.task`
/// auf dem MenuBarExtra-Content würde erst beim ersten Öffnen des Popovers
/// feuern, da dessen Inhalt im `.window`-Stil lazy erzeugt wird.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()
    }
}
