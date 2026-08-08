import SwiftUI
import MAMenubarLib

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var serverURLText = ""
    @State private var tokenText = ""
    @State private var testState: TestState = .idle
    @State private var testedPlayers: [MAPlayer] = []
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var updateState: UpdateState = .idle

    private enum TestState: Equatable {
        case idle
        case testing
        case success(count: Int)
        case failure(String)
    }

    private enum UpdateState: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateChecker.UpdateInfo)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private static let repositoryURL = URL(string: "https://github.com/\(UpdateChecker.repository)")!

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Allgemein", systemImage: "gearshape") }

            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }

            playerTab
                .tabItem { Label("Player", systemImage: "hifispeaker") }
        }
        .frame(width: 440, height: 420)
        .onAppear {
            serverURLText = appState.settings.serverBaseURLString
            tokenText = appState.settings.accessToken ?? ""
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            // Als LSUIElement-App hat der Prozess standardmäßig keine Fokus-/
            // Vordergrund-Rechte; WindowActivation schaltet kurzzeitig auf
            // .regular um, damit das Fenster wirklich key/aktiv wird (sonst
            // landet es unfokussiert hinter anderen Fenstern). Referenzgezählt,
            // damit ein gleichzeitig offenes Suche-Fenster nicht beeinträchtigt
            // wird. SettingsLink öffnet das Fenster, kümmert sich aber nicht
            // selbst um App-Aktivierung.
            WindowActivation.windowDidAppear()
            Task { await checkForUpdates() }
        }
        .onDisappear {
            // Wieder zur reinen Menüleisten-App ohne Dock-Icon zurückschalten,
            // sobald keine Fenster mehr offen sind (siehe WindowActivation).
            WindowActivation.windowDidDisappear()
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Bei Anmeldung starten", isOn: launchAtLoginBinding)
            } footer: {
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Über") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Entwickler", value: "Manuel Weiser")
                Link("GitHub-Repository", destination: Self.repositoryURL)

                HStack {
                    Button("Nach Updates suchen") {
                        Task { await checkForUpdates() }
                    }
                    .buttonStyle(.glass)
                    .disabled(updateState == .checking)

                    if updateState == .checking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    updateStatusLabel
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var updateStatusLabel: some View {
        switch updateState {
        case .idle, .checking:
            EmptyView()
        case .upToDate:
            Label("Aktuell", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .available(let info):
            Link(destination: info.url) {
                Label("Version \(info.latestVersion) verfügbar", systemImage: "arrow.down.circle.fill")
            }
            .font(.caption)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLoginEnabled = newValue
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Fehler: \(error.localizedDescription)"
                }
            }
        )
    }

    private var serverTab: some View {
        Form {
            Section {
                TextField("Server-URL", text: $serverURLText, prompt: Text("https://music.example.org"))
                SecureField("Token", text: $tokenText, prompt: Text("Long-Lived Access Token"))
            } footer: {
                Text("Der Token wird in der Music-Assistant-Web-UI unter Profil → Access Tokens erzeugt und lokal in den App-Einstellungen gespeichert.")
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
        appState.saveCredentials(baseURLString: serverURLText, token: tokenText)
    }

    private func checkForUpdates() async {
        updateState = .checking
        if let info = await UpdateChecker.checkForUpdate(currentVersion: appVersion) {
            updateState = .available(info)
        } else {
            updateState = .upToDate
        }
    }
}
