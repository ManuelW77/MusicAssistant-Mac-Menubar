#!/usr/bin/env bash
# Release-Script: nur vom main-Branch aus lauffähig (main = reiner
# Release-Spiegel, devel bleibt der Arbeits-Branch). Ermittelt die nächste
# SemVer-Version, pusht main nach origin (Gitea) + github, und pusht den
# neuen vX.Y.Z-Tag nach github — das löst dort den Sign & Notarize-Workflow
# aus (.github/workflows/release.yml).
#
# Verwendung:
#   ./scripts/release.sh            # Patch-Bump (Standard)
#   ./scripts/release.sh minor      # Minor-Bump
#   ./scripts/release.sh major      # Major-Bump
#   ./scripts/release.sh v2.3.0     # explizite Version
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

LATEST_TAG=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n1)
LATEST_TAG="${LATEST_TAG:-v0.0.0}"
LATEST_VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_VERSION"

BUMP="${1:-patch}"
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

git tag -a "$NEW_TAG" -m "$NEW_TAG"
git push origin "$NEW_TAG"
git push github "$NEW_TAG"

echo ""
echo "Fertig. $NEW_TAG gepusht — Build/Sign/Notarize läuft:"
echo "  https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/actions"
