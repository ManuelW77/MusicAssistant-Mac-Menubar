import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Progress Interpolation")
struct ProgressInterpolationTests {

    @Test("erkennt Server-Versionen ab 2.10.0")
    func versionAtLeast2_10_0() {
        #expect(AppState.isVersionAtLeast2_10_0("2.10.0") == true)
        #expect(AppState.isVersionAtLeast2_10_0("2.10.0b3") == true)
        #expect(AppState.isVersionAtLeast2_10_0("2.11.0") == true)
        #expect(AppState.isVersionAtLeast2_10_0("3.0.0") == true)
        #expect(AppState.isVersionAtLeast2_10_0("3.0.0b1") == true)
    }

    @Test("erkennt Server-Versionen unter 2.10.0")
    func versionBelow2_10_0() {
        #expect(AppState.isVersionAtLeast2_10_0("2.9.0") == false)
        #expect(AppState.isVersionAtLeast2_10_0("2.9.9") == false)
        #expect(AppState.isVersionAtLeast2_10_0("2.0.0") == false)
        #expect(AppState.isVersionAtLeast2_10_0("1.0.0") == false)
    }

    @Test("ignoriert Suffixe und unvollständige Versionen")
    func versionParsingHandlesSuffixes() {
        #expect(AppState.isVersionAtLeast2_10_0("2.10") == true)
        #expect(AppState.isVersionAtLeast2_10_0("2.9rc1") == false)
        #expect(AppState.isVersionAtLeast2_10_0("2.10.0-123-gabcdef") == true)
    }

    @Test("interpoliert bei laufender Wiedergabe")
    func interpolatesWhilePlaying() {
        let elapsed: Double = 30
        let lastUpdated: Double = 1_000
        let duration: Double = 120
        let now: Double = 1_005

        let progress = AppState.interpolatedProgress(
            elapsedTime: elapsed,
            elapsedTimeLastUpdated: lastUpdated,
            duration: duration,
            isPlaying: true,
            now: now
        )

        // 30 s + 5 s = 35 s / 120 s ≈ 0.2917
        #expect(progress == 35.0 / 120.0)
    }

    @Test("interpoliert nicht bei Pause")
    func doesNotInterpolateWhilePaused() {
        let progress = AppState.interpolatedProgress(
            elapsedTime: 30,
            elapsedTimeLastUpdated: 1_000,
            duration: 120,
            isPlaying: false,
            now: 1_500
        )

        #expect(progress == 30.0 / 120.0)
    }

    @Test("klemmt Fortschritt auf 0…1 ein")
    func clampsProgress() {
        let overflow = AppState.interpolatedProgress(
            elapsedTime: 130,
            elapsedTimeLastUpdated: 1_000,
            duration: 120,
            isPlaying: true,
            now: 1_000
        )
        #expect(overflow == 1.0)

        let negative = AppState.interpolatedProgress(
            elapsedTime: -10,
            elapsedTimeLastUpdated: 1_000,
            duration: 120,
            isPlaying: true,
            now: 1_000
        )
        #expect(negative == 0.0)
    }
}
