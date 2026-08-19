import SwiftUI
import MAMenubarLib

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showAddToPlaylist = false

    private var resolvedImageURL: URL? {
        guard let raw = appState.selectedPlayer?.currentMedia?.imageUrl,
              let serverBaseURL = appState.settings.serverBaseURL else { return nil }
        return MassEndpoint.resolveImageURL(raw, serverBaseURL: serverBaseURL)
    }

    private var playbackProgress: Double? {
        if let interpolated = appState.displayedPlaybackProgress {
            return interpolated
        }
        guard let media = appState.selectedPlayer?.currentMedia,
              let duration = media.duration, duration > 0,
              let elapsed = media.elapsedTime else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }

    private static let coverSize: CGFloat = 160
    private static let progressBarInset: CGFloat = 8
    private static var progressBarWidth: CGFloat { coverSize - 2 * progressBarInset }
    private static let progressTrackExtraWidth: CGFloat = 10
    private static var progressTrackWidth: CGFloat { progressBarWidth + progressTrackExtraWidth }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                    AsyncImage(url: resolvedImageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let playbackProgress {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: Self.progressTrackWidth, height: 8)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, Self.progressBarWidth * playbackProgress - 4), height: 4)
                            .padding(.leading, 2)
                    }
                    .padding(.bottom, 6)
                }
            }
            .frame(width: Self.coverSize, height: Self.coverSize)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                Text(appState.selectedPlayer?.currentMedia?.title ?? appState.t(.noPlayback))
                    .font(.headline)
                    .lineLimit(1)
                Text(appState.selectedPlayer?.currentMedia?.artist ?? " ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                FavoriteButtonView()

                RadioButtonView()

                CrossfadeButtonView()

                Button {
                    showAddToPlaylist = true
                } label: {
                    Label(appState.t(.addToPlaylist), systemImage: "text.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .help(appState.t(.addToPlaylist))
                .disabled(appState.selectedPlayer?.currentMedia == nil)
                .popover(isPresented: $showAddToPlaylist) {
                    AddToPlaylistView()
                        .environment(appState)
                        .dismissPopoverOnOutsideClick(isPresented: $showAddToPlaylist)
                }

                Button {
                    openWindow(id: "search")
                } label: {
                    Label(appState.t(.search), systemImage: "magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .help(appState.t(.search))
            }

            PlayerControlsView(
                playbackState: appState.selectedPlayer?.playbackState,
                isPlayPauseCommandPending: appState.isPlayPauseCommandPending,
                onPrevious: appState.previous,
                onPlayPause: appState.playPause,
                onNext: appState.next
            )

            VolumeSliderView(volumeLevel: appState.selectedPlayer?.effectiveVolume) { level in
                appState.setVolume(level)
            }

            PlayerPickerView(players: appState.availablePlayers, selectedPlayerID: $appState.selectedPlayerID)

            ConnectionStatusView(status: appState.connectionStatus)
        }
        .padding(16)
        .frame(width: 220)
    }
}
