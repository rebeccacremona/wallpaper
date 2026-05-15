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
  2. Stop the background switcher (so the old captured profiles
     don't immediately get re-applied) and quit WallpaperAgent.
  3. Move ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
     aside (renamed, NOT deleted, in case you need it later).
  4. Clear the dispatcher's "last applied profile" memory.
  5. Restart WallpaperAgent.

After this, macOS will regenerate Index.plist from defaults the next
time you open System Settings -> Wallpaper. Pick a wallpaper there to
confirm things are working again.

This does NOT uninstall the switcher. Your captured profiles and the
rest of the setup all stay in place -- but the background helper is
turned OFF until you explicitly turn it back on (after re-capturing,
since the previous captures may be why things broke).

This action is reversible -- nothing is deleted, only moved aside.

BANNER

read -r -p "Continue? (y/N): " confirm
confirm="${confirm:-N}"
if [[ ! "$confirm" =~ ^[Yy] ]]; then
  echo
  echo "Cancelled. Nothing changed."
  exit 0
fi

divider

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

echo "Stopping the background switcher (so it doesn't re-apply old captures)..."
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true

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

divider

cat <<'NEXT'
Done. The background switcher is now OFF.

Next steps:

  1. Open System Settings -> Wallpaper and select any wallpaper.
     macOS will regenerate Index.plist from defaults.

  Then choose ONE of:

  2a. Keep using the switcher. Double-click:
         Capture Wallpaper Profiles.command
      to save fresh profiles for each Tahoe variant, then:
         Turn On.command
      to start the switcher again.

  2b. You're done with the switcher. Double-click:
         Uninstall.command
      to remove it entirely (this will move the whole folder to
      the Trash and remove the background helper).
NEXT
