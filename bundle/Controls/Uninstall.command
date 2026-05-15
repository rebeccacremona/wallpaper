#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

cat <<BANNER
Uninstall Tahoe Aerial Switcher
===============================

What this will do:

  - Stop the LaunchAgent ($LABEL).
  - Remove the LaunchAgent plist:
      $PLIST
  - Move this folder to the Trash:
      $BASE

What it will NOT do:

  - Will NOT change your current wallpaper.
  - Will NOT delete any of Apple's built-in wallpapers.

If your wallpaper system is misbehaving (e.g. after a macOS update),
cancel this and run 'Reset Wallpaper to Default.command' first.

BANNER

read -r -p "Continue? (y/N): " confirm
confirm="${confirm:-N}"
if [[ ! "$confirm" =~ ^[Yy] ]]; then
  echo
  echo "Cancelled. Nothing changed."
  exit 0
fi

divider

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "Removed LaunchAgent."

# Move-to-Trash: use a plain `mv` rather than osascript+Finder. The
# previous AppleScript approach used `POSIX file p as alias`, which
# can resolve to a stale Finder alias cache (e.g., after rapid
# rm/unzip cycles during development) and report success without
# actually moving the live inode. `mv` is unaffected by Finder's
# alias cache, doesn't trigger a TCC Automation prompt, and is
# atomic when source and destination are on the same volume.
trash_dest="$HOME/.Trash/$(basename "$BASE").uninstalled-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$HOME/.Trash"
echo "Moving $BASE to the Trash..."
mv "$BASE" "$trash_dest"

echo
echo "Uninstalled. The folder was moved to the Trash as:"
echo "  $(basename "$trash_dest")"
echo "(You can recover it from Trash if needed. The Terminal window stays"
echo "open so you can read this; close it when done.)"
