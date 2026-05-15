#!/usr/bin/env bash
# Shared helpers for the Tahoe Aerial Switcher.
#
# Source this file from any script. It will:
#   1. Locate the bundle root (BASE) by walking up from common.sh's own path.
#   2. Source config.env so callers see LAT/LNG/TZ/LABEL_SUFFIX/etc.
#   3. Define standard paths (PRIVATE, BACKUPS, PROFILES, STATE).
#   4. Define the LaunchAgent LABEL and PLIST path (uses $USER/$HOME at
#      runtime, so the same bundle works on any Mac).
#   5. Define a log() helper.
#
# Nothing in this file bakes in author-side paths or usernames.

set -euo pipefail

# Resolve BASE = the bundle root (the directory that contains Scripts/ and Controls/).
# common.sh lives at $BASE/Scripts/lib/common.sh, so go up two levels.
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$_COMMON_DIR/../.." && pwd)"
SCRIPTS="$BASE/Scripts"
CONTROLS="$BASE/Controls"

CONFIG="$SCRIPTS/lib/config.env"
if [[ ! -f "$CONFIG" ]]; then
  echo "common.sh: missing $CONFIG" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

PRIVATE="$BASE/_Private"
BACKUPS="$PRIVATE/Backups"
PROFILES="$PRIVATE/Profiles"
STATE="$PRIVATE/State"

# User-specific overrides (created by Change Settings.command). Sourced
# after the shipped defaults so any keys it sets win. Absence is fine --
# fresh installs and unconfigured recipients use the shipped defaults.
USER_CONFIG="$STATE/user_config.env"
if [[ -f "$USER_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$USER_CONFIG"
fi

SUN_FILE="$STATE/sun_times.env"
LAST_PROFILE_FILE="$STATE/last_applied_profile"

LABEL="com.${USER}.${LABEL_SUFFIX}"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_OUT="$HOME/Library/Logs/${LABEL}.out.log"
LOG_ERR="$HOME/Library/Logs/${LABEL}.err.log"

WALLPAPER_STORE_DIR="$HOME/Library/Application Support/com.apple.wallpaper"
WALLPAPER_INDEX="$WALLPAPER_STORE_DIR/Store/Index.plist"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Visual section divider for Controls and the installer. Use between
# major chunks of output so the user can see "I'm now in a new step."
# 60 chars, plain ASCII, blank-line padded.
divider() {
  printf '\n------------------------------------------------------------\n\n'
}

ensure_private_dirs() {
  mkdir -p "$BACKUPS" "$PROFILES" "$STATE"
}

# Names of the four expected profile files.
PROFILE_NAMES=("Morning" "Day" "Evening" "Night")

profile_path() {
  printf '%s/Tahoe-%s.plist' "$PROFILES" "$1"
}

all_profiles_present() {
  local name
  for name in "${PROFILE_NAMES[@]}"; do
    if [[ ! -f "$(profile_path "$name")" ]]; then
      return 1
    fi
  done
  return 0
}
