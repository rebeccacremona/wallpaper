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

read -r -p "Type UNINSTALL to continue (anything else cancels): " confirm
if [[ "$confirm" != "UNINSTALL" ]]; then
  echo
  echo "Cancelled. Nothing changed."
  exit 0
fi

echo
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "Removed LaunchAgent."

echo "Moving $BASE to the Trash..."
osascript - "$BASE" <<'APPLESCRIPT'
on run argv
    set p to item 1 of argv
    tell application "Finder"
        delete (POSIX file p as alias)
    end tell
end run
APPLESCRIPT

echo
echo "Uninstalled. The folder was moved to the Trash."
echo "(The Terminal window stays open so you can read this; close it when done.)"

# Don't pause -- the parent BASE is gone, but Terminal handles that fine.
trap - EXIT
