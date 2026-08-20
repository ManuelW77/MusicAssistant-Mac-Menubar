import Foundation

/// Navigationsziel im Suchfenster, das von außerhalb (Menüleisten-Popover)
/// gesetzt werden kann — `AppState.pendingSearchDestination` transportiert
/// den Wunsch fensterübergreifend, SearchView pusht ihn dann auf seinen
/// eigenen NavigationPath (siehe SearchView.swift).
public enum SearchDestination: Hashable, Sendable {
    case artist(itemId: String, provider: String, name: String)
    case album(itemId: String, provider: String, name: String)
}
