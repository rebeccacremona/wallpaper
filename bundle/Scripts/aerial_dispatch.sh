#!/usr/bin/env bash
# Main sun-aware wallpaper dispatcher. Called by the LaunchAgent every
# CHECK_INTERVAL_SECONDS while the Mac is awake.
#
# Refreshes today's sun times if needed, picks the right profile for the
# current local time, and applies it only if it differs from the last
# applied profile.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

ensure_private_dirs

needs_sun_refresh() {
  if [[ ! -f "$SUN_FILE" ]]; then
    return 0
  fi
  # All "is the cache from today" / "what time is it" comparisons happen in
  # the user's configured timezone, not the machine's local timezone. This
  # matters if someone sets TZ in config.env to a zone different from their
  # Mac's system timezone (e.g. travelling, testing).
  local file_date today
  file_date="$(TZ="$TZ" date -r "$SUN_FILE" +%Y-%m-%d)"
  today="$(TZ="$TZ" date +%Y-%m-%d)"
  if [[ "$file_date" != "$today" ]]; then
    return 0
  fi
  # If the cached file was computed for a different location than the
  # current config, refresh. Catches the case where the user edits
  # config.env directly without re-running Install.command. A missing
  # LOCATION_KEY (e.g. cache from a pre-upgrade version of this script)
  # is also treated as stale.
  local cached_key
  cached_key="$(awk -F'"' '/^LOCATION_KEY=/ {print $2}' "$SUN_FILE")"
  local current_key="${LAT}|${LNG}|${TZ}"
  if [[ "$cached_key" != "$current_key" ]]; then
    log "Location changed (was '${cached_key:-unknown}', now '$current_key') -- refreshing."
    return 0
  fi
  return 1
}

write_fallback_sun_file() {
  cat > "$SUN_FILE" <<'FALLBACK'
SUNRISE="06:00"
SUNSET="18:00"
MORNING_START="05:30"
DAY_START="08:00"
EVENING_START="16:30"
NIGHT_START="20:00"
UPDATED_AT="fallback"
FALLBACK
}

if needs_sun_refresh; then
  log "Refreshing sun times..."
  if ! "$HERE/update_sun_times.sh"; then
    log "Could not refresh sun times; using existing file if available."
    if [[ ! -f "$SUN_FILE" ]]; then
      log "No sun-times file exists; falling back to fixed default schedule."
      write_fallback_sun_file
    fi
  fi
fi

# shellcheck disable=SC1090
source "$SUN_FILE"

to_minutes() {
  local t="$1"
  local h="${t%%:*}"
  local m="${t##*:}"
  printf '%d' $((10#$h * 60 + 10#$m))
}

NOW="$(TZ="$TZ" date +%H:%M)"
now_m="$(to_minutes "$NOW")"
morning_m="$(to_minutes "$MORNING_START")"
day_m="$(to_minutes "$DAY_START")"
evening_m="$(to_minutes "$EVENING_START")"
night_m="$(to_minutes "$NIGHT_START")"

# Logical day order: Night -> Morning -> Day -> Evening -> Night.
# Determine current bucket using the four start times.
if (( now_m >= morning_m && now_m < day_m )); then
  selected="Morning"
elif (( now_m >= day_m && now_m < evening_m )); then
  selected="Day"
elif (( now_m >= evening_m && now_m < night_m )); then
  selected="Evening"
else
  selected="Night"
fi

PROFILE="$(profile_path "$selected")"

last_profile=""
if [[ -f "$LAST_PROFILE_FILE" ]]; then
  last_profile="$(cat "$LAST_PROFILE_FILE")"
fi

if [[ "$last_profile" == "$PROFILE" ]]; then
  log "Now=$NOW sunrise=$SUNRISE sunset=$SUNSET already using $(basename "$PROFILE"); no change."
  exit 0
fi

if [[ ! -f "$PROFILE" ]]; then
  log "Selected profile does not exist yet: $PROFILE"
  log "Run 'Capture Wallpaper Profiles.command' from the Controls folder first."
  exit 1
fi

log "Now=$NOW sunrise=$SUNRISE sunset=$SUNSET applying $(basename "$PROFILE")"
"$HERE/update_aerial.sh" "$PROFILE"
printf '%s' "$PROFILE" > "$LAST_PROFILE_FILE"
