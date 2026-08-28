import SwiftUI
import MAMenubarLib

struct PlayerPickerView: View {
    let players: [MAPlayer]

    @Environment(AppState.self) private var appState

    private var groups: [MAPlayer] { players.filter(\.isGroup).sortedByName() }
    private var speakers: [MAPlayer] { players.filter { !$0.isGroup }.sortedByName() }

    var body: some View {
        if players.isEmpty {
            Text(appState.t(.noPlayersAllowed))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Player", selection: Binding(
                get: { appState.selectedPlayerID },
                // Über AppState, damit die Wahl als bewusst manuell markiert
                // wird und die playback-getriebene Auto-Vorauswahl sie nicht
                // gleich wieder wegschaltet.
                set: { appState.selectPlayerManually($0) }
            )) {
                if groups.isEmpty || speakers.isEmpty {
                    // Nur eine Sorte sichtbar — Abschnittsüberschriften wären
                    // hier nur unnötiges Rauschen.
                    ForEach(groups + speakers) { row(for: $0) }
                } else {
                    Section(appState.t(.playerPickerGroups)) {
                        ForEach(groups) { row(for: $0) }
                    }
                    Section(appState.t(.playerPickerSpeakers)) {
                        ForEach(speakers) { row(for: $0) }
                    }
                }
            }
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func row(for player: MAPlayer) -> some View {
        // Bewusst kein Label(_:systemImage:) — auf macOS 26 wird dessen
        // Icon+Text-Kombination in nativen Menü-/Picker-Controls
        // (NSPopUpButton/NSMenuItem) nicht zuverlässig gerendert (bekanntes
        // Problem, siehe Apple Developer Forums zu Segmented Controls auf
        // macOS 26 — iconOnly/titleOnly funktionieren einzeln, die
        // Kombination nicht). Ein Text mit per String-Interpolation
        // eingebettetem Image bildet sich zuverlässig auf den title-String
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
