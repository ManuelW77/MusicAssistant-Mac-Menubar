import Foundation

/// Navigationsziel im Suchfenster, das von außerhalb (Menüleisten-Popover)
/// gesetzt werden kann — `AppState.pendingSearchDestination` transportiert
/// den Wunsch fensterübergreifend, SearchView pusht ihn dann auf seinen
/// eigenen NavigationPath (siehe SearchView.swift).
public enum SearchDestination: Hashable, Sendable {
    /// uri: für den Play-Button in ArtistDetailView (appState.play(uri:)).
    case artist(itemId: String, provider: String, name: String, uri: String?)
    /// artistName: für die Kopfzeile in MediaDetailView (siehe subtitle dort).
    case album(itemId: String, provider: String, name: String, artistName: String?)
}
