#!/usr/bin/env bash
COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/../Scripts/lib/finder_command.sh"

mkdir -p "$(dirname "$LOG_OUT")"
touch "$LOG_OUT" "$LOG_ERR"

open -a Console "$LOG_OUT" 2>/dev/null || open "$LOG_OUT"
open -a Console "$LOG_ERR" 2>/dev/null || open "$LOG_ERR"

echo
echo "Opened logs in Console.app."
echo "  Output: $LOG_OUT"
echo "  Errors: $LOG_ERR"
