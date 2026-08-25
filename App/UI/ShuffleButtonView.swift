import SwiftUI
import MAMenubarLib

struct ShuffleButtonView: View {
    @Environment(AppState.self) private var appState

    @State private var shuffleEnabled: Bool?
    @State private var isWorking = false

    var body: some View {
        Button {
            toggle()
        } label: {
            Label(
                "Shuffle",
                systemImage: shuffleEnabled == true ? "shuffle.circle.fill" : "shuffle.circle"
            )
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(shuffleEnabled == true ? .green : .primary)
        }
        .buttonStyle(.glass)
        .help(shuffleEnabled == true ? appState.t(.shuffleDisable) : appState.t(.shuffleEnable))
        .disabled(appState.selectedPlayerID == nil || isWorking)
        .task(id: appState.selectedPlayerID) {
            await reload()
        }
        .onChange(of: appState.queueUpdateToken) {
            Task { await reload() }
        }
    }

    private func reload() async {
        do {
            shuffleEnabled = try await appState.loadShuffleEnabled()
            print("ShuffleButtonView: geladen, shuffleEnabled=\(String(describing: shuffleEnabled))")
        } catch {
            print("ShuffleButtonView: Laden fehlgeschlagen: \(error)")
        }
    }

    private func toggle() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let newState = try await appState.toggleShuffle()
                shuffleEnabled = newState
                print("ShuffleButtonView: umgeschaltet auf \(newState)")
            } catch {
                print("ShuffleButtonView: Umschalten fehlgeschlagen: \(error)")
            }
        }
    }
}
