import AppKit
import SwiftUI
import MAMenubarLib

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var serverURLText = ""
    @State private var tokenText = ""
    @State private var testState: TestState = .idle
    @State private var testedPlayers: [MAPlayer] = []

    private enum TestState: Equatable {
        case idle
        case testing
        case success(count: Int)
        case failure(String)
    }

    var body: some View {
        TabView {
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }

            playerTab
                .tabItem { Label("Player", systemImage: "hifispeaker") }
        }
        .frame(width: 440, height: 340)
        .onAppear {
            serverURLText = appState.settings.serverBaseURLString
            // Als LSUIElement-App hat der Prozess standardmäßig keine Fokus-/
            // Vordergrund-Rechte; kurzzeitig auf .regular umschalten, damit
            // das Fenster wirklich key/aktiv wird (sonst landet es unfokussiert
            // hinter anderen Fenstern). SettingsLink öffnet das Fenster, kümmert
            // sich aber nicht selbst um App-Aktivierung.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // Wieder zur reinen Menüleisten-App ohne Dock-Icon zurückschalten,
            // sobald das Settings-Fenster geschlossen wird.
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private var serverTab: some View {
        Form {
            Section {
                TextField("Server-URL", text: $serverURLText, prompt: Text("https://music.example.org"))
                SecureField("Token", text: $tokenText, prompt: Text("Long-Lived Access Token"))
            } footer: {
                Text("Der Token wird in der Music-Assistant-Web-UI unter Profil → Access Tokens erzeugt und ausschließlich in der macOS-Keychain gespeichert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Verbindung testen") {
                        testConnection()
                    }
                    .buttonStyle(.glass)
                    .disabled(serverURLText.isEmpty || tokenText.isEmpty || testState == .testing)

                    if testState == .testing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    testStatusLabel
                }

                Button("Speichern") {
                    save()
                }
                .buttonStyle(.glassProminent)
                .disabled(serverURLText.isEmpty || tokenText.isEmpty)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var testStatusLabel: some View {
        switch testState {
        case .idle, .testing:
            EmptyView()
        case .success(let count):
            Label("Verbunden – \(count) Player gefunden", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(2)
        }
    }

    private var playerTab: some View {
        @Bindable var appState = appState

        return VStack(alignment: .leading, spacing: 8) {
            Text("Wähle aus, welche Player im Menüleisten-Popover zur Auswahl stehen sollen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let players = appState.players.isEmpty ? testedPlayers : appState.players

            if players.isEmpty {
                ContentUnavailableView(
                    "Keine Player geladen",
                    systemImage: "hifispeaker.and.homepod",
                    description: Text("Verbinde dich zuerst über den Server-Tab oder lade die Liste neu.")
                )
            } else {
                List(players) { player in
                    Toggle(isOn: Binding(
                        get: { appState.settings.allowedPlayerIDs.contains(player.playerId) },
                        set: { isOn in
                            if isOn {
                                appState.settings.allowedPlayerIDs.insert(player.playerId)
                            } else {
                                appState.settings.allowedPlayerIDs.remove(player.playerId)
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(player.name)
                            if let state = player.playbackState {
                                Text(state.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Button("Player neu laden") {
                Task { await appState.reloadPlayers() }
            }
            .buttonStyle(.glass)
            .padding(.top, 4)
        }
        .padding()
    }

    private func testConnection() {
        guard let url = URL(string: serverURLText) else {
            testState = .failure("Ungültige URL")
            return
        }
        testState = .testing
        Task {
            do {
                let players = try await appState.testConnection(baseURL: url, token: tokenText)
                testedPlayers = players
                testState = .success(count: players.count)
            } catch {
                testState = .failure("\(error)")
            }
        }
    }

    private func save() {
        do {
            try appState.saveCredentials(baseURLString: serverURLText, token: tokenText)
        } catch {
            testState = .failure("Speichern fehlgeschlagen: \(error)")
        }
    }
}
