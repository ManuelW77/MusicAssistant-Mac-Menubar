import SwiftUI
import MAMenubarLib

struct PlayerPickerView: View {
    let players: [MAPlayer]
    @Binding var selectedPlayerID: String?

    @Environment(AppState.self) private var appState

    var body: some View {
        if players.isEmpty {
            Text(appState.t(.noPlayersAllowed))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Player", selection: $selectedPlayerID) {
                ForEach(players) { player in
                    // Bewusst kein Label(_:systemImage:) — auf macOS 26 wird
                    // dessen Icon+Text-Kombination in nativen Menü-/Picker-
                    // Controls (NSPopUpButton/NSMenuItem) nicht zuverlässig
                    // gerendert (bekanntes Problem, siehe Apple Developer
                    // Forums zu Segmented Controls auf macOS 26 — iconOnly/
                    // titleOnly funktionieren einzeln, die Kombination nicht).
                    // Ein Text mit per String-Interpolation eingebettetem
                    // Image bildet sich zuverlässig auf den title-String
                    // eines NSMenuItem ab.
                    if player.playbackState == .playing {
                        Text("\(Image(systemName: "speaker.wave.2.fill")) \(player.name)")
                            .tag(Optional(player.playerId))
                    } else {
                        Text(player.name)
                            .tag(Optional(player.playerId))
                    }
                }
            }
            .labelsHidden()
        }
    }
}
