import SwiftUI
import MAMenubarLib

struct PlaylistRowView: View {
    let playlist: Playlist

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MediaDetailView(title: playlist.name) {
                    try await appState.loadPlaylistTracks(playlist)
                }
            } label: {
                HStack(spacing: 10) {
                    MediaThumbnailView(imageProxyId: playlist.imageProxyId)
                    Text(playlist.name)
                        .lineLimit(1)
                }
            }
            Spacer()
            ProviderIconView(domain: playlist.sourceProviderDomain, size: 16)
            Button {
                play()
            } label: {
                Image(systemName: "play.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(appState.t(.play)) { play() }
            Button(appState.t(.addToQueue)) { enqueue() }
        }
    }

    private func play() {
        guard let uri = playlist.uri else { return }
        Task { try? await appState.play(uri: uri) }
    }

    private func enqueue() {
        guard let uri = playlist.uri else { return }
        Task { try? await appState.enqueue(uri: uri) }
    }
}
