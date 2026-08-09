import SwiftUI
import MAMenubarLib

struct TrackRowView: View {
    let track: Track

    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            play()
        } label: {
            HStack(spacing: 10) {
                MediaThumbnailView(imageProxyId: track.imageProxyId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .lineLimit(1)
                    if !track.artistNames.isEmpty {
                        Text(track.artistNames)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "play.circle")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(appState.t(.play)) { play() }
            Button(appState.t(.addToQueue)) { enqueue() }
        }
    }

    private func play() {
        guard let uri = track.uri else { return }
        Task { try? await appState.play(uri: uri) }
    }

    private func enqueue() {
        guard let uri = track.uri else { return }
        Task { try? await appState.enqueue(uri: uri) }
    }
}
