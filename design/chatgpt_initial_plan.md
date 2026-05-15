> **Note:** This is the original plan as authored by ChatGPT, preserved verbatim
> as a historical artifact. The actual implementation diverged in several places
> for correctness, safety, and shareability reasons. See [`revisions.md`](revisions.md)
> for a detailed walkthrough of what changed and why.

---

Below is the full polished version, using the visible/shareable folder layout:

```text
~/Aerial Switcher/
  Controls/
  Scripts/
  _Private/
    Profiles/
    Backups/
    State/
```

The rule is:

```text
Controls/ and Scripts/ are shareable.
_Private/ is generated per Mac and should not be shared.
```

---

# Tahoe Ocean Dynamic Wallpaper Switcher

## What it does

Approximate schedule for Boston, MA:

| Time window                                   | Wallpaper |
| --------------------------------------------- | --------- |
| 30 min before sunrise → 2 hours after sunrise | Morning   |
| 2 hours after sunrise → 90 min before sunset  | Day       |
| 90 min before sunset → 2 hours after sunset   | Evening   |
| 2 hours after sunset → next morning           | Night     |

The switcher checks every 15 minutes. If your laptop was asleep overnight, the next check after wake refreshes that day’s Boston sunrise/sunset times.

It only reloads the wallpaper when the selected profile changes, so you avoid unnecessary flashing.

---

# 1. Create the folder structure

Open Terminal and run:

```bash
BASE="$HOME/Aerial Switcher"

mkdir -p "$BASE/Controls"
mkdir -p "$BASE/Scripts"
mkdir -p "$BASE/_Private/Profiles"
mkdir -p "$BASE/_Private/Backups"
mkdir -p "$BASE/_Private/State"
```

---

# 2. Back up your current wallpaper state

```bash
BASE="$HOME/Aerial Switcher"

cp "$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist" \
   "$BASE/_Private/Backups/Index.original.$(date +%Y%m%d-%H%M%S).plist"
```

---

# 3. Create the wallpaper apply helper

This applies one saved Tahoe profile, backs up the current wallpaper state, then reloads `WallpaperAgent`.

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Scripts/update_aerial.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/Aerial Switcher"
PRIVATE="$BASE/_Private"
BACKUPS="$PRIVATE/Backups"

PROFILE_PLIST="${1:-}"
DEST="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

mkdir -p "$BACKUPS"

if [[ -z "$PROFILE_PLIST" ]]; then
  echo "Usage: update_aerial.sh /path/to/Profile.plist" >&2
  exit 2
fi

if [[ ! -f "$PROFILE_PLIST" ]]; then
  echo "Profile not found: $PROFILE_PLIST" >&2
  exit 1
fi

if [[ -f "$DEST" ]]; then
  cp "$DEST" "$BACKUPS/Index.before-switch.$(date +%Y%m%d-%H%M%S).plist"
fi

cp "$PROFILE_PLIST" "$DEST"

# Reload the wallpaper engine.
killall WallpaperAgent 2>/dev/null || true
EOF

