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
                    Text(player.name).tag(Optional(player.playerId))
                }
            }
            .labelsHidden()
        }
    }
}
