.PHONY: build test run verify

build:
	swift build

test:
	swift test

# Baut die App und signiert sie ad-hoc mit den Sandbox/Network-Entitlements,
# damit LSUIElement + App-Sandbox greifen (kein Xcode-Projekt vorhanden,
# xcodegen/tuist sind auf diesem Rechner nicht installiert).
run: build
	codesign --force --sign - --entitlements App/MAMenubar.entitlements .build/debug/MAMenubar
	.build/debug/MAMenubar

# Schritt-0-Protokollverifikation gegen einen echten Server, z.B.:
#   make verify URL=https://music.fire-devils.org TOKEN=abc123
verify: build
	swift run VerifyConnection $(URL) $(TOKEN)
