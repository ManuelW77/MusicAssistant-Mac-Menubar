import SwiftUI
import MAMenubarLib

struct ConnectionStatusView: View {
    let status: ConnectionStatus

    @Environment(AppState.self) private var appState

    var body: some View {
        if status != .connected {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.orange)
                Text(status.description(appState.uiLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(in: Capsule())
        }
    }
}
