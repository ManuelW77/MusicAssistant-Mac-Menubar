import AppKit
import SwiftUI
import MAMenubarLib

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

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
                    .fill(.quaternary)
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

            PlayerControlsView(
                playbackState: appState.selectedPlayer?.playbackState,
                onPrevious: appState.previous,
                onPlayPause: appState.playPause,
                onNext: appState.next
            )

            PlayerPickerView(players: appState.availablePlayers, selectedPlayerID: $appState.selectedPlayerID)

            ConnectionStatusView(status: appState.connectionStatus)

            Divider()

            HStack {
                Button("Einstellungen…") {
                    // Als LSUIElement-App hat der Prozess standardmäßig keine
                    // Fokus-/Vordergrund-Rechte; kurzzeitig auf .regular
                    // umschalten, damit das Fenster wirklich key/aktiv wird
                    // (sonst landet es unfokussiert hinter anderen Fenstern).
                    NSApp.setActivationPolicy(.regular)
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Beenden") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 220)
    }
}
