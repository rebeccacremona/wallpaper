#!/usr/bin/env bash
# Compute today's sunrise/sunset and window starts using the local NOAA
# formula (no network), and atomically write them to $SUN_FILE.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

ensure_private_dirs

TMP="$(mktemp "$STATE/sun_times.env.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

if ! /usr/bin/python3 "$HERE/compute_sun_times.py" \
    "$LAT" "$LNG" "$TZ" \
    "$MORNING_OFFSET_MIN" "$DAY_OFFSET_MIN" \
    "$EVENING_OFFSET_MIN" "$NIGHT_OFFSET_MIN" \
    > "$TMP"; then
  echo "compute_sun_times.py failed" >&2
  exit 1
fi

mv "$TMP" "$SUN_FILE"
trap - EXIT
