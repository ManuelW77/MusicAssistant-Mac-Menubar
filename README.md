# MusicAssistant-Mac-Menubar

Kleines natives macOS-Menüleisten-Tool für [Music Assistant](https://www.music-assistant.io/) (MA). Zeigt Cover, Titel/Künstler des aktuell laufenden Players und erlaubt Play/Pause sowie Vor-/Zurückspringen direkt aus der Menüleiste, ohne die volle MA-Web-UI oder Companion-App öffnen zu müssen.

## Funktionen

- Icon in der Menüleiste, Klick öffnet ein Popover mit Cover, Titel/Künstler und Transport-Controls (⏮ ⏯ ⏭).
- Steuerung eines aktiven Players, wechselbar über einen Picker im Popover.
- Rechtsklick auf das Icon öffnet ein Menü mit „Einstellungen…" und „Beenden".
- Settings-Dialog zum Einstellen von Server-URL, Access-Token, einer Whitelist der wählbaren MA-Player sowie „Bei Anmeldung starten".
- Automatischer Reconnect mit Backoff, Live-Updates über die MA-WebSocket-Events (kein Polling).
- Reine Menüleisten-App ohne Dock-Icon (`LSUIElement`).

## Voraussetzungen

- macOS 26+ (Liquid-Glass-UI)
- Xcode mit swift-tools-version 6.2+
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

## Signierte Releases (GitHub Actions)

Das Repo wird zusätzlich zu Gitea (`origin`) nach GitHub gespiegelt (`github`-Remote, https://github.com/ManuelW77/MusicAssistant-Mac-Menubar). Ein Push eines `vX.Y.Z`-Tags dorthin (oder ein manueller Trigger) löst `.github/workflows/release.yml` aus: baut per `make app`, signiert mit einem **Developer-ID-Application**-Zertifikat, notarisiert bei Apple (`notarytool`) und hängt ein gestapeltes Drag-in-Applications-`.dmg` (`make dmg`) an eine neue GitHub Release — Gatekeeper zeigt auf fremden Macs dann keine Warnung mehr.

Lokal lässt sich das `.dmg` nach einem `make app` auch separat erzeugen:

```
make dmg
```

Versionierung folgt [SemVer](https://semver.org/), beginnend bei `v1.0.0`. Bei einem Tag-Push übernimmt der Workflow den Tag automatisch als `CFBundleShortVersionString` (Tag ohne führendes `v`) und die GitHub-Actions-Run-Nummer als `CFBundleVersion` (Build-Nummer) — `App/Info.plist` muss dafür nicht manuell angepasst werden.

```
git tag v1.0.0
git push github v1.0.0
```

Dafür müssen einmalig folgende Repo-Secrets gesetzt werden (`gh secret set NAME --repo ManuelW77/MusicAssistant-Mac-Menubar -b"…"`, selbst ausführen — dafür wird das Zertifikat/die Credentials nirgendwo sonst eingegeben):

| Secret | Herkunft |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | Developer-ID-Application-Zertifikat + privater Schlüssel aus Keychain Access als `.p12` exportieren, dann `base64 -i certificate.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Passwort, das beim `.p12`-Export vergeben wurde |
| `KEYCHAIN_PASSWORD` | Beliebiges Passwort nur für die temporäre CI-Keychain, z.B. `openssl rand -base64 24` |
| `DEVELOPER_ID_IDENTITY` | Exakter Identity-String, z.B. `Developer ID Application: Manuel Weiser (TEAMID)` (siehe `security find-identity -v -p codesigning`) |
| `NOTARY_KEY_ID` / `NOTARY_ISSUER_ID` / `NOTARY_KEY_P8_BASE64` | App Store Connect → Users and Access → Integrations → App Store Connect API: Key erzeugen (Rolle „Developer" reicht), `.p8` einmalig herunterladen und `base64 -i AuthKey_XXXX.p8` |

## Konfiguration

Beim ersten Start über Rechtsklick auf das Menüleisten-Icon → „Einstellungen…":

1. **Tab „Allgemein"**: optional „Bei Anmeldung starten" aktivieren. Nutzt `SMAppService.mainApp` — funktioniert nur aus einem echten `.app`-Bundle (`make app`), nicht aus dem rohen Debug-Build (`make run`/Xcode-Run).
2. **Tab „Server"**: Server-Basis-URL (z.B. `https://music.example.org`) und Access-Token eintragen, mit „Verbindung testen" prüfen, dann „Speichern".
3. **Tab „Player"**: Aus den vom Server gemeldeten Playern die gewünschten für den Popover-Picker aktivieren.

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
