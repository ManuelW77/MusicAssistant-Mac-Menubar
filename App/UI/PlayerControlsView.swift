import SwiftUI
import MAMenubarLib

struct PlayerControlsView: View {
    let playbackState: PlaybackState?
    let isPlayPauseCommandPending: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    private var isPlaying: Bool { playbackState == .playing }

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .opacity(isPlayPauseCommandPending ? 0.2 : 1.0)
                        .animation(
                            isPlayPauseCommandPending
                                ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                                : .easeInOut(duration: 0.2),
                            value: isPlayPauseCommandPending
                        )
                }
                .buttonStyle(.glassProminent)

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
            }
        }
    }
}
