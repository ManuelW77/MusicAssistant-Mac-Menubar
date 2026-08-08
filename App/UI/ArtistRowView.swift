import SwiftUI
import MAMenubarLib

struct ArtistRowView: View {
    let artist: Artist

    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            play()
        } label: {
            HStack(spacing: 10) {
                MediaThumbnailView(imageProxyId: artist.imageProxyId)
                Text(artist.name)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "play.circle")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Abspielen") { play() }
            Button("Zur Warteschlange hinzufügen") { enqueue() }
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
