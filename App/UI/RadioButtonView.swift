import SwiftUI
import MAMenubarLib

struct RadioButtonView: View {
    @Environment(AppState.self) private var appState
    @State private var isWorking = false

    var body: some View {
        Button {
            start()
        } label: {
            Label(appState.t(.startRadio), systemImage: "dot.radiowaves.left.and.right")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .buttonStyle(.glass)
        .help(appState.t(.startRadio))
        .disabled(appState.selectedPlayer?.currentMedia == nil || isWorking)
    }

    private func start() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            try? await appState.startRadio()
        }
    }
}
