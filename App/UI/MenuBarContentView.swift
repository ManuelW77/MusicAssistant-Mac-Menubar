import SwiftUI
import MAMenubarLib

/// Signalisiert MenuBarContentView, dass das Popover gerade (wieder) geöffnet
/// wird — AppDelegate erzeugt den NSHostingController nur einmal für die
/// gesamte App-Laufzeit und blendet das Popover beim Schließen nur aus statt
/// es neu aufzubauen, wodurch `@State` in MenuBarContentView dauerhaft
/// bestehen bleibt (`.onDisappear` feuert dabei nicht zuverlässig, da die
/// zugrundeliegende View nie wirklich verschwindet). Der Zähler statt eines
/// simplen Bool, damit auch ein erneutes "Öffnen" bei bereits `false`
/// zuverlässig eine `onChange`-Reaktion auslöst.
@MainActor
@Observable
final class PopoverNavigationState {
    private(set) var openCount = 0
    /// Von AppDelegate gesetzt (schließt das Popover) — MenuBarContentView
    /// ruft das vor jedem openWindow(id: "search") auf, damit das Suchfenster
    /// nicht hinter dem noch offenen Popover aufgeht.
    var onRequestClose: (() -> Void)?

    func notifyWillOpen() {
        openCount += 1
    }

