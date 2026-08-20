import SwiftUI
import MAMenubarLib

struct AlbumRowView: View {
    let album: Album

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MediaDetailView(title: album.name, subtitle: album.artistNames.isEmpty ? nil : album.artistNames) {
                    try await appState.loadAlbumTracks(album)
                }
            } label: {
                HStack(spacing: 10) {
                    MediaThumbnailView(imageProxyId: album.imageProxyId)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.name)
                            .lineLimit(1)
                        if !album.artistNames.isEmpty {
                            Text(album.artistNames)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer()
            Button {
                play()
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(appState.t(.play)) { play() }
            Button(appState.t(.addToQueue)) { enqueue() }
        }
    }

    private func play() {
        guard let uri = album.uri else { return }
        Task { try? await appState.play(uri: uri) }
    }

    private func enqueue() {
        guard let uri = album.uri else { return }
        Task { try? await appState.enqueue(uri: uri) }
    }
}
