#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# make-icon.sh
# Converts a single high-resolution PNG into an AppIcon.icns file and
# saves it to Resources/AppIcon.icns.
#
# Usage:
#   ./scripts/make-icon.sh <path-to-source-png>
#
# The source PNG must be at least 1024×1024 pixels.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_ICNS="$REPO_ROOT/Resources/AppIcon.icns"

# ── Validate input ────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <source-image.png>"
    exit 1
fi

SRC="$1"

[[ -f "$SRC" ]] || { echo "✗ File not found: $SRC"; exit 1; }

command -v sips     &>/dev/null || { echo "✗ 'sips' not found (macOS only)"; exit 1; }
command -v iconutil &>/dev/null || { echo "✗ 'iconutil' not found (macOS only)"; exit 1; }

# Verify minimum size
read -r SRC_W SRC_H < <(sips -g pixelWidth -g pixelHeight "$SRC" \
    | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w, h}')

if (( SRC_W < 1024 || SRC_H < 1024 )); then
    echo "✗ Source image is ${SRC_W}×${SRC_H}. Need at least 1024×1024."
    exit 1
fi

# ── Build iconset ─────────────────────────────────────────────────────────────
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

echo "▶ Generating icon sizes from $SRC"

resize() {
    local size=$1 name=$2
    sips -z "$size" "$size" "$SRC" --out "$ICONSET_DIR/$name" &>/dev/null
}

resize   16  "icon_16x16.png"
resize   32  "icon_16x16@2x.png"
resize   32  "icon_32x32.png"
resize   64  "icon_32x32@2x.png"
resize  128  "icon_128x128.png"
resize  256  "icon_128x128@2x.png"
resize  256  "icon_256x256.png"
resize  512  "icon_256x256@2x.png"
resize  512  "icon_512x512.png"
resize 1024  "icon_512x512@2x.png"

# ── Convert to .icns ──────────────────────────────────────────────────────────
echo "▶ Converting iconset → AppIcon.icns"
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"
rm -rf "$(dirname "$ICONSET_DIR")"

echo "✓ Icon saved to $OUT_ICNS"

# Keep the SPM resource copy in sync so Bundle.module picks up the new icon.
cp "$SRC" "$REPO_ROOT/Sources/AppIcon.png"
echo "✓ SPM resource updated at Sources/AppIcon.png"