chmod +x "$BASE/Scripts/update_aerial.sh"
```

---

# 4. Create the Boston sunrise/sunset updater

This fetches today’s Boston sunrise/sunset and writes a local state file.

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Scripts/update_boston_sun_times.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/Aerial Switcher"
STATE="$BASE/_Private/State"

LAT="42.3601"
LNG="-71.0589"
TZ="America/New_York"

OUT="$STATE/boston_sun_times.env"
TMP="$OUT.tmp"

mkdir -p "$STATE"

API_URL="https://api.sunrise-sunset.org/json?lat=${LAT}&lng=${LNG}&date=today&formatted=0"

JSON="$(curl -fsSL "$API_URL")"

STATUS="$(/usr/bin/python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
print(data.get("status", ""))
' <<< "$JSON")"

if [[ "$STATUS" != "OK" ]]; then
  echo "Sunrise API returned status: $STATUS" >&2
  exit 1
fi

JSON_DATA="$JSON" /usr/bin/python3 > "$TMP" <<'PY'
import json
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

data = json.loads(os.environ["JSON_DATA"])
tz = ZoneInfo("America/New_York")

sunrise = datetime.fromisoformat(data["results"]["sunrise"]).astimezone(tz)
sunset = datetime.fromisoformat(data["results"]["sunset"]).astimezone(tz)

# Tunable windows:
# Morning starts 30 min before sunrise and lasts 2 hours after sunrise.
# Evening starts 90 min before sunset and lasts 2 hours after sunset.
morning_start = sunrise - timedelta(minutes=30)
day_start = sunrise + timedelta(hours=2)
evening_start = sunset - timedelta(minutes=90)
night_start = sunset + timedelta(hours=2)

def hm(dt):
    return dt.strftime("%H:%M")

print(f'SUNRISE="{hm(sunrise)}"')
print(f'SUNSET="{hm(sunset)}"')
print(f'MORNING_START="{hm(morning_start)}"')
print(f'DAY_START="{hm(day_start)}"')
print(f'EVENING_START="{hm(evening_start)}"')
print(f'NIGHT_START="{hm(night_start)}"')
print(f'UPDATED_AT="{datetime.now(tz).isoformat(timespec="seconds")}"')
PY

mv "$TMP" "$OUT"
EOF

chmod +x "$BASE/Scripts/update_boston_sun_times.sh"
```

Test it:

```bash
"$HOME/Aerial Switcher/Scripts/update_boston_sun_times.sh"
cat "$HOME/Aerial Switcher/_Private/State/boston_sun_times.env"
```

---

# 5. Create the main sun-aware dispatcher

This is the main script. It refreshes sun times if needed, chooses the correct wallpaper, and only reloads the wallpaper if the profile changed.

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Scripts/aerial_dispatch.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/Aerial Switcher"
SCRIPTS="$BASE/Scripts"
PRIVATE="$BASE/_Private"
PROFILES="$PRIVATE/Profiles"
STATE="$PRIVATE/State"

SUN_FILE="$STATE/boston_sun_times.env"
LAST_PROFILE_FILE="$STATE/last_applied_profile"

mkdir -p "$PROFILES" "$STATE"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

needs_sun_refresh() {
  if [[ ! -f "$SUN_FILE" ]]; then
    return 0
  fi

  local file_date
  local today
  file_date="$(date -r "$SUN_FILE" +%Y-%m-%d)"
  today="$(date +%Y-%m-%d)"

  [[ "$file_date" != "$today" ]]
}

if needs_sun_refresh; then
  log "Refreshing Boston sun times..."

  if ! "$SCRIPTS/update_boston_sun_times.sh"; then
    log "Could not refresh sun times; using existing file if available."

    if [[ ! -f "$SUN_FILE" ]]; then
      log "No sun-times file exists, falling back to fixed default schedule."

      cat > "$SUN_FILE" <<'FALLBACK'
SUNRISE="06:00"
SUNSET="18:00"
MORNING_START="05:30"
DAY_START="08:00"
EVENING_START="16:30"
NIGHT_START="20:00"
UPDATED_AT="fallback"
FALLBACK
    fi
  fi
fi

# shellcheck disable=SC1090
source "$SUN_FILE"

