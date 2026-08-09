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

    private enum TestState: Equatable {
        case idle
        case testing
        case success(count: Int)
        case failure(String)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private static let repositoryURL = URL(string: "https://github.com/\(UpdateChecker.repository)")!

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(appState.t(.generalTabLabel), systemImage: "gearshape") }

            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") } // "Server" ist DE/EN identisch

            playerTab
                .tabItem { Label("Player", systemImage: "hifispeaker") } // "Player" ist DE/EN identisch
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
            // Kein Task { await checkForUpdates() } mehr nötig — die
            // Hintergrund-Update-Check-Schleife (AppState.startUpdateChecks())
            // hat beim App-Start bereits einen Check gemacht, dieses Fenster
            // liest nur noch den geteilten Status.
        }
        .onDisappear {
            // Wieder zur reinen Menüleisten-App ohne Dock-Icon zurückschalten,
            // sobald keine Fenster mehr offen sind (siehe WindowActivation).
            WindowActivation.windowDidDisappear()
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appState.settings.language },
            set: { appState.settings.language = $0 }
        )
    }

    private func languageDisplayName(_ language: AppLanguage) -> String {
        switch language {
        case .de: return "Deutsch"
        case .en: return "English"
        case .system: return appState.t(.systemLanguageOption)
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle(appState.t(.startAtLogin), isOn: launchAtLoginBinding)
                Picker(appState.t(.languageLabel), selection: languageBinding) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(languageDisplayName(language)).tag(language)
                    }
                }
            } footer: {
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(appState.t(.about)) {
                LabeledContent("Version", value: appVersion)
                LabeledContent(appState.t(.developer), value: "Manuel Weiser")
                Link(appState.t(.githubRepo), destination: Self.repositoryURL)

                HStack {
                    Button(appState.t(.checkForUpdates)) {
                        Task { await appState.checkForUpdate() }
                    }
                    .buttonStyle(.glass)
                    .disabled(appState.isCheckingForUpdate)

                    if appState.isCheckingForUpdate {
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
        if appState.isCheckingForUpdate {
            EmptyView()
        } else if let info = appState.updateInfo {
            Link(destination: info.url) {
                Label(L10n.versionAvailable(info.latestVersion, appState.uiLanguage), systemImage: "arrow.down.circle.fill")
            }
            .font(.caption)

            if let notes = info.releaseNotes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
        } else if appState.lastUpdateCheckDate != nil {
            Label(appState.t(.upToDate), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
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
                    launchAtLoginError = L10n.genericError(error.localizedDescription, appState.uiLanguage)
                }
            }
        )
    }

    private var serverTab: some View {
        Form {
            Section {
                TextField(appState.t(.serverURL), text: $serverURLText, prompt: Text("https://music.example.org"))
                SecureField("Token", text: $tokenText, prompt: Text("Long-Lived Access Token"))
            } footer: {
                Text(appState.t(.tokenFooter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button(appState.t(.testConnection)) {
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

                Button(appState.t(.save)) {
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
            Label(L10n.connectedPlayersFound(count, appState.uiLanguage), systemImage: "checkmark.circle.fill")
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
            Text(appState.t(.selectPlayersHint))
                .font(.caption)
                .foregroundStyle(.secondary)

            let players = appState.players.isEmpty ? testedPlayers : appState.players

            if players.isEmpty {
                ContentUnavailableView(
                    appState.t(.noPlayersLoaded),
                    systemImage: "hifispeaker.and.homepod",
                    description: Text(appState.t(.connectFirstHint))
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

            Button(appState.t(.reloadPlayers)) {
                Task { await appState.reloadPlayers() }
            }
            .buttonStyle(.glass)
            .padding(.top, 4)
        }
        .padding()
    }

    private func testConnection() {
        guard let url = URL(string: serverURLText) else {
            testState = .failure(appState.t(.invalidURL))
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
}
