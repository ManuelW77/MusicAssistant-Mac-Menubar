# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native macOS menu bar client for [Music Assistant](https://www.music-assistant.io/) (MA): a status-bar icon shows cover art and transport controls (play/pause, next/previous, volume) for one selected MA player, plus a settings window for server URL, access token, and a player whitelist.

## Commands

```
make build   # swift build (debug)
make test    # swift test
make run     # debug build, codesigned, launches the raw binary directly
make app     # release build into a real dist/"MA Menubar.app" bundle
make verify URL=<server-base-url> TOKEN=<token>   # protocol-verification CLI against a real server
```

For day-to-day development, open the package in Xcode instead of building via CLI — `open Package.swift`, then select the **`MAMenubar`** scheme (not `VerifyConnection` or `MAMenubarTests`) and Cmd+R. The local `swift build` toolchain (a development snapshot via `swiftly`) is much slower for SwiftUI code than Xcode's bundled toolchain, and has previously deadlocked when SwiftPM's manifest sandbox nested inside another sandboxing layer — if `swift build` ever hangs with near-zero CPU, retry with `swift build --disable-sandbox` rather than waiting.

`make run`/`make app` codesign with the local certificate `Apple Development: Manuel Weiser (469HR6FMTH)` (see `SIGN_IDENTITY` in the `Makefile`); override with `SIGN_IDENTITY=-` for ad-hoc signing on a machine without that certificate. Ad-hoc signatures change on every rebuild, which makes macOS re-prompt for Keychain access each time — the real certificate keeps the app identity stable across rebuilds.

There is deliberately no `.xcodeproj`. Xcode opens `Package.swift` directly. The `MAMenubar` executable target embeds `App/Info.plist` into the binary via linker flags (`-Xlinker -sectcreate __TEXT __info_plist ...` in `Package.swift`) so `LSUIElement` etc. take effect even without a real bundle when run directly; `make app` additionally wraps the release binary in a proper `Contents/MacOS` + `Contents/Info.plist` bundle for distribution.

## Architecture

**Module split**: `Shared/` is the `MAMenubarLib` library target (WebSocket client, models, settings/keychain storage, orchestration — all headless, unit-testable). `App/` is the `MAMenubar` executable (SwiftUI views + AppKit glue). `Tools/VerifyConnection/` is a separate CLI executable, also depending on `MAMenubarLib`. `MAMenubarTests/` tests only `MAMenubarLib`.

**Music Assistant protocol is not fully documented upstream** and several details here (WebSocket path `/ws`, `auth` handshake, exact `players/cmd/*` command names, partial/chunked list responses, player JSON field names) were derived from reading the MA server/client source and have only been partially verified against a real server. When touching `Shared/MassClient/` or `Shared/Models/MAPlayer.swift`, verify assumptions with `make verify URL=... TOKEN=...` against a real instance before trusting the shape of the data — don't assume the current field names/commands are authoritative.

**`MassWebSocketClient`** (`Shared/MassClient/MassWebSocketClient.swift`) is an `actor` wrapping `URLSessionWebSocketTask`. Requests use a `message_id`-keyed `CheckedContinuation` map (`pending`); a single `receiveLoop()` task demuxes incoming frames into either the events `AsyncStream` (frames with an `event` key) or a matching pending continuation (frames with a `message_id`). List-style responses (e.g. `players/all`) can arrive as multiple `"partial": true` chunks that must be accumulated before the continuation resolves — this logic lives in `handle(_:)`. `JSONValue` (`Shared/MassClient/JSONValue.swift`) is a generic JSON representation used to defer decoding into a concrete type until the caller's expected `Result` type is known.

**`AppState`** (`Shared/AppState.swift`) is the single `@MainActor @Observable` orchestrator: owns the current `MassWebSocketClient`, runs a supervised reconnect loop with backoff (`runSupervised()`), consumes the event stream to keep `players` in sync, and exposes the player commands (`playPause()`, `next()`, `previous()`, `setVolume(_:)`) the UI calls. `AppSettingsStore` (non-secret config: server URL, player whitelist, last-selected player — `UserDefaults`) and `KeychainTokenStore` (the access token — Keychain only, never `UserDefaults`) are separate, injected into `AppState`.

**Menu bar icon is managed manually via `NSStatusItem`** in `App/AppDelegate.swift`, not SwiftUI's `MenuBarExtra` — `MenuBarExtra` cannot distinguish left- from right-click. Left click toggles an `NSPopover` hosting `MenuBarContentView` (cover/controls/volume/player picker); right click shows an `NSMenu` with "Einstellungen…"/"Beenden". The status icon reactively reflects `AppState.connectionStatus` via `withObservationTracking` (there's no SwiftUI rendering here to bind against automatically). The app has no main window scene — only a `Settings` scene, opened from the AppDelegate via the classic `showSettingsWindow:` selector.

**Settings window focus quirk**: because the app is `LSUIElement` (accessory activation policy), a newly opened `Settings` window won't reliably become key/focused. The fix (see `AppDelegate.openSettings()` and `SettingsView.onDisappear`) is to temporarily flip `NSApp.setActivationPolicy(.regular)` before opening the window and flip back to `.accessory` when it closes. Calling `NSApp.activate(ignoringOtherApps:)` directly without this policy dance previously failed with a Mach task-port error and no window appeared at all.

**Cover image URLs sometimes point at a private LAN address** (this MA server's `webserver.base_url` is misconfigured internally) instead of the public reverse-proxied host, which macOS's Local Network Privacy then blocks outright. `MassEndpoint.resolveImageURL` (`Shared/MassClient/MassEndpoint.swift`) detects private/link-local hosts and rewrites them to the configured public server base URL while leaving genuinely external URLs (provider CDNs) untouched — don't "simplify" this back to a plain relative/absolute check.

**UI uses Liquid Glass** (`.glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`) on the custom-drawn elements (cover placeholder, transport buttons, connection status badge, primary settings buttons); standard controls (`Form`, `TabView`, `Slider`, `Toggle`) pick up the look automatically from the SDK and aren't explicitly styled.
