Tahoe Aerial Switcher
=====================

Automatically cycles your Mac's desktop wallpaper between the four
Tahoe ocean variants (Morning, Day, Evening, Night) based on the
position of the sun at your configured location. Designed for
macOS Tahoe (26).

Note: Tahoe's "dynamic" wallpapers only animate on the lock screen,
not on the desktop. This tool switches between four still-frame
variants throughout the day so your desktop changes look without
needing motion.


First-Time Setup
----------------

1. (Recommended) Move this whole "Aerial Switcher" folder into your
   home folder. It works from anywhere, but ~/Aerial Switcher is
   tidy and matches all the README references.

2. Right-click "Install.command" and choose "Open". You'll get a
   security warning the first time -- click "Open" to confirm.

   (Why right-click? macOS Gatekeeper warns about scripts that
   weren't downloaded from the App Store. Right-click + Open is the
   one-time bypass. After that, double-clicking works normally.)

3. Follow the on-screen prompts. For each of Morning, Day, Evening,
   and Night, the installer will ask you to:

     a. Open System Settings -> Wallpaper.
     b. Click the matching Tahoe ocean variant.
     c. Wait for it to finish downloading / applying.
     d. Return to the Terminal window and press Return.

4. The installer then loads a background service (a "LaunchAgent")
   that re-checks the time of day every 15 minutes and switches the
   wallpaper when needed.

That's it. You're done.


How It Works
------------

The macOS wallpaper system stores its current state in a private
file:

  ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist

When you select a wallpaper in System Settings, that file is
rewritten. The "Capture Wallpaper Profiles.command" step saves a
copy of that file for each of the four Tahoe ocean variants. The
dispatcher then swaps in the matching copy and reloads
WallpaperAgent throughout the day.

Sun times (sunrise / sunset) are computed locally using the NOAA
solar position formula. No network calls.


Folder Layout
-------------

  Install.command          One-double-click setup. Idempotent;
                           re-run after editing config.env.

  README.txt               This file.

  Controls/                Finder-clickable commands. See "Controls"
                           below.

  Scripts/                 The actual logic.
    aerial_dispatch.sh       Picks today's profile, applies it.
    update_aerial.sh         Swaps in one profile + reloads.
    update_sun_times.sh      Recomputes today's sunrise/sunset.
    compute_sun_times.py     NOAA formula (stdlib only).
    status.sh                Reports current state.
    lib/config.env           User-editable settings (see below).
    lib/common.sh            Internal: shared paths and helpers.
    lib/finder_command.sh    Internal: shared boilerplate for
                              Controls/*.command files.

  _Private/                Generated on this Mac. NOT shareable.
    Profiles/                Captured wallpaper profile plists.
    Backups/                 Snapshots taken before each switch.
    State/                   Today's sun times, last-applied marker.


Controls
--------

All in the Controls/ folder. Double-click to run (right-click ->
Open the very first time, per Gatekeeper note above).

  Capture Wallpaper Profiles.command
      Walk through capturing the four wallpaper profiles. Idempotent
      -- re-run any time to refresh captures (useful if a macOS
      update breaks the previous ones).

  Turn On.command
      Load the LaunchAgent. The switcher runs in the background.

  Turn Off.command
      Stop the LaunchAgent. Your current wallpaper stays as-is.

  Switch Now.command
      Force an immediate check + apply.

  Show Status.command
      Print bundle location, service on/off, today's sun schedule,
      last-applied profile, recent log lines.

  Show Logs.command
      Open the dispatcher's stdout / stderr logs in Console.

  Open Config Folder.command
      Reveal the bundle in Finder.

  Change Settings.command
      Interactive prompts to update your city, schedule, and check
      frequency. Looks up cities online (one-time geocoding query
      per change), no need to know your latitude/longitude.

  Use Morning.command
  Use Day.command
  Use Evening.command
  Use Night.command
      Manually apply one specific profile (useful for testing).

  Reset Wallpaper to Default.command
      Nuclear escape hatch. If something has gone wrong with your
      wallpaper system (e.g. after a macOS update broke the captured
      profiles), this snapshots your current wallpaper state, moves
      Index.plist aside, and lets macOS regenerate it from defaults.
      You then re-pick a wallpaper in System Settings to confirm,
      and (if you want to keep using the switcher) re-run Capture.
      Reversible -- nothing is deleted, only moved aside.

  Uninstall.command
      Stop the LaunchAgent, remove its plist, and move this folder
      to the Trash. Does NOT change your current wallpaper. If your
      wallpaper system is misbehaving, run Reset first, then
      Uninstall.


Editing the Config
------------------

The easiest way: double-click "Change Settings.command" in the
Controls folder. It'll prompt you for:

  - Your city (looked up online, no need to know your latitude /
    longitude / timezone).
  - Schedule preset (short / normal / long transitions).
  - Check frequency (5 / 15 / 30 minutes).

Each prompt has a "keep current" option, so you can update only what
you care about. When you save, it offers to apply the change
immediately (which just reloads the background helper -- it does NOT
re-prompt for wallpaper captures).

If you'd rather edit by hand, all tunables live in:

  Scripts/lib/config.env

The keys are LAT, LNG, TZ, MORNING_OFFSET_MIN, DAY_OFFSET_MIN,
EVENING_OFFSET_MIN, NIGHT_OFFSET_MIN, and CHECK_INTERVAL_SECONDS.
Window offsets are minutes relative to sunrise / sunset (negative
means "before"). After editing by hand, re-run Install.command to
apply.


Recovery
--------

If your wallpaper system gets into a weird state -- typically after
a macOS update breaks the captured profile schema -- there are
three escalating recovery options:

  1. Roll back the most recent switch. Each switch backs up the
     previous Index.plist into _Private/Backups/. To restore, copy
     the most recent Index.before-switch.*.plist back over
     ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
     and run "killall WallpaperAgent".

  2. Restore the original (pre-installation) state. There's an
     Index.original.first-capture.plist saved on first capture.
     Same restore process as above. Note: if you've upgraded macOS
     since installing this tool, this backup may also be schema-
     mismatched and not work.

  3. Nuclear: run "Reset Wallpaper to Default.command". This is
     immune to schema drift because it lets macOS regenerate the
     Index.plist from current-OS defaults. Then re-pick a wallpaper
     in System Settings, and re-run Capture if you want to keep
     using the switcher.


Sharing
-------

You can share this whole folder with another Mac user, but they
should NOT inherit your _Private/ folder (it contains profiles
captured against YOUR macOS install -- they may not work on theirs,
and even if they do, schema drift will get them eventually).

The simplest path: get the original Aerial Switcher Shareable.zip
from whoever you got this from, and have them extract + run
Install.command. The installer will guide them through capturing
their own profiles.


Caveats
-------

  - This tool pokes a private macOS file. Apple could change the
    schema in any point release. The "Reset Wallpaper to Default"
    control exists as the escape hatch for that case.

  - Each switch causes a brief desktop flash as WallpaperAgent
    reloads. This is unavoidable with the current technique.

  - The LaunchAgent plist references this folder's current absolute
    path. If you move the folder later, just re-run Install.command
    and the new path will be picked up automatically.

  - First-time wallpaper capture requires manually clicking through
    System Settings -- there is no Apple-supplied API to script
    this.

  - Single-display configurations only.
