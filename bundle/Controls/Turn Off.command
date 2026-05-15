#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true

echo
echo "Tahoe Aerial Switcher is OFF."
echo "Your current wallpaper will stay as-is."
