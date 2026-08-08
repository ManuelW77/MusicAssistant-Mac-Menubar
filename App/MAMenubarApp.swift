import SwiftUI
import MAMenubarLib

@main
struct MAMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Kein MenuBarExtra mehr: Das Menüleisten-Icon wird manuell im
        // AppDelegate verwaltet, weil Links-/Rechtsklick unterschiedliche
        // Aktionen auslösen sollen (SwiftUIs MenuBarExtra kann das nicht).
        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }
    }
}
