import SwiftUI
import MAMenubarLib

/// Haupt-Lautstärkeregler plus, sofern der gewählte Player eine Sync-/
/// Gruppen-Player-Queue mit lautstärkefähigen Mitgliedern ist, ein
/// Gruppen-Icon daneben, das bei Klick die einzelnen Mitglieder-Regler
/// einblendet — Pendant zur "Gruppen-Lautstärke"-Sektion im HTML-Player
/// (../ma-html-player/ma-dashboard.html, renderVolumeMembers()), aber ohne
/// im eingeklappten Zustand eine eigene Zeile zu belegen. Mitglieder-Updates
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

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VolumeSliderView(volumeLevel: appState.selectedPlayer?.effectiveVolume) { level in
                    appState.setVolume(level)
                }

                if !members.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "hifispeaker.2.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(isExpanded ? .green : .primary)
                    }
                    .buttonStyle(.glass)
                    // hifispeaker.2.fill zeigt zwei Geräte nebeneinander statt eines
                    // einzelnen quadratischen Symbols wie bei den anderen Buttons
                    // (heart, shuffle.circle, …) — .glass bemisst die Pillenbreite
                    // an einem nackten Image (ohne Label) offenbar großzügiger als
                    // an deren Label(...).labelStyle(.iconOnly). Ein explizites
                    // Frame auf dem Button selbst (statt nur auf dem Icon) deckelt
                    // die Gesamtbreite hart auf die Größe der anderen Buttons.
                    .frame(width: 32, height: 32)
                    .help(appState.t(.groupVolume))
                }
            }

            if isExpanded && !members.isEmpty {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // Beim Player-Wechsel schließen — sonst bliebe die Ansicht z.B. für
        // einen Einzelplayer ohne Gruppe fälschlich "aufgeklappt" hängen.
        .onChange(of: appState.selectedPlayerID) { _, _ in
            isExpanded = false
        }
    }
}
