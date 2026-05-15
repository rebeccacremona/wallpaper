# Boilerplate sourced by every Controls/*.command file.
#
# Usage at the top of each .command file:
#   #!/usr/bin/env bash
#   COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"
#
# That gives the .command access to:
#   Paths: BASE, SCRIPTS, CONTROLS, PRIVATE, BACKUPS, PROFILES, STATE,
#          CONFIG, USER_CONFIG, SUN_FILE, LAST_PROFILE_FILE,
#          WALLPAPER_STORE_DIR, WALLPAPER_INDEX
#   LaunchAgent: LABEL, PLIST, LOG_OUT, LOG_ERR
#   Effective config (shipped defaults overlaid by user_config.env if present):
#          LAT, LNG, TZ, LOCATION_LABEL, LABEL_SUFFIX,
#          MORNING_OFFSET_MIN, DAY_OFFSET_MIN, EVENING_OFFSET_MIN,
#          NIGHT_OFFSET_MIN, CHECK_INTERVAL_SECONDS
#   Helpers: log(), ensure_private_dirs(), profile_path(),
#            all_profiles_present(), PROFILE_NAMES (array)

set -euo pipefail

_FC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$_FC_DIR/common.sh"

# Print a blank line so script output isn't visually butted up against
# the Terminal-launched command line. macOS double-click of a .command
# spawns "/path/to/Foo.command ; exit;" with no trailing newline, so
# without this the first line of script output appears on the same row.
echo
