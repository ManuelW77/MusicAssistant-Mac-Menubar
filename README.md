# MusicAssistant-Mac-Menubar

Kleines natives macOS-Menüleisten-Tool für [Music Assistant](https://www.music-assistant.io/) (MA). Zeigt Cover, Titel/Künstler des aktuell laufenden Players und erlaubt Play/Pause sowie Vor-/Zurückspringen direkt aus der Menüleiste, ohne die volle MA-Web-UI oder Companion-App öffnen zu müssen.

## Funktionen

- Icon in der Menüleiste, Klick öffnet ein Popover mit Cover, Titel/Künstler und Transport-Controls (⏮ ⏯ ⏭).
- Steuerung eines aktiven Players, wechselbar über einen Picker im Popover.
- Settings-Dialog (⌘,) zum Einstellen von Server-URL, Access-Token und einer Whitelist, welche MA-Player überhaupt zur Auswahl stehen sollen.
- Automatischer Reconnect mit Backoff, Live-Updates über die MA-WebSocket-Events (kein Polling).
- Reine Menüleisten-App ohne Dock-Icon (`LSUIElement`).

## Voraussetzungen

- macOS 15+
- Xcode 16+ bzw. ein Swift-6-Toolchain
- Ein laufender Music-Assistant-Server sowie ein Long-Lived Access Token (MA-Web-UI → Profil → Access Tokens)

## Projektstruktur

```
Shared/            SPM-Library "MAMenubarLib": WebSocket-Client, Datenmodelle,
                    Settings-/Keychain-Speicher, AppState-Orchestrator
App/                SwiftUI-App (MenuBarExtra-Popover + Settings-Dialog)
Tools/VerifyConnection/  CLI zur Protokollverifikation gegen einen echten Server
MAMenubarTests/     Unit-Tests für Shared/
```

Es gibt bewusst kein `.xcodeproj` — das Projekt ist ein reines Swift Package. Xcode kann `Package.swift` direkt öffnen und daraus bauen/debuggen.

## Bauen & Starten

### Mit Xcode (empfohlen für Entwicklung)

```
open Package.swift
```

Im Schema-Dropdown **„MAMenubar"** auswählen (nicht `VerifyConnection` oder `MAMenubarTests`) und ⌘R. Da `LSUIElement = YES` gesetzt ist, öffnet sich kein Fenster — die App erscheint nur als Icon in der Menüleiste.

### Mit der Kommandozeile

```
make build   # swift build (Debug)
make test    # swift test
make run     # Debug-Build, ad-hoc/zertifikatssigniert, direkt starten
```

### Fertiges `.app`-Bundle bauen

```
make app
```

Baut Release-optimiert und erzeugt ein doppelklickbares Bundle unter `dist/MA Menubar.app`, das sich z.B. nach `/Applications` verschieben lässt:

```
mv "dist/MA Menubar.app" /Applications/
```

`run` und `app` signieren standardmäßig mit dem lokalen Zertifikat `Apple Development: Manuel Weiser (469HR6FMTH)` aus der Keychain (siehe `SIGN_IDENTITY` im `Makefile`). Auf einem Rechner ohne dieses Zertifikat mit `make app SIGN_IDENTITY=-` auf Ad-hoc-Signatur zurückfallen.

## Konfiguration

Beim ersten Start über „Einstellungen…" im Popover (bzw. ⌘,):

1. **Tab „Server"**: Server-Basis-URL (z.B. `https://music.example.org`) und Access-Token eintragen, mit „Verbindung testen" prüfen, dann „Speichern".
2. **Tab „Player"**: Aus den vom Server gemeldeten Playern die gewünschten für den Popover-Picker aktivieren.

Der Access-Token wird ausschließlich in der macOS-Keychain gespeichert (Service `org.fire-devils.MAMenubar`), nie im Klartext. Server-URL und Player-Whitelist liegen in `UserDefaults`.

## Protokollverifikation gegen einen echten Server

Die Music-Assistant-WebSocket-API ist nicht vollständig dokumentiert; `Tools/VerifyConnection` prüft Connect/Auth/Player-Liste gegen einen echten Server, ohne die UI zu bauen:

```
make verify URL=https://music.example.org TOKEN=<dein-token>
```

## Tests

```
make test
```

Deckt u.a. das JSON-Decoding (inkl. Partial-Response-Handling der MA-API), die Bild-URL-Auflösung (`MassEndpoint`, inkl. Umschreiben privater LAN-Adressen auf die öffentliche Server-URL) sowie Settings-/Keychain-Roundtrips ab.
