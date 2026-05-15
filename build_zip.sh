#!/usr/bin/env bash
# Build "Aerial Switcher Shareable.zip" from bundle/.
#
# Uses ditto (instead of zip) to preserve macOS metadata and executable
# bits cleanly. Stages bundle/ as Aerial Switcher/ in a temp dir so the
# archive's top-level entry has the friendly name.
#
# The _Private/ directory is excluded if it exists (it's generated per Mac).

set -euo pipefail
cd "$(dirname "$0")"

OUT="Aerial Switcher Shareable.zip"
SRC="bundle"
FRIENDLY_NAME="Aerial Switcher"

if [[ ! -d "$SRC" ]]; then
  echo "Source directory not found: $SRC" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Strip any Finder-leftover .DS_Store files so ditto doesn't choke and
# the recipient doesn't see noise.
find "$SRC" -name ".DS_Store" -delete 2>/dev/null || true

ditto "$SRC" "$STAGE/$FRIENDLY_NAME"
rm -rf "$STAGE/$FRIENDLY_NAME/_Private"
find "$STAGE/$FRIENDLY_NAME" -name ".DS_Store" -delete 2>/dev/null || true

rm -f "$OUT"
# --norsrc / --noextattr / --noacl suppress AppleDouble (._*) sidecars in
# the archive. Unix executable bits are preserved (those are mode bits, not
# extended attributes), which is all we actually need.
ditto -c -k --keepParent --norsrc --noextattr --noacl \
  "$STAGE/$FRIENDLY_NAME" "$OUT"

bytes="$(stat -f%z "$OUT")"
echo "Built: $OUT (${bytes} bytes)"
echo
echo "Recipient instructions (also in bundle/README.txt):"
echo "  1. Double-click the zip to extract."
echo "  2. Move 'Aerial Switcher' into your home folder."
echo "  3. Right-click 'Install.command' -> Open (Gatekeeper warning, accept once)."
echo "  4. Follow prompts to capture each Tahoe ocean variant."
