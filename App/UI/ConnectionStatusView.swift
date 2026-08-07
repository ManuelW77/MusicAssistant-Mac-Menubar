import SwiftUI
import MAMenubarLib

struct ConnectionStatusView: View {
    let status: ConnectionStatus

    var body: some View {
        if status != .connected {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.orange)
                Text(status.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
