#!/usr/bin/env bash
# Interactive configuration helper.
#
# Walks through location, schedule, and check-frequency prompts. Writes
# changes atomically to Scripts/lib/config.env. Optionally invokes
# Install.command at the end to apply (rewrite LaunchAgent + reload).
#
# Each prompt has a "keep current" option, so re-running this is safe.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

NEW_CONFIG="$(mktemp "$STATE/config.env.new.XXXXXX" 2>/dev/null \
  || mktemp -t config.env.new.XXXXXX)"
mkdir -p "$STATE" 2>/dev/null || true
trap 'rm -f "$NEW_CONFIG"' EXIT

cp "$CONFIG" "$NEW_CONFIG"

# update_kv NEW_CONFIG KEY VALUE
update_kv() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^${key}=" "$file"; then
    sed -i '' -E "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

quoted() { printf '"%s"' "$1"; }

detect_preset() {
  if [[ "$MORNING_OFFSET_MIN" == "-15"  && "$DAY_OFFSET_MIN" == "60"  \
     && "$EVENING_OFFSET_MIN" == "-60"  && "$NIGHT_OFFSET_MIN" == "60"  ]]; then
    echo Short
  elif [[ "$MORNING_OFFSET_MIN" == "-30"  && "$DAY_OFFSET_MIN" == "120" \
     && "$EVENING_OFFSET_MIN" == "-90"  && "$NIGHT_OFFSET_MIN" == "120" ]]; then
    echo Normal
  elif [[ "$MORNING_OFFSET_MIN" == "-45"  && "$DAY_OFFSET_MIN" == "180" \
     && "$EVENING_OFFSET_MIN" == "-120" && "$NIGHT_OFFSET_MIN" == "90"  ]]; then
    echo Long
  else
    echo Custom
  fi
}

detect_freq_label() {
  case "$CHECK_INTERVAL_SECONDS" in
    300)  echo "Every 5 minutes"  ;;
    900)  echo "Every 15 minutes" ;;
    1800) echo "Every 30 minutes" ;;
    *)    echo "Every $CHECK_INTERVAL_SECONDS seconds (custom)" ;;
  esac
}

current_preset="$(detect_preset)"
current_freq_label="$(detect_freq_label)"

cat <<'BANNER'
Change Settings
===============

You can update three things here:

  1. Your location (city) -- used to compute sunrise and sunset.
  2. Schedule -- how long the morning and evening windows last.
  3. Check frequency -- how often the switcher looks at the clock.

For each one, you can press Return to keep your current setting. None
of your changes are saved until the very end, so you can cancel
anytime with Ctrl-C.

BANNER

if [[ -n "${LOCATION_LABEL:-}" ]]; then
  echo "Current location:  $LOCATION_LABEL"
  echo "                   ($LAT, $LNG, $TZ)"
else
  echo "Current location:  $LAT, $LNG  ($TZ)"
  echo "                   (no city name on file -- pick one below to add one)"
fi
echo

# ---------- Location ----------

read -r -p "Enter a city to look up (or Return to keep current): " city_input

if [[ -n "$city_input" ]]; then
  echo "Searching..."
  encoded=$(/usr/bin/python3 -c \
    'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))' \
    "$city_input")
  api="https://geocoding-api.open-meteo.com/v1/search?name=${encoded}&count=10&language=en&format=json"

  if ! response=$(curl -fsSL --max-time 8 "$api" 2>/dev/null); then
    echo "Could not reach the geocoding service. Skipping location update."
    response=''
  fi

  if [[ -n "$response" ]]; then
    options=$(/usr/bin/python3 - <<PY
import json, sys
try:
    data = json.loads('''$response''')
except Exception:
    sys.exit(1)
results = data.get('results') or []
for i, r in enumerate(results, 1):
    parts = [r.get('name'), r.get('admin1'), r.get('country')]
    label = ' / '.join(p for p in parts if p)
    print(f"{i}|{label}|{r.get('latitude')}|{r.get('longitude')}|{r.get('timezone')}")
PY
    )

    if [[ -z "$options" ]]; then
      echo "No matches for '$city_input'. Keeping current location."
    else
      echo
      echo "Matches:"
      echo "$options" | awk -F'|' '{ printf "  %s. %s (%s)\n", $1, $2, $5 }'
      echo "  0. Cancel (keep current location)"
      echo
      read -r -p "Pick a number: " pick

      if [[ "$pick" == "0" || -z "$pick" ]]; then
        echo "Keeping current location."
      else
        chosen=$(echo "$options" | awk -F'|' -v n="$pick" '$1 == n')
        if [[ -z "$chosen" ]]; then
          echo "Invalid choice. Keeping current location."
        else
          new_label=$(echo "$chosen" | awk -F'|' '{print $2}')
          new_lat=$(echo "$chosen" | awk -F'|' '{print $3}')
          new_lng=$(echo "$chosen" | awk -F'|' '{print $4}')
          new_tz=$(echo "$chosen" | awk -F'|' '{print $5}')
          echo "Selected: $new_label"
          update_kv "$NEW_CONFIG" LAT "$(quoted "$new_lat")"
          update_kv "$NEW_CONFIG" LNG "$(quoted "$new_lng")"
          update_kv "$NEW_CONFIG" TZ "$(quoted "$new_tz")"
          update_kv "$NEW_CONFIG" LOCATION_LABEL "$(quoted "$new_label")"
        fi
      fi
    fi
  fi
