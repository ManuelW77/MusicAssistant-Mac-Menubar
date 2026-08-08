import SwiftUI
import MAMenubarLib

struct SearchView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var results: SearchResultsInfo?
    @State private var loadState: LoadState = .idle
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedTypes: Set<MediaTypeFilter> = Set(MediaTypeFilter.allCases)
    @State private var selectedProviderDomain: String?

    private enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private enum MediaTypeFilter: String, CaseIterable, Identifiable {
        case track
        case album
        case playlist
        case artist

        var id: String { rawValue }

        var label: String {
            switch self {
            case .track: return "Titel"
            case .album: return "Alben"
            case .playlist: return "Playlists"
            case .artist: return "Interpreten"
            }
        }
    }

    var body: some View {
        TabView {
            searchTab
                .tabItem { Label("Suche", systemImage: "magnifyingglass") }

            playlistsTab
                .tabItem { Label("Playlists", systemImage: "music.note.list") }
        }
        .frame(minWidth: 480, minHeight: 480)
        .onAppear { WindowActivation.windowDidAppear() }
        .onDisappear { WindowActivation.windowDidDisappear() }
    }

    private var searchTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterRow

                Group {
                    if selectedTypes.isEmpty {
                        ContentUnavailableView(
                            "Keine Kategorie ausgewählt",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Wähle mindestens eine Kategorie oben aus.")
                        )
                    } else {
                        switch loadState {
                        case .idle:
                            ContentUnavailableView.search
                        case .loading:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failed(let message):
                            ContentUnavailableView(
                                "Suche fehlgeschlagen",
                                systemImage: "xmark.circle",
                                description: Text(message)
                            )
                        case .loaded:
                            searchResultsList
                        }
                    }
                }
            }
            .navigationTitle("Suche")
            .searchable(text: $query, prompt: "Titel, Alben, Playlists, Interpreten…")
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .onChange(of: selectedTypes) {
                scheduleSearch(query)
            }
            .onChange(of: selectedProviderDomain) {
                scheduleSearch(query)
            }
            .task {
                try? await appState.loadMusicProviders()
            }
        }
    }

    private var filterRow: some View {
        HStack(spacing: 6) {
            Spacer()

            ForEach(MediaTypeFilter.allCases) { type in
                if selectedTypes.contains(type) {
                    Button(type.label) { toggleType(type) }
                        .buttonStyle(.glassProminent)
                } else {
                    Button(type.label) { toggleType(type) }
                        .buttonStyle(.glass)
                }
            }

            Picker("Quelle", selection: $selectedProviderDomain) {
                Text("Alle Quellen").tag(nil as String?)
                ForEach(appState.musicProviders) { provider in
                    Text(provider.name).tag(provider.domain as String?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Spacer()
        }
        .padding(8)
    }

    private func toggleType(_ type: MediaTypeFilter) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if let results, !results.tracks.isEmpty || !results.albums.isEmpty
            || !results.playlists.isEmpty || !results.artists.isEmpty {
            List {
                if !results.artists.isEmpty {
                    Section("Interpreten") {
                        ForEach(results.artists) { ArtistRowView(artist: $0) }
                    }
                }
                if !results.albums.isEmpty {
                    Section("Alben") {
                        ForEach(results.albums) { AlbumRowView(album: $0) }
                    }
                }
                if !results.playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(results.playlists) { PlaylistRowView(playlist: $0) }
                    }
                }
                if !results.tracks.isEmpty {
                    Section("Titel") {
                        ForEach(results.tracks) { TrackRowView(track: $0) }
                    }
                }
            }
        } else {
            ContentUnavailableView.search(text: query)
        }
    }

    private var playlistsTab: some View {
        NavigationStack {
            Group {
                if appState.playlists.isEmpty {
                    ContentUnavailableView(
                        "Keine Playlists gefunden",
                        systemImage: "music.note.list"
                    )
                } else {
                    List(appState.playlists) { PlaylistRowView(playlist: $0) }
                }
            }
            .navigationTitle("Playlists")
            .task {
                try? await appState.loadPlaylists()
            }
        }
    }

    private func scheduleSearch(_ newValue: String) {
        searchTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            loadState = .idle
            results = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) async {
        guard !selectedTypes.isEmpty else { return }
        loadState = .loading
        do {
            results = try await appState.search(
                query: query,
                mediaTypes: selectedTypes.map(\.rawValue),
                providers: selectedProviderDomain.map { [$0] }
            )
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }
}
