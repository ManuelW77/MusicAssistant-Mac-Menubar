.PHONY: build test run verify app dmg release

APP_NAME := MA Menubar
APP_BUNDLE := dist/$(APP_NAME).app
DMG_PATH := dist/$(APP_NAME).dmg

# Echte Signing-Identität aus der Keychain (siehe `security find-identity -v
# -p codesigning`). Auf einem Rechner ohne dieses Zertifikat mit
# `make app SIGN_IDENTITY=-` auf ad-hoc-Signatur zurückfallen.
SIGN_IDENTITY := Apple Development: Manuel Weiser (469HR6FMTH)

build:
	swift build

test:
	swift test

# Baut die App und signiert sie mit den Sandbox/Network-Entitlements, damit
# LSUIElement + App-Sandbox greifen (kein Xcode-Projekt vorhanden,
# xcodegen/tuist sind auf diesem Rechner nicht installiert).
run: build
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements App/MAMenubar.entitlements .build/debug/MAMenubar
	.build/debug/MAMenubar

# Schritt-0-Protokollverifikation gegen einen echten Server, z.B.:
#   make verify URL=https://music.fire-devils.org TOKEN=abc123
verify: build
	swift run VerifyConnection $(URL) $(TOKEN)

# Baut ein echtes, doppelklickbares .app-Bundle im Release-Modus unter
# dist/, das sich z.B. nach /Applications ziehen lässt.
app:
	swift build -c release
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp .build/release/MAMenubar "$(APP_BUNDLE)/Contents/MacOS/MAMenubar"
	cp App/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	if [ -f App/AppIcon.icns ]; then \
		cp App/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"; \
	fi
	if [ -f App/MenubarIcon.png ]; then \
		cp App/MenubarIcon.png "$(APP_BUNDLE)/Contents/Resources/MenubarIcon.png"; \
	fi
	# --options runtime (Hardened Runtime) + --timestamp (Secure Timestamp)
	# sind Pflicht für Notarization, sonst lehnt Apple mit "does not have
	# the hardened runtime enabled" ab.
	codesign --force --options runtime --timestamp --sign "$(SIGN_IDENTITY)" --entitlements App/MAMenubar.entitlements "$(APP_BUNDLE)"
	@echo "Fertig: $(APP_BUNDLE)"

# Baut ein Drag-in-Applications-.dmg aus dem bereits gebauten (und für
# Distribution im Idealfall bereits notarisierten/gestapelten) .app-Bundle.
# Voraussetzung: `make app` (bzw. der App/Notarization-Schritt in CI) ist
# bereits gelaufen, "$(APP_BUNDLE)" existiert.
dmg:
	rm -f "$(DMG_PATH)"
	rm -rf dist/dmg-staging
	mkdir -p dist/dmg-staging
	cp -R "$(APP_BUNDLE)" dist/dmg-staging/
	ln -s /Applications "dist/dmg-staging/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder dist/dmg-staging -ov -format UDZO "$(DMG_PATH)"
	rm -rf dist/dmg-staging
	@echo "Fertig: $(DMG_PATH)"

# Version bumpen (Standard: patch) und Release via GitHub Actions anstoßen.
# Nur vom main-Branch aus lauffähig, siehe scripts/release.sh.
#   make release            # Patch-Bump
#   make release BUMP=minor # Minor-Bump
#   make release BUMP=v2.0.0
release:
	./scripts/release.sh $(BUMP)
