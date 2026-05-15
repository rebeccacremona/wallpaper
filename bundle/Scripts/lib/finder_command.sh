# Boilerplate sourced by every Controls/*.command file.
#
# Usage at the top of each .command file:
#   #!/usr/bin/env bash
#   COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"
#
# That gives the .command access to: BASE, SCRIPTS, CONTROLS, PRIVATE,
# BACKUPS, PROFILES, STATE, LABEL, PLIST, LOG_OUT, LOG_ERR, LAT, LNG, TZ,
# CHECK_INTERVAL_SECONDS, log(), profile_path(), all_profiles_present().

set -euo pipefail

_FC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$_FC_DIR/common.sh"

# Print a blank line so script output isn't visually butted up against
# the Terminal-launched command line. macOS double-click of a .command
# spawns "/path/to/Foo.command ; exit;" with no trailing newline, so
# without this the first line of script output appears on the same row.
echo
