import SwiftUI
import MAMenubarLib

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddToPlaylist = false

    private var resolvedImageURL: URL? {
        guard let raw = appState.selectedPlayer?.currentMedia?.imageUrl,
              let serverBaseURL = appState.settings.serverBaseURL else { return nil }
        return MassEndpoint.resolveImageURL(raw, serverBaseURL: serverBaseURL)
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 14) {
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
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                Text(appState.selectedPlayer?.currentMedia?.title ?? "Keine Wiedergabe")
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

                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Zu Playlist hinzufügen", systemImage: "text.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .disabled(appState.selectedPlayer?.currentMedia == nil)
                .popover(isPresented: $showAddToPlaylist) {
                    AddToPlaylistView()
                        .environment(appState)
                }
            }

            PlayerControlsView(
                playbackState: appState.selectedPlayer?.playbackState,
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
