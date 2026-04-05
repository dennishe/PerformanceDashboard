#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-release.sh
# Builds a release .app bundle and a distributable .pkg installer.
#
# Usage:
#   ./scripts/build-release.sh [--sign "Developer ID Application: Name (TEAMID)"]
#                              [--notarize] [--apple-id you@example.com]
#                              [--team-id TEAMID] [--keychain-profile PROFILE]
#
# Flags:
#   --sign              Codesign identity (optional; skips signing if absent)
#   --notarize          Submit pkg for notarization after signing
#   --apple-id          Apple ID for notarytool (required when --notarize)
#   --team-id           Team ID for notarytool (required when --notarize)
#   --keychain-profile  Stored keychain profile name for notarytool
#                       (alternative to --apple-id / --team-id)
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
APP_NAME="PerformanceDashboard"
BUNDLE_ID="com.Wecode.PerformanceDashboard"
VERSION="1.0"
MIN_MACOS="26.4"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/.build/release"
STAGING_DIR="$REPO_ROOT/.build/staging"
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
DIST_DIR="$REPO_ROOT/dist"

SIGN_IDENTITY=""
NOTARIZE=false
APPLE_ID=""
TEAM_ID=""
KC_PROFILE=""

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)            SIGN_IDENTITY="$2"; shift 2 ;;
        --notarize)        NOTARIZE=true; shift ;;
        --apple-id)        APPLE_ID="$2"; shift 2 ;;
        --team-id)         TEAM_ID="$2"; shift 2 ;;
        --keychain-profile) KC_PROFILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
step() { echo; echo "▶ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" &>/dev/null || die "'$1' not found. Install Xcode Command Line Tools."
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
step "Pre-flight checks"
require_cmd swift
require_cmd pkgbuild
require_cmd productbuild
[[ -n "$SIGN_IDENTITY" ]] && require_cmd codesign
$NOTARIZE && require_cmd xcrun

ICON_SRC="$REPO_ROOT/Resources/AppIcon.icns"
if [[ ! -f "$ICON_SRC" ]]; then
    echo "  ⚠  No AppIcon.icns found in Resources/. Run scripts/make-icon.sh first."
    echo "     The app bundle will have no custom icon."
    ICON_SRC=""
fi

# ── 1. Build release binary ──────────────────────────────────────────────────
step "Building release binary"
cd "$REPO_ROOT"
swift build -c release
BINARY="$BUILD_DIR/$APP_NAME"
[[ -f "$BINARY" ]] || die "Binary not found at $BINARY"

# ── 2. Assemble .app bundle ───────────────────────────────────────────────────
step "Assembling .app bundle → $APP_BUNDLE"
rm -rf "$STAGING_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
[[ -n "$ICON_SRC" ]] && cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Write Info.plist
ICON_FILE_ENTRY=""
[[ -n "$ICON_SRC" ]] && ICON_FILE_ENTRY="
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>         <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>         <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>               <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>            <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>     <string>${MIN_MACOS}</string>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>    <true/>${ICON_FILE_ENTRY}
</dict>
</plist>
PLIST

# Copy entitlements into bundle (used by codesign below)
cp "$REPO_ROOT/PerformanceDashboard.entitlements" \
   "$APP_BUNDLE/Contents/$APP_NAME.entitlements"

echo "  Bundle assembled."

# ── 3. Code-sign ──────────────────────────────────────────────────────────────
if [[ -n "$SIGN_IDENTITY" ]]; then
    step "Code-signing with '$SIGN_IDENTITY'"
    codesign \
        --deep \
        --force \
        --options runtime \
        --entitlements "$APP_BUNDLE/Contents/$APP_NAME.entitlements" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
    codesign --verify --deep --strict "$APP_BUNDLE"
    echo "  Signed OK."
else
    echo "  (Skipping code-signing — pass --sign to enable)"
fi

# ── 4. Build .pkg ─────────────────────────────────────────────────────────────
step "Building installer package"
mkdir -p "$DIST_DIR"
COMPONENT_PKG="$STAGING_DIR/$APP_NAME-component.pkg"
FINAL_PKG="$DIST_DIR/$APP_NAME-${VERSION}.pkg"

pkgbuild \
    --root "$APP_BUNDLE" \
    --install-location "/Applications/$APP_NAME.app" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    "$COMPONENT_PKG"

if [[ -n "$SIGN_IDENTITY" ]]; then
    productbuild \
        --sign "$SIGN_IDENTITY" \
        --package "$COMPONENT_PKG" \
        "$FINAL_PKG"
else
    productbuild \
        --package "$COMPONENT_PKG" \
        "$FINAL_PKG"
fi

echo "  Installer → $FINAL_PKG"

# ── 5. Notarize ───────────────────────────────────────────────────────────────
if $NOTARIZE; then
    step "Submitting for notarization"

    NOTARY_ARGS=(--wait)

    if [[ -n "$KC_PROFILE" ]]; then
        NOTARY_ARGS+=(--keychain-profile "$KC_PROFILE")
    else
        [[ -z "$APPLE_ID" ]] && die "--apple-id required when --notarize is set"
        [[ -z "$TEAM_ID"  ]] && die "--team-id required when --notarize is set"
        NOTARY_ARGS+=(--apple-id "$APPLE_ID" --team-id "$TEAM_ID")
    fi

    xcrun notarytool submit "$FINAL_PKG" "${NOTARY_ARGS[@]}"
    xcrun stapler staple "$FINAL_PKG"
    echo "  Notarization complete."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "✓ Done!  Output: $FINAL_PKG"
