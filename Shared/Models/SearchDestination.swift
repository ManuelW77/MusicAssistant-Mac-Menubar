import Foundation

/// Navigationsziel im Suchfenster, das von außerhalb (Menüleisten-Popover)
/// gesetzt werden kann — `AppState.pendingSearchDestination` transportiert
/// den Wunsch fensterübergreifend, SearchView pusht ihn dann auf seinen
/// eigenen NavigationPath (siehe SearchView.swift).
public enum SearchDestination: Hashable, Sendable {
    /// uri: für den Play-Button in ArtistDetailView (appState.play(uri:)).
    case artist(itemId: String, provider: String, name: String, uri: String?)
    /// uri: für den Play-Button in AlbumDetailView. artistName: ggf.
    /// zusammengesetzter Anzeigename (mehrere Interpreten) für die
    /// Kopfzeile. artistRef: nur der erste Interpret, navigierbar (Klick auf
    /// die Kopfzeile → Artist-Übersicht) — nil, wenn unbekannt.
    case album(itemId: String, provider: String, name: String, uri: String?, artistName: String?, artistRef: MediaItemRef?)
}
