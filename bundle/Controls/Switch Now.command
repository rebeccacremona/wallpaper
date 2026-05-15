#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

"$SCRIPTS/aerial_dispatch.sh"

echo
echo "Checked sun times and applied the current wallpaper if needed."
