import Foundation

/// Persistierbare Sprachwahl des Nutzers. `.system` wird nie direkt zur
/// Textauflösung verwendet, sondern über `resolved(preferredLanguages:)` in
/// eine konkrete `L10n.Language` übersetzt.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case de
    case en
}

public extension AppLanguage {
    /// `preferredLanguages` ist injizierbar (Default `Locale.preferredLanguages`),
    /// damit die Fallback-Logik ohne System-Locale-Mocking testbar ist.
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> L10n.Language {
        switch self {
        case .de: return .de
        case .en: return .en
        case .system:
            for preference in preferredLanguages {
                switch Locale(identifier: preference).language.languageCode?.identifier {
                case "de": return .de
                case "en": return .en
                default: continue
                }
            }
            return .en
        }
    }
}
