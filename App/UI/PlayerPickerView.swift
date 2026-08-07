import SwiftUI
import MAMenubarLib

struct PlayerPickerView: View {
    let players: [MAPlayer]
    @Binding var selectedPlayerID: String?

    var body: some View {
        if players.isEmpty {
            Text("Keine Player freigegeben – siehe Einstellungen")
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
