#!/usr/bin/env bash
# Apply one captured Tahoe profile to the live wallpaper Index.plist,
# backing up the previous Index.plist first, then reload WallpaperAgent.
#
# Usage: update_aerial.sh /absolute/path/to/Profile.plist

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

PROFILE_PLIST="${1:-}"

if [[ -z "$PROFILE_PLIST" ]]; then
  echo "Usage: update_aerial.sh /path/to/Profile.plist" >&2
  exit 2
fi

if [[ ! -f "$PROFILE_PLIST" ]]; then
  echo "Profile not found: $PROFILE_PLIST" >&2
  exit 1
fi

ensure_private_dirs

if [[ -f "$WALLPAPER_INDEX" ]]; then
  cp "$WALLPAPER_INDEX" "$BACKUPS/Index.before-switch.$(date +%Y%m%d-%H%M%S).plist"
fi

mkdir -p "$(dirname "$WALLPAPER_INDEX")"
cp "$PROFILE_PLIST" "$WALLPAPER_INDEX"

killall WallpaperAgent 2>/dev/null || true
