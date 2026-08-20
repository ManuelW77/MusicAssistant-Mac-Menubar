import SwiftUI
import MAMenubarLib

/// Generische Titel-Listen-Detailansicht für den Drill-down aus Playlist-/
/// Album-Zeilen — nimmt die Ladefunktion als Closure entgegen, damit die
/// Track-Listen-Logik nicht pro Medientyp dupliziert werden muss.
struct MediaDetailView: View {
    let title: String
    /// z.B. der Artist-Name bei einem Album-Drill-down — der navigationTitle
    /// zeigt nur `title` prominent in der Fensterleiste, hier zusätzlich als
    /// eigene Kopfzeile über der Titelliste sichtbar.
    var subtitle: String?
    let loadTracks: () async throws -> [Track]

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
            if let subtitle {
                header(subtitle: subtitle)
            }

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
                    List(tracks) { track in
                        TrackRowView(track: track)
                    }
                }
            }
        }
        .navigationTitle(title)
        .task {
            await load()
        }
    }

    private func header(subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func load() async {
        loadState = .loading
        do {
            tracks = try await loadTracks()
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }
}
