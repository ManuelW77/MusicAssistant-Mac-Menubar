import SwiftUI
import MAMenubarLib

struct CrossfadeButtonView: View {
    @Environment(AppState.self) private var appState

    @State private var crossfadeEnabled: Bool?
    @State private var isWorking = false

    var body: some View {
        Button {
            toggle()
        } label: {
            Label(
                "Smart Crossfade",
                systemImage: crossfadeEnabled == true
                    ? "arrow.left.arrow.right.circle.fill"
                    : "arrow.left.arrow.right.circle"
            )
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        .help(crossfadeEnabled == true ? appState.t(.smartCrossfadeDisable) : appState.t(.smartCrossfadeEnable))
        .disabled(appState.selectedPlayerID == nil || isWorking)
        .task(id: appState.selectedPlayerID) {
            do {
                crossfadeEnabled = try await appState.loadCrossfadeEnabled()
                print("CrossfadeButtonView: geladen, crossfadeEnabled=\(String(describing: crossfadeEnabled))")
            } catch {
                print("CrossfadeButtonView: Laden fehlgeschlagen: \(error)")
            }
        }
    }

    private func toggle() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let newState = try await appState.toggleCrossfade()
                crossfadeEnabled = newState
                print("CrossfadeButtonView: umgeschaltet auf \(newState)")
            } catch {
                print("CrossfadeButtonView: Umschalten fehlgeschlagen: \(error)")
            }
        }
    }
}
