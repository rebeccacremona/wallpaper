#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

if [[ ! -f "$PLIST" ]]; then
  echo "LaunchAgent plist not found at:"
  echo "  $PLIST"
  echo
  echo "Run Install.command first (in the parent folder) to set things up."
  exit 1
fi

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo
echo "Tahoe Aerial Switcher is ON."
