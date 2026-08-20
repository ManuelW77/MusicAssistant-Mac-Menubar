import SwiftUI
import MAMenubarLib

/// Detailansicht eines Interpreten (Drill-down aus ArtistRowView im
/// Suchfenster oder per Popover-Klick auf Interpret/Titel des laufenden
/// Songs, siehe SearchDestination) — lädt Top-Titel, alle Titel und Alben
/// parallel, analog zu den drei dedizierten MA-Kommandos
/// (music/artists/top_tracks, artist_tracks, artist_albums).
struct ArtistDetailView: View {
    let itemId: String
    let provider: String
    let name: String

    @State private var topTracks: [Track] = []
    @State private var tracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var loadState: LoadState = .loading

    @Environment(AppState.self) private var appState

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
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
                    if !topTracks.isEmpty {
                        Section(appState.t(.topTracks)) {
                            ForEach(topTracks) { TrackRowView(track: $0) }
                        }
                    }
                    if !tracks.isEmpty {
                        Section(appState.t(.mediaTypeTrack)) {
                            ForEach(tracks) { TrackRowView(track: $0) }
                        }
                    }
                    if !albums.isEmpty {
                        Section(appState.t(.mediaTypeAlbum)) {
                            ForEach(albums) { AlbumRowView(album: $0) }
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

    private func load() async {
        loadState = .loading
        do {
            async let top = appState.loadArtistTopTracks(itemId: itemId, provider: provider)
            async let all = appState.loadArtistTracks(itemId: itemId, provider: provider)
            async let albs = appState.loadArtistAlbums(itemId: itemId, provider: provider)
            (topTracks, tracks, albums) = try await (top, all, albs)
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }
}
