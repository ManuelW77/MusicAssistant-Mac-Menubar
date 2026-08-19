#!/usr/bin/env bash
# Release-Script: nur vom main-Branch aus lauffähig (main = reiner
# Release-Spiegel, devel bleibt der Arbeits-Branch). Ermittelt die nächste
# SemVer-Version, pusht main nach origin (Gitea) + github, und pusht den
# neuen vX.Y.Z-Tag nach github — das löst dort den Sign & Notarize-Workflow
# aus (.github/workflows/release.yml).
#
# Verwendung:
#   ./scripts/release.sh            # zeigt die aktuelle Version, fragt dann
#                                    # interaktiv nach major/minor/patch
#                                    # (Standard bei leerer Eingabe: patch)
#   ./scripts/release.sh minor      # Minor-Bump (keine Rückfrage)
#   ./scripts/release.sh major      # Major-Bump (keine Rückfrage)
#   ./scripts/release.sh v2.3.0     # explizite Version (keine Rückfrage)
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
    echo "Fehler: Release nur vom main-Branch aus. Aktuell auf '$BRANCH'." >&2
    echo "Erst 'git checkout main && git merge devel', dann erneut versuchen." >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Fehler: Working Tree ist nicht sauber. Erst committen oder stashen." >&2
    exit 1
fi

# github/main kann durch den Release-Workflow einen automatischen
# Cask-Formel-Commit erhalten haben (.github/workflows/release.yml), der nie
# zurück nach origin (Gitea) bzw. in die lokale main-Historie fließt (der
# Workflow läuft nur auf GitHub Actions, ohne Gitea-Zugang). Ohne Sync würde
# der spätere `git push github main` als Non-Fast-Forward fehlschlagen.
git fetch github main --quiet
if ! git merge-base --is-ancestor github/main main; then
    echo "main liegt hinter github/main zurück (vermutlich automatischer Cask-Formel-Commit) – synchronisiere..."
    git merge github/main --no-edit
fi

LATEST_TAG=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n1)
LATEST_TAG="${LATEST_TAG:-v0.0.0}"
LATEST_VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_VERSION"

BUMP="${1:-}"

# Nur nachfragen, wenn das Script ganz ohne Argument aufgerufen wurde (der
# übliche interaktive `make release`-Fall) — bei explizit übergebenem Bump-Typ
# oder Version (z.B. aus einem Skript/CI) ist die Entscheidung schon getroffen,
# da nicht erneut nachfragen.
if [ -z "$BUMP" ]; then
    echo "Aktuelle Version: $LATEST_TAG"
    read -r -p "Version erhöhen um [major/minor/patch] (Standard: patch): " BUMP
    BUMP="${BUMP:-patch}"
fi