    func requestClose() {
        onRequestClose?()
    }
}

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(PopoverNavigationState.self) private var popoverNavigationState
    @State private var showAddToPlaylist = false

    private var resolvedImageURL: URL? {
        guard let raw = appState.selectedPlayer?.currentMedia?.imageUrl,
              let serverBaseURL = appState.settings.serverBaseURL else { return nil }
        return MassEndpoint.resolveImageURL(raw, serverBaseURL: serverBaseURL)
    }

    private var playbackProgress: Double? {
        if let interpolated = appState.displayedPlaybackProgress {
            return interpolated
        }
        guard let media = appState.selectedPlayer?.currentMedia,
              let duration = media.duration, duration > 0,
              let elapsed = media.elapsedTime else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }

    private static let coverSize: CGFloat = 160
    private static let progressBarInset: CGFloat = 8
    private static var progressBarWidth: CGFloat { coverSize - 2 * progressBarInset }
    private static let progressTrackExtraWidth: CGFloat = 10
    private static var progressTrackWidth: CGFloat { progressBarWidth + progressTrackExtraWidth }
    private static let contentWidth: CGFloat = 220

    // Bewusst ein Inhaltswechsel innerhalb DIESES Popovers statt eines
    // verschachtelten `.popover`: ein SwiftUI-Popover im AppKit-eigenen
    // NSPopover (siehe AppDelegate) ist auf dieser macOS-/SDK-Version nicht
    // stabil zu bekommen — es blieb bei Außenklicks offen, hängte
    // Gesture-Recognizer auf ("Stuck gesture recognizers", danach ignoriert
    // SwiftUI global alle weiteren Gesten) und stürzte beim erneuten Öffnen
    // über einen verwaisten Field-Editor ab. Ein eigenes Fenster wäre die
    // andere Option gewesen, ist als Menüleisten-UI aber zu sperrig — daher
    // dieser Weg: gleiche Breite, nur die Höhe des Popovers ändert sich.
    var body: some View {
        // Bewusst if/else (jeweils nur EINE Ansicht bestimmt die gemeldete
        // Größe): NSHostingController mit sizingOptions =
        // .preferredContentSize berechnet die Popover-Höhe aus der
        // "idealen" Größe des aktuell vorhandenen Inhalts — ein Versuch,
        // das per GeometryReader/PreferenceKey selbst zu messen, ist
        // gescheitert (GeometryReader liefert bei dieser Art
        // "Ideal-Größen"-Anfrage durchgehend 0, kein echter Layout-Durchlauf
        // mit konkret vorgeschlagener Größe).
        //
        // Damit das Popover beim Wechsel zur Playlist-Ansicht NICHT
        // schrumpft, sondern die Höhe der Player-Ansicht behält: im
        // showAddToPlaylist-Zweig bestimmt ein UNSICHTBARER playerContent
        // (`.hidden()`) weiterhin die gemeldete Größe (das funktioniert
        // zuverlässig, da es exakt der normale, unveränderte Player-Zweig
        // ist) — AddToPlaylistView liegt sichtbar als `.overlay()` obendrauf,
        // was die gemeldete Größe der Basis nicht verändert. Kein
        // Rätselraten über eine passende feste Pixelzahl nötig.
        //
        // Das durch den View-Identitätsverlust beim Wechsel zurückkehrende
        // Cover-Neuladen wird über einen Bild-Cache gelöst (siehe
        // CachedCoverImage unten), der das Cover synchron beim Erscheinen
        // wieder anzeigt, ganz ohne Platzhalter-Flackern.
        Group {
            if showAddToPlaylist {
                playerContent
                    .hidden()
                    .overlay(alignment: .top) {
                        AddToPlaylistView { showAddToPlaylist = false }
                            .frame(width: Self.contentWidth)
                            .transition(.move(edge: .trailing))
                    }
            } else {
                playerContent
                    .transition(.move(edge: .leading))
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: showAddToPlaylist)
        .onChange(of: popoverNavigationState.openCount) { _, _ in
            showAddToPlaylist = false
        }
    }

    private var playerContent: some View {
        @Bindable var appState = appState

        return VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                    CachedCoverImage(url: resolvedImageURL)
                }

                if let playbackProgress {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: Self.progressTrackWidth, height: 8)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, Self.progressBarWidth * playbackProgress - 4), height: 4)
                            .padding(.leading, 2)
                    }
                    .padding(.bottom, 6)
                }
            }
            .frame(width: Self.coverSize, height: Self.coverSize)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(appState.selectedPlayer?.currentMedia?.title ?? appState.t(.noPlayback))
                        .font(.headline)
                        .lineLimit(1)
                    if appState.selectedPlayer?.currentMedia != nil {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { openCurrentTrackAlbum() }

                HStack(spacing: 4) {
                    Text(appState.selectedPlayer?.currentMedia?.artist ?? " ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if appState.selectedPlayer?.currentMedia != nil {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { openCurrentTrackArtist() }
            }

            HStack(spacing: 4) {
                FavoriteButtonView()

                CrossfadeButtonView()

                RadioButtonView()

                ShuffleButtonView()

                Button {
                    showAddToPlaylist = true
                } label: {
                    Label(appState.t(.addToPlaylist), systemImage: "text.badge.plus")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .help(appState.t(.addToPlaylist))
                .disabled(appState.selectedPlayer?.currentMedia == nil)

                Button {
                    popoverNavigationState.requestClose()
                    openWindow(id: "search")
                } label: {
                    Label(appState.t(.search), systemImage: "magnifyingglass")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .help(appState.t(.search))
            }

            PlayerControlsView(
                playbackState: appState.selectedPlayer?.playbackState,
                isPlayPauseCommandPending: appState.isPlayPauseCommandPending,
                onPrevious: appState.previous,
                onPlayPause: appState.playPause,
                onNext: appState.next
            )

            GroupVolumeView()

            PlayerPickerView(players: appState.availablePlayers, selectedPlayerID: $appState.selectedPlayerID)

            ConnectionStatusView(status: appState.connectionStatus)
        }
        .padding(16)
        .frame(width: Self.contentWidth)
    }

    /// Klick auf den Titel des laufenden Songs: löst dessen Album auf
    /// (music/item_by_uri, da PlayerMedia.album nur ein Anzeigename ist,
    /// keine navigierbare Referenz) und öffnet das Suchfenster direkt dort.
    private func openCurrentTrackAlbum() {
        Task {
            guard let track = try? await appState.loadCurrentTrackDetail(), let albumRef = track.albumRef else {
                return
            }
            appState.pendingSearchDestination = .album(
                itemId: albumRef.itemId, provider: albumRef.provider, name: albumRef.name, uri: albumRef.uri,
                artistName: track.artistNames.isEmpty ? nil : track.artistNames,
                artistRef: track.primaryArtistRef
            )
            popoverNavigationState.requestClose()
            openWindow(id: "search")
        }
    }

    /// Klick auf den Interpreten des laufenden Songs: analog zu
    /// openCurrentTrackAlbum(), navigiert aber zur Artist-Übersicht
    /// (Top-Titel/Titel/Alben).
    private func openCurrentTrackArtist() {
        Task {
            guard let track = try? await appState.loadCurrentTrackDetail(), let artistRef = track.primaryArtistRef else {
                return
            }
            appState.pendingSearchDestination = .artist(
                itemId: artistRef.itemId, provider: artistRef.provider, name: artistRef.name, uri: artistRef.uri
            )
            popoverNavigationState.requestClose()
            openWindow(id: "search")
        }
    }
}

/// Prozessweiter In-Memory-Cache für bereits geladene Cover — vermeidet ein
/// Platzhalter-Flackern von `CachedCoverImage`, wenn `playerContent` beim
/// Wechsel zwischen Player- und Playlist-Ansicht seine View-Identität
/// verliert (einfaches if/else, siehe MenuBarContentView.body) und dadurch
/// bei jedem Wechsel neu instanziiert wird.
@MainActor
private final class CoverImageCache {
    static let shared = CoverImageCache()
    private let cache = NSCache<NSURL, NSImage>()
    private init() {}

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// Ersatz für `AsyncImage`: prüft den Cache bereits synchron in `init`
/// (`@State`-Startwert), damit ein wiederholt neu instanziiertes Cover ohne
/// Zwischenzustand direkt mit Bild erscheint statt kurz den Platzhalter zu
/// zeigen. Fehlt der Cache-Eintrag (erster Aufruf für diese URL), wird ganz
/// normal asynchron nachgeladen wie zuvor mit `AsyncImage`.
private struct CachedCoverImage: View {
    let url: URL?
    @State private var image: NSImage?

    init(url: URL?) {
        self.url = url
        _image = State(initialValue: url.flatMap { CoverImageCache.shared.image(for: $0) })
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            // Kein "image == nil"-Guard mehr: Diese View-Instanz bleibt beim
            // Wechsel eines Songs UNVERÄNDERT bestehen (playerContent wird
            // nicht neu gebaut, solange das Popover offen bleibt) — nur die
            // `url` ändert sich, wodurch `.task(id:)` neu anläuft. Ein Guard
            // auf das ALTE `image` hätte den Task dann sofort wieder
            // verlassen, bevor er das NEUE Cover überhaupt nachlädt — genau
            // das ließ das Cover auf dem zuletzt geladenen Titel hängen, bis
            // die View durch einen kompletten Neuaufbau (Popover schließen
            // + neu öffnen) ihre Identität verlor und `init` erneut griff.
            guard let url else {
                image = nil
                return
            }
            if let cached = CoverImageCache.shared.image(for: url) {
                image = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let loaded = NSImage(data: data) else { return }
                CoverImageCache.shared.store(loaded, for: url)
                image = loaded
            } catch {
                // Platzhalter bleibt sichtbar, kein Fehlerzustand nötig —
                // gleiches Verhalten wie AsyncImage ohne .failure-Handling.
            }
        }
    }
}
