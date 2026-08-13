import SwiftUI
import MAMenubarLib

struct AddToPlaylistView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 280)
        .task {
            await load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appState.t(.addToPlaylist))
                .font(.headline)
            Text(trackDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
                List {
                    if !favoritePlaylists.isEmpty {
                        Section {
                            ForEach(favoritePlaylists) { playlist in
                                playlistRow(playlist)
                            }
                        } header: {
                            Text(appState.t(.favoritePlaylists))
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                        }
                    }
                    if !otherPlaylists.isEmpty {
                        Section(appState.t(.allPlaylists)) {
                            ForEach(otherPlaylists) { playlist in
                                playlistRow(playlist)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .listStyle(.plain)
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
            dismiss()
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
            dismiss()
        } catch {
            actionState = .failed("\(error)")
        }
    }
}
