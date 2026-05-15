#!/usr/bin/env bash
# Report current state of the Tahoe Aerial Switcher.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

echo "Tahoe Aerial Switcher Status"
echo "============================"
echo
echo "Bundle location: $BASE"
echo "LaunchAgent label: $LABEL"
echo "LaunchAgent plist: $PLIST"
echo

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "Service: ON"
else
  echo "Service: OFF"
fi
echo

echo "Config (Scripts/lib/config.env):"
echo "  LAT=$LAT  LNG=$LNG  TZ=$TZ"
echo "  Window offsets (min):"
echo "    morning=$MORNING_OFFSET_MIN  day=$DAY_OFFSET_MIN"
echo "    evening=$EVENING_OFFSET_MIN  night=$NIGHT_OFFSET_MIN"
echo "  Check interval: ${CHECK_INTERVAL_SECONDS}s"
echo

if [[ -f "$SUN_FILE" ]]; then
  echo "Today's sun schedule:"
  sed 's/^/  /' "$SUN_FILE"
else
  echo "Today's sun schedule: not computed yet"
fi
echo

if [[ -f "$LAST_PROFILE_FILE" ]]; then
  echo "Last applied: $(basename "$(cat "$LAST_PROFILE_FILE")")"
else
  echo "Last applied: unknown"
fi
echo

echo "Saved profiles:"
found_any=0
for name in "${PROFILE_NAMES[@]}"; do
  p="$(profile_path "$name")"
  if [[ -f "$p" ]]; then
    found_any=1
    printf '  - %s\n' "$(basename "$p")"
  fi
done
if [[ "$found_any" -eq 0 ]]; then
  echo "  none yet (run 'Capture Wallpaper Profiles.command')"
fi
echo

echo "Recent activity (out log):"
if [[ -f "$LOG_OUT" ]]; then
  tail -n 10 "$LOG_OUT" | sed 's/^/  /'
else
  echo "  no output log yet"
fi
echo

echo "Recent errors (err log):"
if [[ -f "$LOG_ERR" ]]; then
  tail -n 10 "$LOG_ERR" | sed 's/^/  /'
else
  echo "  no error log yet"
fi
