import SwiftUI
import MAMenubarLib

/// Detailansicht eines Albums (Drill-down aus AlbumRowView im Suchfenster/
/// Artist-Detailansicht oder per Popover-Klick auf den Titel des laufenden
/// Songs, siehe SearchDestination) — ersetzt für Alben das generische
/// MediaDetailView, damit Eyebrow-Label, klickbarer Interpret und
/// Play-Button (analog zu ArtistDetailView) verfügbar sind.
struct AlbumDetailView: View {
    let itemId: String
    let provider: String
    let name: String
    let uri: String?
    let artistName: String?
    let artistRef: MediaItemRef?

    @State private var tracks: [Track] = []
    @State private var loadState: LoadState = .loading

    @Environment(AppState.self) private var appState

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch loadState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    ContentUnavailableView(
                        appState.t(.tracksLoadFailed),
                        systemImage: "xmark.circle",
                        description: Text(message)
                    )
                case .loaded:
                    List {
                        Section(appState.t(.mediaTypeTrack)) {
                            ForEach(tracks) { TrackRowView(track: $0) }
                        }
                    }
                }
            }
        }
        .navigationTitle(name)
        .task {
            await load()
        }
    }

    // Eyebrow-Label "Album" oben, damit auch ein Album mit nur einem Titel
    // (der dann genauso heißt wie das Album selbst) klar von einer normalen
    // Titel-/Playlist-Ansicht unterscheidbar ist.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appState.t(.albumEyebrow))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let artistName {
                        artistLabel(artistName)
                    }
                    Text(name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    play()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(uri == nil)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func artistLabel(_ artistName: String) -> some View {
        if let artistRef {
            NavigationLink(value: SearchDestination.artist(
                itemId: artistRef.itemId, provider: artistRef.provider, name: artistRef.name, uri: artistRef.uri
            )) {
                HStack(spacing: 4) {
                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            Text(artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            tracks = try await appState.loadAlbumTracks(itemId: itemId, provider: provider)
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }

    private func play() {
        guard let uri else { return }
        Task { try? await appState.play(uri: uri) }
    }
}
