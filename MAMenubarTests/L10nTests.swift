import Foundation
import Testing
@testable import MAMenubarLib

@Suite("L10n")
struct L10nTests {
    @Test(
        "AppLanguage.resolved löst .system anhand der bevorzugten Sprachen auf",
        arguments: [
            (["de-DE", "en-US"], L10n.Language.de),
            (["fr-FR", "en-GB", "de-DE"], L10n.Language.en),
            (["fr-FR", "es-ES"], L10n.Language.en),
            ([], L10n.Language.en),
        ] as [([String], L10n.Language)]
    )
    func resolvesSystemLanguage(preferredLanguages: [String], expected: L10n.Language) {
        #expect(AppLanguage.system.resolved(preferredLanguages: preferredLanguages) == expected)
    }

    @Test("de/en ignorieren preferredLanguages und lösen immer zu sich selbst auf")
    func explicitLanguagesIgnorePreferences() {
        #expect(AppLanguage.de.resolved(preferredLanguages: ["en-US"]) == .de)
        #expect(AppLanguage.en.resolved(preferredLanguages: ["de-DE"]) == .en)
    }

    @Test("jeder Key hat einen Tabelleneintrag")
    func tableIsComplete() {
        for key in L10n.Key.allCases {
            #expect(L10n.table[key] != nil, "fehlender Eintrag für \(key)")
        }
    }

    @Test("jeder Tabelleneintrag hat nicht-leere de/en-Werte")
    func tableEntriesAreNonEmpty() {
        for (key, entry) in L10n.table {
            #expect(!entry.de.isEmpty, "leerer de-Wert für \(key)")
            #expect(!entry.en.isEmpty, "leerer en-Wert für \(key)")
        }
    }
}
