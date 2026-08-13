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

        // Kein appState-Zugriff in diesem View-lokalen Typ, daher Sprache als
        // Parameter statt appState.t(...). "Playlists" ist DE/EN identisch
        // und bleibt bewusst literal (siehe Migrationsplan).
        func label(_ language: L10n.Language) -> String {
            switch self {
            case .track: return L10n.text(.mediaTypeTrack, language)
            case .album: return L10n.text(.mediaTypeAlbum, language)
            case .playlist: return "Playlists"
            case .artist: return L10n.text(.mediaTypeArtist, language)
            }
        }
    }

    var body: some View {
        TabView {
            searchTab
                .tabItem { Label(appState.t(.search), systemImage: "magnifyingglass") }

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
                            appState.t(.noCategorySelected),
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text(appState.t(.selectAtLeastOneCategory))
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
                                appState.t(.searchFailed),
                                systemImage: "xmark.circle",
                                description: Text(message)
                            )
                        case .loaded:
                            searchResultsList
                        }
                    }
                }
            }
            .navigationTitle(appState.t(.search))
            .searchable(text: $query, prompt: appState.t(.searchPrompt))
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
                    Button(type.label(appState.uiLanguage)) { toggleType(type) }
                        .buttonStyle(.glassProminent)
                } else {
                    Button(type.label(appState.uiLanguage)) { toggleType(type) }
                        .buttonStyle(.glass)
                }
            }

            Picker(appState.t(.source), selection: $selectedProviderDomain) {
                Text(appState.t(.allSources)).tag(nil as String?)
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
                    Section(appState.t(.mediaTypeArtist)) {
                        ForEach(results.artists) { ArtistRowView(artist: $0) }
                    }
                }
                if !results.albums.isEmpty {
                    Section(appState.t(.mediaTypeAlbum)) {
                        ForEach(results.albums) { AlbumRowView(album: $0) }
                    }
                }
                if !results.playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(results.playlists) { PlaylistRowView(playlist: $0) }
                    }
                }
                if !results.tracks.isEmpty {
                    Section(appState.t(.mediaTypeTrack)) {
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
                        appState.t(.noPlaylistsFound),
                        systemImage: "music.note.list"
                    )
                } else {
                    List {
                        if !favoritePlaylists.isEmpty {
                            Section {
                                ForEach(favoritePlaylists) { PlaylistRowView(playlist: $0) }
                            } header: {
                                Text(appState.t(.favoritePlaylists))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        if !otherPlaylists.isEmpty {
                            Section(appState.t(.allPlaylists)) {
                                ForEach(otherPlaylists) { PlaylistRowView(playlist: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .task {
                try? await appState.loadPlaylists()
            }
        }
    }

    private var favoritePlaylists: [Playlist] {
        appState.playlists.filter(\.favorite)
    }

    private var otherPlaylists: [Playlist] {
        appState.playlists.filter { !$0.favorite }
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
