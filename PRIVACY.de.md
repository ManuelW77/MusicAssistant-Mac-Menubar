# Datenschutzerklärung — MA Menubar

🇬🇧 [English](PRIVACY.md)

_Stand: 16. August 2026_

## Überblick

MA Menubar ist ein macOS-Menüleisten-Client für deinen eigenen [Music Assistant](https://www.music-assistant.io/)-Server. Kurz gesagt: **Die App erhebt, überträgt oder verkauft keinerlei personenbezogene Daten an den Entwickler.** Alles, was du konfigurierst, verbleibt auf deinem Mac. Die einzigen Netzwerkverbindungen, die die App aufbaut, sind (1) die Verbindung zu dem Music-Assistant-Server, den *du* angibst, und (2) eine anonyme Abfrage bei der öffentlichen API von GitHub, um auf verfügbare Updates zu prüfen.

## Verantwortlicher

Manuel Weiser
E-Mail: manuel.weiser@me.com
GitHub: https://github.com/ManuelW77/MusicAssistant-Mac-Menubar

## Welche Daten die App verarbeitet

### Von dir eingegebene Daten — nur lokal auf deinem Gerät gespeichert

- Server-URL
- Zugriffstoken (Long-Lived Access Token) für deinen Music-Assistant-Server
- Deine ausgewählten/freigegebenen Player
- Spracheinstellung

Diese Daten werden lokal auf deinem Mac über `UserDefaults` gespeichert und niemals an den Entwickler oder Dritte übertragen — mit der einzigen Ausnahme deines eigenen Music-Assistant-Servers, der URL und Token zur Authentifizierung benötigt (siehe unten). Hinweis: Aus technischen Gründen (um den aufdringlichen macOS-Keychain-Berechtigungsdialog beim ersten Start zu vermeiden) werden diese Daten — einschließlich des Zugriffstokens — **unverschlüsselt** gespeichert. Jede Person mit Zugriff auf deinen Mac-Benutzeraccount könnte diese Daten aus `UserDefaults` auslesen.

### Verbindung zu deinem Music-Assistant-Server

Die App baut eine WebSocket-Verbindung zu der von dir konfigurierten Server-URL auf und authentifiziert sich mit dem von dir angegebenen Zugriffstoken, um Cover-Art/Titelinformationen anzuzeigen und Wiedergabebefehle zu senden (Play/Pause, Skip, Lautstärke, Playlists, Suche usw.). Dieser Server wird von dir (oder einem von dir gewählten Dritten) betrieben — er wird nicht vom Entwickler betrieben und ist für den Entwickler nicht zugänglich. Wie dieser Server mit den dort verarbeiteten Daten umgeht, richtet sich nach dessen eigener Konfiguration, nicht nach dieser Erklärung.

### Update-Prüfung

Beim Start, etwa alle 24 Stunden sowie beim Klick auf "Nach Updates suchen" in den Einstellungen sendet die App eine unauthentifizierte `GET`-Anfrage an die öffentliche Releases-API von GitHub (`api.github.com`), um die aktuell verfügbare Versionsnummer abzufragen. Dabei werden keine Konto-, Geräte- oder Nutzungsdaten übermittelt, abgesehen von dem, was jede HTTP-Anfrage grundsätzlich mit sich bringt (z. B. deine IP-Adresse, die von der Infrastruktur GitHubs verarbeitet wird, nicht vom Entwickler). Siehe dazu die [Datenschutzerklärung von GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

### Was die App NICHT tut

- Keine Analytics, Telemetrie oder Nutzungsverfolgung
- Keine Werbung, Werbe-IDs oder Werbenetzwerke
- Keine Kontoerstellung oder Anmeldung beim Entwickler
- Kein Crash-Reporting und keine Drittanbieter-SDKs — die App hat keinerlei externe Code-Abhängigkeiten (siehe `Package.swift`)
- Es werden zu keinem Zeitpunkt Daten an den Entwickler übertragen

## App-Store-"Datenschutz-Kennzeichnung" (Privacy Nutrition Label)

Entsprechend dem oben Beschriebenen erhebt diese App keinerlei Daten und kann in Apples App-Privacy-Angaben als **"Keine Daten erfasst"** deklariert werden.

## Zugriff auf das lokale Netzwerk

macOS fragt beim ersten Verbindungsversuch zu einem Server im lokalen Netzwerk nach der Berechtigung "Lokales Netzwerk". Diese Berechtigung wird ausschließlich zur Verbindung mit dem von dir konfigurierten Music-Assistant-Server genutzt — für keinen anderen Zweck.

## Datenschutz von Kindern

Die App richtet sich nicht an Kinder und erhebt wissentlich keine Daten von irgendjemandem, da sie generell von niemandem Daten erhebt.

## Deine Rechte (DSGVO)

Da der Entwickler keinerlei personenbezogene Daten erhebt oder verarbeitet, gibt es auf Seiten des Entwicklers grundsätzlich nichts einzusehen, zu berichtigen oder zu löschen. Die von dir eingegebenen Daten (Server-URL, Zugriffstoken, Player-Auswahl) existieren ausschließlich auf deinem eigenen Gerät unter deiner eigenen Kontrolle — du kannst sie jederzeit in den Einstellungen der App ändern oder löschen, oder durch Deinstallation der App entfernen. Bei weiteren Fragen zu deinen Rechten nach der DSGVO kannst du den Entwickler über die oben genannte E-Mail-Adresse kontaktieren.

## Änderungen dieser Erklärung

Diese Erklärung kann aktualisiert werden, falls sich der Funktionsumfang der App in einer Weise ändert, die die Datenverarbeitung betrifft. Die jeweils aktuelle Fassung ist immer verfügbar unter:
https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/blob/main/PRIVACY.de.md

## Kontakt

Manuel Weiser — manuel.weiser@me.com — https://github.com/ManuelW77/MusicAssistant-Mac-Menubar
