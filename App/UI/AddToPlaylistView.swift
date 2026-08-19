import SwiftUI
import MAMenubarLib

struct AddToPlaylistView: View {
    /// Schließt die Ansicht. Bewusst ein Callback statt `@Environment(\.dismiss)`:
    /// Diese View ist keine eigene Präsentation (Sheet/Fenster/Popover) mehr,
    /// sondern nur ein Inhaltswechsel innerhalb des Menüleisten-Popovers —
    /// siehe Kommentar in MenuBarContentView.
    let onClose: () -> Void

    @Environment(AppState.self) private var appState

    @State private var loadState: LoadState = .loading
    @State private var actionState: ActionState = .idle
    @State private var newPlaylistName = ""

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private enum ActionState: Equatable {
        case idle
        case working
        case created(String)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            content
            Divider()
            createSection
            actionStatusLabel
        }
        .padding(14)
        // Füllt die volle Höhe, die MenuBarContentView per .overlay() über
        // dem unsichtbaren playerContent-Platzhalter anbietet (sonst bliebe
        // trotz gleich hohem Popover ungenutzter Platz unterhalb von
        // createSection) — die ScrollView in `content` wächst entsprechend
        // mit (.frame(maxHeight: .infinity) dort statt einer festen Kappung).
        .frame(maxHeight: .infinity, alignment: .top)
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(appState.t(.back))

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.t(.addToPlaylist))
                    .font(.headline)
                Text(trackDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var trackDescription: String {
        guard let media = appState.selectedPlayer?.currentMedia else { return appState.t(.noTrack) }
        return "\(media.title ?? "-") – \(media.artist ?? "-")"
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        case .failed(let message):
            VStack(spacing: 6) {
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Button(appState.t(.retry)) {
                    Task { await load() }
                }
                .buttonStyle(.glass)
            }
        case .loaded:
            if appState.playlists.isEmpty {
                ContentUnavailableView(
                    appState.t(.noPlaylistsFound),
                    systemImage: "music.note.list",
                    description: Text(appState.t(.createPlaylistHint))
                )
                .frame(height: 120)
            } else {
                // Bewusst ScrollView + VStack statt List: SwiftUIs List-Zellen
                // (CellHostingView) bringen in diesem verschachtelten Popover
                // ihre Gesture-Erkennung durcheinander — nach dem ersten
                // Hinzufügen blieb ein Recognizer im "Began"-Zustand hängen
                // ("Stuck gesture recognizers detected"), woraufhin SwiftUI
                // alle weiteren Gesten ignorierte und ein zweites Hinzufügen
                // unmöglich war. Ohne List-Zellenebene tritt das nicht auf.
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !favoritePlaylists.isEmpty {
                            Text(appState.t(.favoritePlaylists))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                            ForEach(favoritePlaylists) { playlist in
                                playlistRow(playlist)
                            }
                        }
                        if !otherPlaylists.isEmpty {
                            Text(appState.t(.allPlaylists))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, favoritePlaylists.isEmpty ? 0 : 6)
                            ForEach(otherPlaylists) { playlist in
                                playlistRow(playlist)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Füllt die von body() über .frame(maxHeight: .infinity)
                // bereitgestellte Resthöhe komplett aus, statt bei fester
                // Kappung ungenutzten Platz darunter zu lassen — das Popover
                // selbst wächst dadurch nicht weiter (dessen Höhe kommt vom
                // unsichtbaren playerContent-Platzhalter in
                // MenuBarContentView, nicht von hier).
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var favoritePlaylists: [Playlist] {
        appState.playlists.filter(\.favorite)
    }

    private var otherPlaylists: [Playlist] {
        appState.playlists.filter { !$0.favorite }
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        Button {
            Task { await add(to: playlist) }
        } label: {
            Text(playlist.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                // Ohne das wäre nur der Text selbst klickbar, nicht die
                // ganze Zeilenbreite (in der List übernahm das die Zelle).
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(actionState == .working)
    }

    private var createSection: some View {
        HStack {
            TextField(appState.t(.newPlaylistPlaceholder), text: $newPlaylistName)
            Button(appState.t(.create)) {
                Task { await createAndAdd() }
            }
            .buttonStyle(.glassProminent)
            .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty || actionState == .working)
        }
    }

    @ViewBuilder
    private var actionStatusLabel: some View {
        switch actionState {
        case .idle, .working:
            EmptyView()
        case .created(let name):
            Label(L10n.addedToPlaylist(name, appState.uiLanguage), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(2)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            try await appState.loadPlaylists()
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }

    private func add(to playlist: Playlist) async {
        actionState = .working
        do {
            try await appState.addCurrentTrackToPlaylist(playlist)
            actionState = .created(playlist.name)
            try? await Task.sleep(for: .seconds(1))
            onClose()
        } catch {
            actionState = .failed("\(error)")
        }
    }

    private func createAndAdd() async {
        actionState = .working
        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
        do {
            let playlist = try await appState.createPlaylist(name: name)
            try await appState.addCurrentTrackToPlaylist(playlist)
            newPlaylistName = ""
            actionState = .created(playlist.name)
            try? await Task.sleep(for: .seconds(1))
            onClose()
        } catch {
            actionState = .failed("\(error)")
        }
    }
}