to_minutes() {
  local t="$1"
  local h="${t%%:*}"
  local m="${t##*:}"
  echo $((10#$h * 60 + 10#$m))
}

NOW="$(date +%H:%M)"

now_m="$(to_minutes "$NOW")"
morning_m="$(to_minutes "$MORNING_START")"
day_m="$(to_minutes "$DAY_START")"
evening_m="$(to_minutes "$EVENING_START")"
night_m="$(to_minutes "$NIGHT_START")"

if (( now_m >= morning_m && now_m < day_m )); then
  PROFILE="$PROFILES/Tahoe-Morning.plist"
elif (( now_m >= day_m && now_m < evening_m )); then
  PROFILE="$PROFILES/Tahoe-Day.plist"
elif (( now_m >= evening_m && now_m < night_m )); then
  PROFILE="$PROFILES/Tahoe-Evening.plist"
else
  PROFILE="$PROFILES/Tahoe-Night.plist"
fi

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
  log "Run Capture Wallpaper Profiles.command first."
  exit 1
fi

log "Now=$NOW sunrise=$SUNRISE sunset=$SUNSET applying $(basename "$PROFILE")"
"$SCRIPTS/update_aerial.sh" "$PROFILE"
echo "$PROFILE" > "$LAST_PROFILE_FILE"
EOF

chmod +x "$BASE/Scripts/aerial_dispatch.sh"
```

---

# 6. Add the guided profile capture command

This walks you through the one manual part: selecting each Tahoe wallpaper in System Settings, then copying the active profile.

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Capture Wallpaper Profiles.command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/Aerial Switcher"
PROFILES="$BASE/_Private/Profiles"
SRC="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

mkdir -p "$PROFILES"

capture_one() {
  local name="$1"
  local dest="$PROFILES/Tahoe-${name}.plist"

  echo
  echo "1. Open System Settings -> Wallpaper."
  echo "2. Select the Tahoe ${name} ocean wallpaper."
  echo "3. Wait until it is fully applied/downloaded."
  echo
  read -r -p "Press Return when Tahoe ${name} is active..."

  if [[ ! -f "$SRC" ]]; then
    echo "Could not find active wallpaper store:"
    echo "$SRC"
    exit 1
  fi

  cp "$SRC" "$dest"
  echo "Saved: $dest"
}

echo "Tahoe Wallpaper Profile Capture"
echo "==============================="
echo
echo "This will help you save the four Tahoe wallpaper profiles."
echo "It does not click anything automatically; it just waits while you select each one."
echo

capture_one "Morning"
capture_one "Day"
capture_one "Evening"
capture_one "Night"

echo
echo "Done. Saved profiles:"
ls -lh "$PROFILES"/Tahoe-*.plist

echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Capture Wallpaper Profiles.command"
```

---

# 7. Create the LaunchAgent

This runs the dispatcher at login and every 15 minutes while your Mac is awake.

```bash
BASE="$HOME/Aerial Switcher"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.$USER.aerial.switcher</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$BASE/Scripts/aerial_dispatch.sh</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>900</integer>

  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/aerial.switcher.out.log</string>

  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/aerial.switcher.err.log</string>
</dict>
</plist>
EOF
```

Load it:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"
launchctl kickstart -k "gui/$(id -u)/com.$USER.aerial.switcher"
```

---

# 8. Create the status script

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Scripts/status.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/Aerial Switcher"
PRIVATE="$BASE/_Private"
PROFILES="$PRIVATE/Profiles"
STATE="$PRIVATE/State"

SUN_FILE="$STATE/boston_sun_times.env"
LAST_PROFILE_FILE="$STATE/last_applied_profile"
LABEL="com.$USER.aerial.switcher"

echo "Tahoe Aerial Switcher Status"
echo "============================"
echo

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "Service: ON"
else
  echo "Service: OFF"
fi

echo

if [[ -f "$SUN_FILE" ]]; then
  echo "Sun schedule:"
  cat "$SUN_FILE"
else
  echo "Sun schedule: not created yet"
fi

echo

if [[ -f "$LAST_PROFILE_FILE" ]]; then
  echo "Last applied:"
  basename "$(cat "$LAST_PROFILE_FILE")"
else
  echo "Last applied: unknown"
fi

echo
echo "Saved profiles:"
found_any=0
for profile in "$PROFILES"/Tahoe-*.plist; do
  if [[ -f "$profile" ]]; then
    found_any=1
    echo "  - $(basename "$profile")"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "  none yet"
fi

echo
echo "Recent activity:"
if [[ -f "$HOME/Library/Logs/aerial.switcher.out.log" ]]; then
  tail -n 10 "$HOME/Library/Logs/aerial.switcher.out.log"
else
  echo "No output log yet."
fi

echo
echo "Recent errors:"
if [[ -f "$HOME/Library/Logs/aerial.switcher.err.log" ]]; then
  tail -n 10 "$HOME/Library/Logs/aerial.switcher.err.log"
else
  echo "No error log yet."
fi
EOF

chmod +x "$BASE/Scripts/status.sh"
```

---

# 9. Create Finder-click controls

## Turn On

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Turn On.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"
LABEL="com.$USER.aerial.switcher"

launchctl bootout "gui/$(id -u)" "\$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "\$PLIST"
launchctl kickstart -k "gui/$(id -u)/\$LABEL"

echo
echo "Tahoe Aerial Switcher is ON."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Turn On.command"
```

## Turn Off

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Turn Off.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"

launchctl bootout "gui/$(id -u)" "\$PLIST" 2>/dev/null || true

echo
echo "Tahoe Aerial Switcher is OFF."
echo "Your current wallpaper will stay as-is."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Turn Off.command"
```

## Switch Now

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Switch Now.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/aerial_dispatch.sh"

echo
echo "Checked sun times and applied the current wallpaper if needed."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Switch Now.command"
```

## Show Status

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Show Status.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/status.sh"

echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Show Status.command"
```

## Show Logs

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Show Logs.command" <<EOF
#!/usr/bin/env bash

touch "$HOME/Library/Logs/aerial.switcher.out.log"
touch "$HOME/Library/Logs/aerial.switcher.err.log"

open -a Console "$HOME/Library/Logs/aerial.switcher.out.log" 2>/dev/null || open "$HOME/Library/Logs/aerial.switcher.out.log"
open -a Console "$HOME/Library/Logs/aerial.switcher.err.log" 2>/dev/null || open "$HOME/Library/Logs/aerial.switcher.err.log"
EOF

chmod +x "$BASE/Controls/Show Logs.command"
```

## Open Config Folder

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Open Config Folder.command" <<EOF
#!/usr/bin/env bash
open "$BASE"
EOF

chmod +x "$BASE/Controls/Open Config Folder.command"
```

---

# 10. Add manual wallpaper controls

These are useful for testing.

## Use Morning

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Use Morning.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/update_aerial.sh" "$BASE/_Private/Profiles/Tahoe-Morning.plist"
echo "$BASE/_Private/Profiles/Tahoe-Morning.plist" > "$BASE/_Private/State/last_applied_profile"

echo
echo "Applied Morning."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF
```

## Use Day

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Use Day.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/update_aerial.sh" "$BASE/_Private/Profiles/Tahoe-Day.plist"
echo "$BASE/_Private/Profiles/Tahoe-Day.plist" > "$BASE/_Private/State/last_applied_profile"

echo
echo "Applied Day."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF
```

## Use Evening

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Use Evening.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/update_aerial.sh" "$BASE/_Private/Profiles/Tahoe-Evening.plist"
echo "$BASE/_Private/Profiles/Tahoe-Evening.plist" > "$BASE/_Private/State/last_applied_profile"

echo
echo "Applied Evening."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF
```

## Use Night

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Use Night.command" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$BASE/Scripts/update_aerial.sh" "$BASE/_Private/Profiles/Tahoe-Night.plist"
echo "$BASE/_Private/Profiles/Tahoe-Night.plist" > "$BASE/_Private/State/last_applied_profile"

echo
echo "Applied Night."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF
```

Make them executable:

```bash
chmod +x "$HOME/Aerial Switcher/Controls/"*.command
```

---

# 11. Add safe uninstall control

This stops the LaunchAgent, removes its plist, and moves `~/Aerial Switcher` to the Trash.

```bash
BASE="$HOME/Aerial Switcher"

cat > "$BASE/Controls/Uninstall.command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"
AERIAL_DIR="$HOME/Aerial Switcher"

echo "This will uninstall the Tahoe Aerial Switcher."
echo
echo "It will:"
echo "  - stop the LaunchAgent"
echo "  - remove the LaunchAgent plist"
echo "  - move $AERIAL_DIR to the Trash"
echo
echo "It will NOT delete Apple's built-in wallpapers."
echo "It will NOT change your current wallpaper after uninstalling."
echo
read -r -p "Type UNINSTALL to continue: " confirm

if [[ "$confirm" != "UNINSTALL" ]]; then
  echo
  echo "Cancelled."
  echo
  read -n 1 -s -r -p "Press any key to close..."
  exit 0
fi

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

osascript <<APPLESCRIPT
tell application "Finder"
  if exists POSIX file "$AERIAL_DIR" then
    delete POSIX file "$AERIAL_DIR"
  end if
end tell
APPLESCRIPT

echo
echo "Uninstalled. The Aerial Switcher folder was moved to the Trash."
echo
read -n 1 -s -r -p "Press any key to close..."
EOF

chmod +x "$BASE/Controls/Uninstall.command"
```

---

# 12. Open the Controls folder

```bash
open "$HOME/Aerial Switcher/Controls"
```

You can drag this folder to your Finder sidebar or Dock.

You should now have:

```text
Capture Wallpaper Profiles.command
Open Config Folder.command
Show Logs.command
Show Status.command
Switch Now.command
Turn Off.command
Turn On.command
Uninstall.command
Use Day.command
Use Evening.command
Use Morning.command
Use Night.command
```

---

# 13. First-time setup flow

After creating everything above:

1. Open the Controls folder:

   ```bash
   open "$HOME/Aerial Switcher/Controls"
   ```

2. Double-click:

   ```text
   Capture Wallpaper Profiles.command
   ```

3. Follow the prompts to capture Morning, Day, Evening, and Night.

4. Double-click:

   ```text
   Switch Now.command
   ```

5. Double-click:

   ```text
   Show Status.command
   ```

6. Confirm that the service says:

   ```text
   Service: ON
   ```

If it is off, double-click:

```text
Turn On.command
```

---

# 14. Tune the transition windows

Edit:

```bash
nano "$HOME/Aerial Switcher/Scripts/update_boston_sun_times.sh"
```

Find:

```python
morning_start = sunrise - timedelta(minutes=30)
day_start = sunrise + timedelta(hours=2)
evening_start = sunset - timedelta(minutes=90)
night_start = sunset + timedelta(hours=2)
```

Example: longer morning/evening ambience:

```python
morning_start = sunrise - timedelta(minutes=45)
day_start = sunrise + timedelta(hours=3)
evening_start = sunset - timedelta(hours=2)
night_start = sunset + timedelta(minutes=90)
```

Then refresh:

```bash
"$HOME/Aerial Switcher/Scripts/update_boston_sun_times.sh"
"$HOME/Aerial Switcher/Scripts/aerial_dispatch.sh"
```

---

# 15. Change the check frequency

The LaunchAgent currently checks every 15 minutes:

```xml
<key>StartInterval</key>
<integer>900</integer>
```

To check every 5 minutes, change `900` to `300`.

Edit:

```bash
nano "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"
```

Then reload:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.$USER.aerial.switcher.plist"
launchctl kickstart -k "gui/$(id -u)/com.$USER.aerial.switcher"
```

I’d keep `900`. The dispatcher skips unnecessary reloads, so 5 minutes is okay, but 15 minutes is gentler.

---

# 16. Sharing with another Mac user

You can share this folder before running the capture process.

Share:

```text
Aerial Switcher/
  Controls/
  Scripts/
```

Do not share:

```text
Aerial Switcher/_Private/
```

To make a clean shareable zip:

```bash
cd "$HOME"
zip -r "Aerial Switcher Shareable.zip" "Aerial Switcher" -x "Aerial Switcher/_Private/*"
```

The other Mac user should copy the folder to their home folder, then run:

```text
Capture Wallpaper Profiles.command
```

on their own Mac.

---

# 17. Quick troubleshooting

## Check status

```bash
"$HOME/Aerial Switcher/Scripts/status.sh"
```

## Force-refresh Boston sun times

```bash
"$HOME/Aerial Switcher/Scripts/update_boston_sun_times.sh"
```

## Force the correct wallpaper right now

```bash
"$HOME/Aerial Switcher/Scripts/aerial_dispatch.sh"
```

## Check recent activity

```bash
tail -n 50 "$HOME/Library/Logs/aerial.switcher.out.log"
```

## Check recent errors

```bash
tail -n 50 "$HOME/Library/Logs/aerial.switcher.err.log"
```

## Confirm LaunchAgent is loaded

```bash
launchctl print "gui/$(id -u)/com.$USER.aerial.switcher"
```

---

# 18. Notes on risk

This is low-risk and reversible, but it uses macOS’s private wallpaper state file:

```text
~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
```

The main risks are:

* macOS updates could change the wallpaper storage format
* the wallpaper may briefly reload when switching
* captured profiles may not be portable between Macs
* if something gets weird, turn it off or uninstall it

Use:

```text
Turn Off.command
```

to stop the automation without deleting anything.

Use:

```text
Uninstall.command
```

to remove the setup and move the folder to the Trash.


Here’s a `README.txt` you can include at the top level of the folder:

```text
Tahoe Ocean Dynamic Wallpaper Switcher
======================================

This folder contains a small macOS LaunchAgent-based setup for automatically
switching between the four Tahoe ocean animated wallpapers based on approximate
time of day.

It is designed for macOS Tahoe and uses Boston, MA sunrise/sunset times by
default.


What It Does
------------

The switcher uses four saved Tahoe wallpaper profiles:

  - Morning
  - Day
  - Evening
  - Night

It checks every 15 minutes while your Mac is awake.

If your laptop was asleep overnight, the next check after wake will refresh
today's Boston sunrise/sunset times and apply the appropriate wallpaper.

Approximate default schedule:

  Morning:  30 minutes before sunrise -> 2 hours after sunrise
  Day:      2 hours after sunrise -> 90 minutes before sunset
  Evening:  90 minutes before sunset -> 2 hours after sunset
  Night:    2 hours after sunset -> next morning

The switcher only reloads the wallpaper when the selected profile changes, so it
should normally reload the wallpaper about four times per day.


Folder Structure
----------------

Aerial Switcher/
  Controls/
    Finder-clickable commands.

  Scripts/
    Shell scripts used by the controls and LaunchAgent.

  _Private/
    Machine-specific and user-specific generated files.

_Private/ is intentionally separated from the shareable parts of the setup.

Safe-ish to share:

  Controls/
  Scripts/
  README.txt

Do not share, or regenerate per Mac:

  _Private/


First-Time Setup
----------------

1. Put this folder here:

     ~/Aerial Switcher

2. Open:

     ~/Aerial Switcher/Controls

3. Double-click:

     Capture Wallpaper Profiles.command

4. Follow the prompts.

   For each of Morning, Day, Evening, and Night:

     - Open System Settings -> Wallpaper
     - Select the matching Tahoe ocean wallpaper
     - Wait until it is fully applied/downloaded
     - Return to the command window and press Return

5. Double-click:

     Switch Now.command

6. Double-click:

     Show Status.command

7. Confirm that the service says:

     Service: ON

If it says OFF, double-click:

     Turn On.command


Finder Controls
---------------

Capture Wallpaper Profiles.command

  Walks you through capturing the four Tahoe wallpaper profiles from System
  Settings. This is the one manual part of setup.

Turn On.command

  Loads the LaunchAgent and starts automatic switching.

Turn Off.command

  Stops automatic switching. Your current wallpaper stays as-is.

Switch Now.command

  Immediately checks the current sunrise/sunset schedule and applies the correct
  wallpaper if needed.

Show Status.command

  Shows whether the service is on, today's sun schedule, the last applied
  wallpaper, saved profiles, and recent log output.

Show Logs.command

  Opens the output and error logs.

Open Config Folder.command

  Opens the main Aerial Switcher folder.

Use Morning.command
Use Day.command
Use Evening.command
Use Night.command

  Manually apply a specific wallpaper profile. Useful for testing.

Uninstall.command

  Stops the LaunchAgent, removes the LaunchAgent plist, and moves the Aerial
  Switcher folder to the Trash. It does not delete Apple's built-in wallpapers
  and does not change your current wallpaper after uninstalling.


How It Works
------------

The active macOS wallpaper state is stored in:

  ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist

This setup captures four copies of that file, one for each Tahoe ocean variant.

The main dispatcher script is:

  Scripts/aerial_dispatch.sh

It:

  1. Checks whether today's Boston sunrise/sunset data exists.
  2. Refreshes it if missing or stale.
  3. Chooses Morning, Day, Evening, or Night.
  4. Applies the selected profile only if it changed.

The LaunchAgent lives here:

  ~/Library/LaunchAgents/com.$USER.aerial.switcher.plist

The LaunchAgent runs the dispatcher:

  - when loaded
  - every 15 minutes while your Mac is awake


Changing the Location
---------------------

By default, sunrise/sunset is based on Boston, MA:

  Latitude:  42.3601
  Longitude: -71.0589
  Timezone:  America/New_York

To change this, edit:

  Scripts/update_boston_sun_times.sh

Look for:

  LAT="42.3601"
  LNG="-71.0589"
  TZ="America/New_York"

Replace those values with your preferred location.


Changing the Transition Windows
-------------------------------

Edit:

  Scripts/update_boston_sun_times.sh

Look for:

  morning_start = sunrise - timedelta(minutes=30)
  day_start = sunrise + timedelta(hours=2)
  evening_start = sunset - timedelta(minutes=90)
  night_start = sunset + timedelta(hours=2)

For example, to make morning and evening last longer:

  morning_start = sunrise - timedelta(minutes=45)
  day_start = sunrise + timedelta(hours=3)
  evening_start = sunset - timedelta(hours=2)
  night_start = sunset + timedelta(minutes=90)

After editing, run:

  Scripts/update_boston_sun_times.sh
  Scripts/aerial_dispatch.sh


Changing the Check Frequency
----------------------------

The LaunchAgent checks every 15 minutes by default:

  StartInterval = 900

To change it, edit:

  ~/Library/LaunchAgents/com.$USER.aerial.switcher.plist

Use:

  300   for every 5 minutes
  900   for every 15 minutes
  1800  for every 30 minutes

After editing the LaunchAgent, reload it by double-clicking:

  Turn On.command


Troubleshooting
---------------

Use:

  Show Status.command

or run:

  ~/Aerial Switcher/Scripts/status.sh

Useful logs:

  ~/Library/Logs/aerial.switcher.out.log
  ~/Library/Logs/aerial.switcher.err.log

To force a sun-time refresh:

  ~/Aerial Switcher/Scripts/update_boston_sun_times.sh

To force wallpaper selection now:

  ~/Aerial Switcher/Scripts/aerial_dispatch.sh

To stop the automation without deleting anything:

  Turn Off.command

To remove the setup:

  Uninstall.command


Risks and Caveats
-----------------

This setup is low-risk and reversible, but it relies on macOS's private
wallpaper state file:

  ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist

That means:

  - A future macOS update could change how wallpaper state is stored.
  - The wallpaper may briefly reload or flash when switching.
  - Captured wallpaper profiles may not work reliably on another Mac.
  - Each Mac should capture its own profiles using Capture Wallpaper Profiles.command.

The setup does not delete Apple's built-in wallpapers.

Uninstalling does not change your current wallpaper. It simply stops the
automation and moves the Aerial Switcher folder to the Trash.


Sharing This Folder
-------------------

To share this setup with another Mac user, share:

  Controls/
  Scripts/
  README.txt

Do not share:

  _Private/

Each Mac should generate its own _Private/ contents by running:

  Capture Wallpaper Profiles.command

To make a shareable zip from Terminal:

  cd "$HOME"
  zip -r "Aerial Switcher Shareable.zip" "Aerial Switcher" -x "Aerial Switcher/_Private/*"
```
