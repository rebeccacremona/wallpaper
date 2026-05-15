#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

ensure_private_dirs

cat <<'BANNER'
Reset Wallpaper to Default
==========================

Use this when something has gone wrong with your wallpaper system --
for example, after a macOS update if the captured profiles no longer
work, or if the wallpaper just looks broken.

What this will do:

  1. Snapshot your current wallpaper system state for forensics
     (into _Private/Backups/wallpaper-state-<timestamp>/).
  2. Quit WallpaperAgent.
  3. Move ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
     aside (renamed, NOT deleted, in case you need it later).
  4. Clear the dispatcher's "last applied profile" memory.
  5. Restart WallpaperAgent.

After this, macOS will regenerate Index.plist from defaults the next
time you open System Settings -> Wallpaper. Pick a wallpaper there to
confirm things are working again.

This does NOT uninstall the switcher. Your captured profiles, the
LaunchAgent, and the rest of the setup all stay in place. To start
using the switcher again afterwards, re-run Capture Wallpaper
Profiles.command (since the previous captures may be why things
broke).

This action is reversible -- nothing is deleted, only moved aside.

BANNER

read -r -p "Type RESET to continue (anything else cancels): " confirm
if [[ "$confirm" != "RESET" ]]; then
  echo
  echo "Cancelled. Nothing changed."
  exit 0
fi

ts="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="$BACKUPS/wallpaper-state-${ts}"

echo
if [[ -d "$WALLPAPER_STORE_DIR" ]]; then
  echo "Snapshotting $WALLPAPER_STORE_DIR -> $SNAPSHOT_DIR"
  mkdir -p "$SNAPSHOT_DIR"
  ditto "$WALLPAPER_STORE_DIR" "$SNAPSHOT_DIR"
else
  echo "No existing wallpaper store directory to snapshot (that's fine)."
fi

echo "Quitting WallpaperAgent..."
killall WallpaperAgent 2>/dev/null || true

if [[ -f "$WALLPAPER_INDEX" ]]; then
  moved="${WALLPAPER_INDEX}.broken.${ts}"
  echo "Renaming Index.plist aside:"
  echo "  $WALLPAPER_INDEX"
  echo "  -> $moved"
  mv "$WALLPAPER_INDEX" "$moved"
else
  echo "No Index.plist to move aside (already absent)."
fi

if [[ -f "$LAST_PROFILE_FILE" ]]; then
  rm -f "$LAST_PROFILE_FILE"
  echo "Cleared dispatcher state ($LAST_PROFILE_FILE)."
fi

# Give launchd a moment, then poke WallpaperAgent so it respawns cleanly.
sleep 1
killall WallpaperAgent 2>/dev/null || true

cat <<'NEXT'

Done.

Next steps:

  - Open System Settings -> Wallpaper and select any wallpaper. macOS
    will regenerate Index.plist from defaults.
  - If you want to keep using the switcher, then re-run:
        Capture Wallpaper Profiles.command
NEXT
