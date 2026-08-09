import SwiftUI
import MAMenubarLib

struct FavoriteButtonView: View {
    @Environment(AppState.self) private var appState

    @State private var isFavorite: Bool?
    @State private var isWorking = false

    private var currentURI: String? {
        appState.selectedPlayer?.currentMedia?.uri
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            Label(appState.t(.favorite), systemImage: isFavorite == true ? "heart.fill" : "heart")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        .tint(isFavorite == true ? .red : nil)
        .help(isFavorite == true ? appState.t(.removeFromFavorites) : appState.t(.addToFavorites))
        .disabled(currentURI == nil || isWorking)
        .task(id: currentURI) {
            isFavorite = try? await appState.loadFavoriteStatus()
        }
    }

    private func toggle() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            if let newState = try? await appState.toggleFavorite() {
                isFavorite = newState
            }
        }
    }
}
