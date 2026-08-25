import SwiftUI
import MAMenubarLib

/// Aufklappbarer Bereich mit je einem Lautstärkeregler pro Mitglied einer
/// Sync-/Gruppen-Player-Queue — Pendant zur "Gruppen-Lautstärke"-Sektion im
/// HTML-Player (../ma-html-player/ma-dashboard.html, renderVolumeMembers()).
/// Erscheint nur, wenn der gewählte Player überhaupt lautstärkefähige
/// Gruppenmitglieder hat (AppState.groupMembers(for:)); Mitglieder-Updates
/// (z.B. Lautstärke extern geändert) kommen wie beim Hauptplayer über die
/// normalen playerUpdated-Events in AppState.players an, kein Extra-Polling
/// nötig.
struct GroupVolumeView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    private var members: [MAPlayer] {
        guard let playerID = appState.selectedPlayerID else { return [] }
        return appState.groupMembers(for: playerID)
    }

    var body: some View {
        let members = members
        if !members.isEmpty {
            VStack(spacing: 6) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.t(.groupVolume))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(members) { member in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                VolumeSliderView(volumeLevel: member.effectiveVolume) { level in
                                    appState.setVolume(level, for: member.playerId)
                                }
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }
}
