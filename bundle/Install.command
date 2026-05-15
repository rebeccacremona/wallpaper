#!/usr/bin/env bash
# Setup / reapply for the Tahoe Aerial Switcher. Safe to re-run any time:
# skips wallpaper capture if profiles already exist; always rewrites the
# LaunchAgent plist with the latest settings and reloads.

COMMAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMAND_DIR/Scripts/lib/finder_command.sh"

ensure_private_dirs

xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

write_launch_agent_plist() {
  mkdir -p "$(dirname "$PLIST")"
  local script_path label log_out log_err
  script_path="$(xml_escape "$SCRIPTS/aerial_dispatch.sh")"
  label="$(xml_escape "$LABEL")"
  log_out="$(xml_escape "$LOG_OUT")"
  log_err="$(xml_escape "$LOG_ERR")"

  cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${script_path}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>${CHECK_INTERVAL_SECONDS}</integer>
  <key>StandardOutPath</key>
  <string>${log_out}</string>
  <key>StandardErrorPath</key>
  <string>${log_err}</string>
</dict>
</plist>
PLISTEOF
}

reload_launch_agent() {
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  launchctl kickstart -k "gui/$(id -u)/$LABEL"
}

mkdir -p "$(dirname "$LOG_OUT")"

# Detect first-time install: no profiles captured yet.
first_run="no"
if ! all_profiles_present; then
  first_run="yes"
fi

if [[ "$first_run" == "yes" ]]; then
  cat <<'WELCOME'
Welcome to the Tahoe Aerial Switcher!
=====================================

This will set up automatic wallpaper switching on your Mac, so your
desktop cycles between the four Tahoe ocean variants (Morning, Day,
Evening, and Night) based on the sun in your area.

Setup is two steps:

  1. (Optional) Tell me your city and how long you'd like the morning
     and evening transitions to feel. If you skip this, I'll use:
         - Location:  Boston, Massachusetts (America/New_York)
         - Schedule:  Normal -- morning ~30 min before sunrise to
                      ~2 hr after, evening ~90 min before sunset to
                      ~2 hr after
         - Check:     every 15 minutes while your Mac is awake
     You can always change any of these later via the Controls folder.

  2. Pick each Tahoe ocean wallpaper in System Settings, one at a
     time. I'll save a snapshot after each.

Then I'll start a small background helper that switches your wallpaper
four times a day automatically.

WELCOME

  read -r -p "Customize your location and schedule first? (y/N): " want_config
  want_config="${want_config:-N}"
  if [[ "$want_config" =~ ^[Yy] ]]; then
    divider
    # Tell configure.sh not to ask "Apply now?" or re-exec Install --
    # we'll handle the apply ourselves below.
    CONFIGURE_FROM_INSTALL=1 "$SCRIPTS/configure.sh"
    # Re-source common.sh so we pick up any LAT/LNG/TZ/CHECK_INTERVAL changes.
    source "$SCRIPTS/lib/common.sh"
  fi
else
  cat <<'WELCOMEBACK'
Tahoe Aerial Switcher
=====================

Welcome back! All four wallpaper profiles are already saved, so this
will just re-apply your latest settings (rewrite the background helper
and reload it). No wallpaper picking needed this time.

WELCOMEBACK
fi

divider

# 1. Capture profiles if any are missing.
if all_profiles_present; then
  echo "Wallpaper profiles already captured. Skipping that step."
else
  echo "Time to capture your four Tahoe ocean wallpapers."
  "$CONTROLS/Capture Wallpaper Profiles.command"
  if ! all_profiles_present; then
    echo
    echo "I didn't get all four profiles. Stopping here so nothing else changes."
    echo "Run this Install.command again whenever you're ready."
    exit 1
  fi
fi

divider

# 2. Write the LaunchAgent plist using runtime $HOME/$USER (not author-side values).
echo "Setting up the background helper..."
write_launch_agent_plist
reload_launch_agent
echo "Done -- it'll check the time every ${CHECK_INTERVAL_SECONDS} seconds while your Mac is awake."

# 3. Force a fresh sun-times computation so any location change in
#    config.env takes effect immediately (the dispatcher's normal
#    "refresh once per day" check would otherwise keep using yesterday's
#    location until tomorrow).
rm -f "$SUN_FILE"

divider

# 4. Run one immediate dispatch so the wallpaper matches the current time.
echo "Picking the right wallpaper for right now..."
"$SCRIPTS/aerial_dispatch.sh" || true

divider

cat <<DONE
All set!

You can use any of these from the Controls folder:

  - Show Status        See what's running and today's schedule
  - Switch Now         Re-check the time and switch if needed
  - Change Settings    Update your city, schedule, or check frequency
  - Turn Off           Stop the automatic switching
  - Use Morning / Day / Evening / Night   Manually pick a variant
  - Reset Wallpaper to Default            Escape hatch if things go wrong
  - Uninstall          Remove the switcher entirely
DONE
