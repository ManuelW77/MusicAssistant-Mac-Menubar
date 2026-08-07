import SwiftUI
import MAMenubarLib

struct PlayerControlsView: View {
    let playbackState: PlaybackState?
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    private var isPlaying: Bool { playbackState == .playing }

    var body: some View {
        HStack(spacing: 28) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
    }
}
