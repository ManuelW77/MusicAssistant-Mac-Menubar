# Privacy Policy — MA Menubar

🇩🇪 [Deutsch](PRIVACY.de.md)

_Last updated: August 16, 2026_

## Overview

MA Menubar is a macOS menu bar client for your own [Music Assistant](https://www.music-assistant.io/) server. In short: **the app does not collect, transmit, or sell any personal data to the developer.** Everything you configure stays on your Mac, and the only network connections the app makes are (1) to the Music Assistant server *you* specify, and (2) an anonymous check against GitHub's public API for available updates.

## Data controller

Manuel Weiser
Email: manuel.weiser@me.com
GitHub: https://github.com/ManuelW77/MusicAssistant-Mac-Menubar

## What data the app processes

### Data you enter — stored only on your device

- Server URL
- Access token (Long-Lived Access Token) for your Music Assistant server
- Your selected/whitelisted players
- Language preference

This data is stored locally on your Mac via `UserDefaults` and is never transmitted to the developer or to any third party — with the sole exception of your own Music Assistant server, which needs the URL and token to authenticate you (see below). Note: for technical reasons (avoiding an intrusive macOS Keychain permission prompt on first launch), this data — including the access token — is stored **unencrypted**. Anyone with access to your Mac user account could read it from `UserDefaults`.

### Connection to your Music Assistant server

The app opens a WebSocket connection to the server URL you configure and authenticates with the access token you provide, in order to display cover art/track info and send playback commands (play/pause, skip, volume, playlists, search, etc.). This server is operated by you (or a third party of your choosing) — it is not operated by, and not accessible to, the developer. Any data handled by that server is governed by however that server is configured, not by this policy.

### Update checks

On launch, roughly every 24 hours, and whenever you click "Check for Updates" in Settings, the app sends an unauthenticated `GET` request to GitHub's public Releases API (`api.github.com`) to look up the latest available version number. No account information, device identifiers, or usage data are included beyond what any plain HTTP request inherently carries (e.g. your IP address, which is handled by GitHub's infrastructure, not the developer). See [GitHub's Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement) for how GitHub itself handles that.

### What the app does NOT do

- No analytics, telemetry, or usage tracking
- No advertising, ad identifiers, or ad networks
- No account creation or sign-in with the developer
- No crash reporting or third-party SDKs — the app has zero external code dependencies (see `Package.swift`)
- No data of any kind is ever sent to the developer

## App Store "Privacy Nutrition Label"

Consistent with the above, this app collects no data and can be declared as **"Data Not Collected"** under Apple's App Privacy details.

## Local network access

macOS asks you to grant "Local Network" access the first time the app tries to reach a server on your local network. This permission is used exclusively to connect to the Music Assistant server you configured — for no other purpose.

## Children's privacy

The app is not directed at children and does not knowingly collect data from anyone, since it does not collect data from anyone at all.

## Your rights (GDPR / DSGVO)

Because the developer does not collect or process any personal data, there is generally nothing on the developer's side to access, correct, or delete. The data you enter (server URL, access token, player selection) exists only on your own device, under your own control — you can change or delete it at any time in the app's Settings, or by uninstalling the app. If you have further questions about your rights under the GDPR, contact the developer using the email above.

## Changes to this policy

This policy may be updated if the app's functionality changes in a way that affects data handling. The current version is always available at:
https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/blob/main/PRIVACY.md

## Contact

Manuel Weiser — manuel.weiser@me.com — https://github.com/ManuelW77/MusicAssistant-Mac-Menubar
