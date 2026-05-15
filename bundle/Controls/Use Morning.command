#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

PROFILE="$(profile_path "Morning")"

if [[ ! -f "$PROFILE" ]]; then
  echo "Morning profile not captured yet:"
  echo "  $PROFILE"
  echo
  echo "Run 'Capture Wallpaper Profiles.command' first."
  exit 1
fi

"$SCRIPTS/update_aerial.sh" "$PROFILE"
printf '%s' "$PROFILE" > "$LAST_PROFILE_FILE"

echo
echo "Applied Morning."