case "$BUMP" in
    major)
        MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
        NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    minor)
        MINOR=$((MINOR + 1)); PATCH=0
        NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    patch)
        PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    *)
        # Striktes, verankertes Regex-Match statt eines Glob-Patterns: ein
        # Glob wie v[0-9]*.[0-9]*.[0-9]* matcht wegen der ungebremsten `*`
        # so gut wie jeden String mit zwei Punkten, nicht nur echte
        # Versionsnummern. BASH_REMATCH stellt sicher, dass NEW_VERSION
        # ausschließlich aus den gematchten Ziffern besteht.
        if [[ "$BUMP" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            NEW_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        else
            echo "Fehler: Unbekanntes Argument '$BUMP' (erwartet: major | minor | patch | vX.Y.Z)" >&2
            exit 1
        fi
        ;;
esac

NEW_TAG="v${NEW_VERSION}"

if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "Fehler: Tag $NEW_TAG existiert bereits." >&2
    exit 1
fi

echo "Aktuelle Version: $LATEST_TAG"
echo "Neue Version:     $NEW_TAG"
read -r -p "main + Tag $NEW_TAG nach origin (Gitea) und github pushen? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Abgebrochen."
    exit 1
fi

git push origin main
git push github main

CHANGELOG=$(git log "${LATEST_TAG}..HEAD" --no-merges --pretty=format:'- %s')
git tag -a "$NEW_TAG" -m "$NEW_TAG" -m "$CHANGELOG"
git push origin "$NEW_TAG"
git push github "$NEW_TAG"

echo ""
echo "Fertig. $NEW_TAG gepusht — Build/Sign/Notarize läuft:"
echo "  https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/actions"

# --- Xcode-Projekt-Version mitziehen (best-effort, bricht das Release nicht ab) ---
# Das separate Xcode-Projekt in ../MA-Mac-Menubar-xCode (eigenes Git-Repo,
# bindet denselben Sourcecode per relativem Pfad ein, siehe dessen
# project.pbxproj) pflegt seine eigene MARKETING_VERSION/CURRENT_PROJECT_VERSION
# unabhängig von den Git-Tags hier. Wir identifizieren die Build-Configs des
# App-Targets über ihre IDs aus der "Build configuration list"-Sektion, statt
# naiv jede MARKETING_VERSION-Zeile zu ersetzen — das Projekt enthält 2
# weitere Targets (MAMenubarLib, MAMenubarLibTests), deren Versionsfelder
# unangetastet bleiben müssen. Die Version wird IMMER gesetzt, unabhängig vom
# sonstigen Git-Status des Xcode-Repos (die Version muss stets zum
# tatsächlichen Release-Build passen) — anschließend wird gezielt nur die
# pbxproj-Datei committet und gepusht, andere ggf. offene Änderungen in
# diesem Repo bleiben davon unberührt und uncommitted.
sync_xcode_project_version() {
    local xcode_dir="../MA-Mac-Menubar-xCode"
    local target_name="Music Assistant Menubar"
    local pbxproj="$xcode_dir/$target_name.xcodeproj/project.pbxproj"

    if [ ! -f "$pbxproj" ]; then
        echo "Warnung: Xcode-Projekt nicht gefunden unter '$pbxproj' – Versions-Sync übersprungen." >&2
        return
    fi

    local config_list_line debug_id release_id
    # Der Name kommt zweimal vor: einmal als reine Referenz
    # ("buildConfigurationList = ID /* ... */;", z.B. am PBXNativeTarget
    # selbst) und einmal als die eigentliche Block-Definition ("ID /* ... */
    # = {"). Nur Letztere enthält die Debug/Release-IDs, daher gezielt auf
    # "= {" am Zeilenende matchen statt nur auf den Namen.
    config_list_line=$(grep -n "Build configuration list for PBXNativeTarget \"$target_name\" \\*/ = {" "$pbxproj" | head -n1 | cut -d: -f1)
    if [ -z "$config_list_line" ]; then
        echo "Warnung: Build-Configuration-Liste für Target '$target_name' nicht gefunden – Versions-Sync übersprungen." >&2
        return
    fi
    debug_id=$(sed -n "$((config_list_line + 3))p" "$pbxproj" | grep -o '[0-9A-Fa-f]\{24\}')
    release_id=$(sed -n "$((config_list_line + 4))p" "$pbxproj" | grep -o '[0-9A-Fa-f]\{24\}')
    if [ -z "$debug_id" ] || [ -z "$release_id" ]; then
        echo "Warnung: Debug/Release-Build-Config-IDs für '$target_name' nicht gefunden – Versions-Sync übersprungen." >&2
        return
    fi

    awk -v debug_id="$debug_id" -v release_id="$release_id" -v new_version="$NEW_VERSION" '
        $0 ~ debug_id " /\\* Debug configuration.*= \\{" { in_block = 1 }
        $0 ~ release_id " /\\* Release configuration.*= \\{" { in_block = 1 }
        in_block && /MARKETING_VERSION = / {
            sub(/MARKETING_VERSION = [^;]*;/, "MARKETING_VERSION = " new_version ";")
        }
        in_block && /CURRENT_PROJECT_VERSION = / {
            if (match($0, /[0-9]+/)) {
                old = substr($0, RSTART, RLENGTH)
                sub(/CURRENT_PROJECT_VERSION = [0-9]+;/, "CURRENT_PROJECT_VERSION = " (old + 1) ";")
            }
        }
        /name = (Debug|Release);/ { in_block = 0 }
        { print }
    ' "$pbxproj" > "$pbxproj.tmp" && mv "$pbxproj.tmp" "$pbxproj"

    # Gezielt nur die pbxproj-Datei stagen (kein `add -A`), damit andere,
    # unabhängige uncommitted Änderungen in diesem Repo unberührt bleiben —
    # nur der Versions-Bump wird committet.
    git -C "$xcode_dir" add "$pbxproj"
    if git -C "$xcode_dir" diff --cached --quiet -- "$pbxproj"; then
        echo "Xcode-Projekt-Version bereits aktuell ($NEW_VERSION) – kein Commit nötig."
        return
    fi
    if ! git -C "$xcode_dir" commit --quiet -m "chore: Version auf $NEW_VERSION setzen"; then
        echo "Warnung: Commit im Xcode-Projekt fehlgeschlagen – bitte manuell prüfen: $xcode_dir" >&2
        return
    fi
    if ! git -C "$xcode_dir" push origin main --quiet; then
        echo "Warnung: Push des Xcode-Projekt-Commits fehlgeschlagen – bitte manuell pushen: $xcode_dir" >&2
        return
    fi

    echo "Xcode-Projekt-Version aktualisiert, committet und gepusht: $pbxproj (MARKETING_VERSION=$NEW_VERSION, CURRENT_PROJECT_VERSION +1)."
}

sync_xcode_project_version
