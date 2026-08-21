import SwiftUI
import MAMenubarLib

struct ArtistRowView: View {
    let artist: Artist

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(
                value: SearchDestination.artist(
                    itemId: artist.itemId, provider: artist.provider, name: artist.name, uri: artist.uri
                )
            ) {
                HStack(spacing: 10) {
                    MediaThumbnailView(imageProxyId: artist.imageProxyId)
                    Text(artist.name)
                        .lineLimit(1)
                }
            }
            Spacer()
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
        guard let uri = artist.uri else { return }
        Task { try? await appState.play(uri: uri) }
    }

    private func enqueue() {
        guard let uri = artist.uri else { return }
        Task { try? await appState.enqueue(uri: uri) }
    }
}
