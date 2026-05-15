#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

ensure_private_dirs

echo "Tahoe Wallpaper Profile Capture"
echo "==============================="
echo
echo "This will save four wallpaper profiles by snapshotting the active"
echo "wallpaper state after you select each Tahoe ocean variant in"
echo "System Settings."
echo
echo "Nothing is clicked automatically -- you'll be prompted before each"
echo "snapshot. Re-running this command overwrites any existing profiles."
echo

if [[ ! -f "$WALLPAPER_INDEX" ]]; then
  echo "Could not find the active wallpaper state file:"
  echo "  $WALLPAPER_INDEX"
  echo
  echo "Open System Settings -> Wallpaper at least once, then re-run this."
  exit 1
fi

if [[ ! -f "$BACKUPS/Index.original.first-capture.plist" ]]; then
  cp "$WALLPAPER_INDEX" "$BACKUPS/Index.original.first-capture.plist"
  echo "(Saved a one-time pristine backup of your current wallpaper state)"
  echo
fi

capture_one() {
  local name="$1"
  local dest
  dest="$(profile_path "$name")"

  echo
  echo "----------------------------------------------------------------"
  echo "Capturing: Tahoe ${name}"
  echo "----------------------------------------------------------------"
  echo "1. Open System Settings -> Wallpaper."
  echo "2. Select the Tahoe ${name} ocean wallpaper."
  echo "3. Wait until it is fully applied / downloaded."
  echo
  read -r -p "Press Return when Tahoe ${name} is active... " _

  if [[ ! -f "$WALLPAPER_INDEX" ]]; then
    echo "Active wallpaper state file disappeared:"
    echo "  $WALLPAPER_INDEX"
    exit 1
  fi

  cp "$WALLPAPER_INDEX" "$dest"
  echo "Saved: $dest"
}

for name in "${PROFILE_NAMES[@]}"; do
  capture_one "$name"
done

echo
echo "Done. Saved profiles:"
for name in "${PROFILE_NAMES[@]}"; do
  p="$(profile_path "$name")"
  if [[ -f "$p" ]]; then
    printf '  - %s (%s bytes)\n' "$(basename "$p")" "$(stat -f%z "$p")"
  fi
done
