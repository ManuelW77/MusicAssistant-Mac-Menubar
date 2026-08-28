import SwiftUI
import MAMenubarLib

/// Haupt-Lautstärkeregler plus, sofern der gewählte Player eine Sync-/
/// Gruppen-Player-Queue ist, ein Gruppen-Icon daneben, das bei Klick eine
/// Verwaltungsansicht einblendet: je Mitglied ein Lautstärkeregler mit
/// Entfernen-Button, darunter (falls der Gruppenleiter `set_members`
/// unterstützt) weitere freigegebene Player zum Hinzufügen — Pendant zu
/// renderVolumeMembers()/renderGroupMenu() im HTML-Player
/// (../ma-html-player/ma-dashboard.html), aber in einer einzigen
/// aufklappbaren Ansicht statt zweier getrennter UI-Bereiche, und ohne im
/// eingeklappten Zustand eine eigene Zeile zu belegen. Updates (z.B.
/// Lautstärke oder Gruppenzugehörigkeit extern geändert) kommen wie beim
/// Hauptplayer über die normalen playerUpdated-Events in AppState.players
/// an, kein Extra-Polling nötig.
struct GroupVolumeView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    /// Alle Mitglieder unabhängig von Lautstärkefähigkeit (requireVolumeControl:
    /// false) — für die Verwaltungsansicht braucht es auch entfernbare
    /// Mitglieder ohne eigenen Lautstärkeregler.
    private var members: [MAPlayer] {
        guard let playerID = appState.selectedPlayerID else { return [] }
        return appState.groupMembers(for: playerID, requireVolumeControl: false).sortedByName()
    }

    private var candidates: [MAPlayer] {
        guard let playerID = appState.selectedPlayerID else { return [] }
        return appState.groupingCandidates(for: playerID).sortedByName()
    }

    var body: some View {
        let members = members
        let candidates = candidates
        let hasContent = !members.isEmpty || !candidates.isEmpty

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VolumeSliderView(volumeLevel: appState.selectedPlayer?.effectiveVolume) { level in
                    appState.setVolume(level)
                }

                if hasContent {
                    // Bewusst OHNE withAnimation(): MenuBarContentView lebt in
                    // einem NSHostingController mit sizingOptions =
                    // .preferredContentSize (siehe AppDelegate.swift), der
                    // NSPopover bei jeder Content-Größenänderung selbst
                    // resized. Lässt SwiftUI die Höhe der VStack zusätzlich
                    // selbst interpolieren (egal mit welcher .transition —
                    // sowohl .move+.opacity als auch reines .opacity wurden
                    // getestet), meldet der Hosting-Controller bei jedem
                    // Zwischenwert ein neues Zielmaß an das bereits
                    // animierende NSPopover — das erzeugt sichtbares Gruckeln
                    // des gesamten Inhalts. Die Höhenänderung selbst bleibt
                    // daher instantan; die eigentliche Slide-Optik liefert
                    // MembersRevealView unten rein lokal über offset/opacity,
                    // was die gemeldete Content-Größe nicht berührt.
                    Button {
                        isExpanded.toggle()
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

            if isExpanded && hasContent {
                MembersRevealView(members: members, candidates: candidates)
            }
        }
        // Beim Player-Wechsel schließen — sonst bliebe die Ansicht z.B. für
        // einen Einzelplayer ohne Gruppe fälschlich "aufgeklappt" hängen.
        .onChange(of: appState.selectedPlayerID) { _, _ in
            isExpanded = false
        }
    }
}

/// Reine Optik für das Einblenden der Verwaltungsansicht: die umgebende
/// VStack in GroupVolumeView reserviert den Platz sofort/unanimiert (siehe
/// Kommentar dort), erst NACH dem Erscheinen (`.onAppear`, Layout also schon
/// fertig) startet diese View ihre eigene, rein lokale Animation von
/// `.offset`/`.opacity` — beides beeinflusst die gemeldete Ideal-Größe des
/// Hosting-Controllers nicht, wodurch der Effekt (Inhalt schiebt sich leicht
/// von oben herein und blendet auf) nicht mit dem NSPopover-Resize
/// kollidiert.
private struct MembersRevealView: View {
    let members: [MAPlayer]
    let candidates: [MAPlayer]
    @Environment(AppState.self) private var appState
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(members) { member in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(member.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            appState.removeFromGroup(member.playerId)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(appState.t(.groupRemove))
                    }

                    if member.supportsVolumeControl {
                        VolumeSliderView(volumeLevel: member.effectiveVolume) { level in
                            appState.setVolume(level, for: member.playerId)
                        }
                    }
                }
            }

            if !candidates.isEmpty {
                if !members.isEmpty {
                    Divider()
                }

                Text(appState.t(.groupAddSpeakers))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(candidates) { candidate in
                    HStack(spacing: 4) {
                        Text(candidate.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            appState.addToGroup(candidate.playerId)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(appState.t(.groupAdd))
                    }
                }
            }
        }
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : -8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isRevealed = true
            }
        }
    }
}
