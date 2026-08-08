import SwiftUI
import MAMenubarLib

@main
struct MAMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Kein MenuBarExtra mehr: Das Menüleisten-Icon wird manuell im
        // AppDelegate verwaltet, weil Links-/Rechtsklick unterschiedliche
        // Aktionen auslösen sollen (SwiftUIs MenuBarExtra kann das nicht).
        // .defaultLaunchBehavior(.suppressed) auch hier: ohne das kann macOS'
        // Fenster-Zustands-Wiederherstellung das Settings-Fenster beim
        // nächsten Start erneut öffnen, wenn es beim letzten Beenden offen
        // war. Das gezielte Öffnen bei fehlenden Zugangsdaten übernimmt
        // AppDelegate.applicationDidFinishLaunching.
        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }
        .defaultLaunchBehavior(.suppressed)

        // Anders als Settings ist Window eine "echte" Fenster-Scene und würde
        // ohne defaultLaunchBehavior(.suppressed) beim App-Start automatisch
        // aufgehen — für eine reine Menüleisten-App unerwünscht, das Fenster
        // soll nur über den Lupen-Button im Popover erscheinen.
        Window("Suche", id: "search") {
            SearchView()
                .environment(appDelegate.appState)
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
