import SwiftUI
import MAMenubarLib

struct MediaThumbnailView: View {
    let imageProxyId: String?
    var size: CGFloat = 40

    @Environment(AppState.self) private var appState

    private var resolvedURL: URL? {
        guard let imageProxyId, let serverBaseURL = appState.settings.serverBaseURL else { return nil }
        return MassEndpoint.resolveImageURL("/imageproxy/\(imageProxyId)", serverBaseURL: serverBaseURL)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
            AsyncImage(url: resolvedURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