fi

# ---------- Schedule preset ----------

cat <<PRESETS

Schedule presets (currently using: $current_preset). These set how
long the morning and evening windows last, relative to sunrise /
sunset:

  1. Short   -- crisp transitions
                Morning: 15 min before sunrise -> 1 hr after sunrise
                Evening: 1 hr before sunset    -> 1 hr after sunset

  2. Normal  -- the default
                Morning: 30 min before sunrise -> 2 hr after sunrise
                Evening: 90 min before sunset  -> 2 hr after sunset

  3. Long    -- extended ambience
                Morning: 45 min before sunrise -> 3 hr after sunrise
                Evening: 2 hr before sunset    -> 90 min after sunset

  4. Keep current ($current_preset)

PRESETS

read -r -p "Pick a number [4]: " preset
preset="${preset:-4}"

case "$preset" in
  1) M=-15;  D=60;  E=-60;  N=60  ;;
  2) M=-30;  D=120; E=-90;  N=120 ;;
  3) M=-45;  D=180; E=-120; N=90  ;;
  4) M=""; D=""; E=""; N="" ;;
  *) echo "Invalid choice. Keeping current schedule."; M=""; D=""; E=""; N="" ;;
esac

if [[ -n "$M" ]]; then
  update_kv "$NEW_CONFIG" MORNING_OFFSET_MIN "$M"
  update_kv "$NEW_CONFIG" DAY_OFFSET_MIN     "$D"
  update_kv "$NEW_CONFIG" EVENING_OFFSET_MIN "$E"
  update_kv "$NEW_CONFIG" NIGHT_OFFSET_MIN   "$N"
fi

# ---------- Check frequency ----------

cat <<FREQ

How often should the switcher check the clock? (currently: $current_freq_label)

  1. Every 5 minutes
  2. Every 15 minutes (default)
  3. Every 30 minutes
  4. Keep current ($current_freq_label)

FREQ

read -r -p "Pick a number [4]: " freq
freq="${freq:-4}"

case "$freq" in
  1) interval=300  ;;
  2) interval=900  ;;
  3) interval=1800 ;;
  4) interval=""   ;;
  *) echo "Invalid choice. Keeping current frequency."; interval="" ;;
esac

if [[ -n "$interval" ]]; then
  update_kv "$NEW_CONFIG" CHECK_INTERVAL_SECONDS "$interval"
fi

# ---------- Confirm + apply ----------

cat <<'SUMMARY'

------------------------------------------------------------
New settings:
SUMMARY
grep -E '^(LAT|LNG|TZ|MORNING|DAY|EVENING|NIGHT|CHECK)' "$NEW_CONFIG" \
  | sed 's/^/  /'
echo "------------------------------------------------------------"
echo

read -r -p "Save these settings? (Y/n): " save
save="${save:-Y}"

if [[ ! "$save" =~ ^[Yy] ]]; then
  echo "Cancelled. No changes made."
  exit 0
fi

mv "$NEW_CONFIG" "$CONFIG"
trap - EXIT
echo "Saved to $CONFIG."

# When invoked from Install.command, just exit -- the caller will apply.
if [[ "${CONFIGURE_FROM_INSTALL:-}" == "1" ]]; then
  exit 0
fi

echo
read -r -p "Apply now (re-runs Install.command)? (Y/n): " apply
apply="${apply:-Y}"

if [[ "$apply" =~ ^[Yy] ]]; then
  echo
  exec "$BASE/Install.command"
else
  cat <<DONE

Settings saved but not yet applied. To apply later, double-click
Install.command (it will skip the wallpaper-capture step if your
profiles are already saved).
DONE
fi
