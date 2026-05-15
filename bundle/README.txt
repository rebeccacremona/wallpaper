Tahoe Aerial Switcher
=====================

This makes your Mac's desktop wallpaper change throughout the day,
cycling between the four Tahoe ocean variants -- Morning, Day,
Evening, and Night -- so your desktop visually matches the time of
day in your area.

Set it up once, and it runs in the background. You can change your
settings, pause it, or remove it any time.

Designed for macOS Tahoe (26).


Heads up about animation
------------------------

On macOS Tahoe, the "dynamic" Tahoe ocean wallpapers only animate on
the lock screen. On the desktop, you just see a still image.


------------------------------------------------------------
1. Install (about 2 minutes)
------------------------------------------------------------

Step 1. Move the "Aerial Switcher" folder into your home folder.
        (Recommended for tidiness. It works from anywhere, but the
        instructions all assume ~/Aerial Switcher.)

Step 2. Open the "Aerial Switcher" folder.

Step 3. RIGHT-click on "Install.command" and choose "Open."

        You'll see a security warning -- this is normal for any
        script that wasn't downloaded from the App Store. Click
        "Open" to confirm.

        After this first time, you can just double-click anything in
        the Controls folder normally.

Step 4. The installer welcomes you and asks if you'd like to
        customize your location and schedule.

        - If you live in or near Boston, just press Return to use
          the defaults.

        - If you live elsewhere, press 'y' and Return. You'll be
          prompted for your city (looked up online), how long the
          morning and evening transitions should last, and how often
          to check the clock.

Step 5. The installer walks you through saving each of the four
        Tahoe ocean wallpapers, one at a time. For each one:

        a. Open System Settings -> Wallpaper.
        b. Click the matching Tahoe ocean variant (Morning, Day,
           Evening, or Night).
        c. Wait until the new wallpaper appears on your desktop.
        d. Switch back to the Terminal window and press Return.

Step 6. Done! A small background helper takes over and re-checks the
        time every 15 minutes, switching the wallpaper as needed.


------------------------------------------------------------
2. Day-to-day use
------------------------------------------------------------

You don't have to do anything. The wallpaper switches itself four
times a day, around sunrise and sunset.

But the Controls folder has things you can do whenever you want:

  Show Status.command
      See if it's running, today's sunrise/sunset, and what wallpaper
      is currently in use.

  Switch Now.command
      Don't want to wait 15 minutes? This re-checks the time and
      applies the right wallpaper immediately.

  Change Settings.command
      Update your city, schedule, or check frequency. Walks you
      through step-by-step. (See section 3 for details.)

  Turn Off.command
      Pause the automatic switching. Your current wallpaper stays
      put until you turn it back on.

  Turn On.command
      Resume the automatic switching after you've turned it off.

  Use Morning.command
  Use Day.command
  Use Evening.command
  Use Night.command
      Manually apply a specific wallpaper. Useful if you just want
      to override the schedule for the moment.

  Open Config Folder.command
      Reveal the Aerial Switcher folder in Finder.

  Show Logs.command
      Open the technical log files. Mostly useful if you hit a
      problem and someone's helping you troubleshoot.


------------------------------------------------------------
3. Changing your settings
------------------------------------------------------------

Easiest way: double-click "Change Settings.command" in the Controls
folder. It'll ask you three things, in order:

  1. Your city.
     Type any city name. The tool looks it up online and shows you a
     numbered list of matches (so "Boston" lets you pick MA, GA, NY,
     etc.). Press a number to pick. You don't need to know your
     latitude, longitude, or timezone.

  2. Schedule preset.
     - Short:  Crisp transitions, brief morning and evening windows.
     - Normal: The default. Comfortable transitions around sunrise
               and sunset.
     - Long:   Extended ambience. Mornings linger after sunrise,
               evenings start well before sunset.

  3. Check frequency.
     How often the background helper checks the clock. 5, 15, or 30
     minutes. The default (15) is gentle and responsive enough.

For each prompt, press Return to keep what you currently have. None
of your changes are saved until you confirm at the end.


------------------------------------------------------------
4. If something looks wrong
------------------------------------------------------------

Most common cause: macOS updated, and now the wallpaper looks weird
or stops changing.

Try this, in order:

  1. Double-click "Show Status.command" to see what's going on. If
     you can spot the issue from there, great.

  2. Double-click "Reset Wallpaper to Default.command" and follow
     the prompts. This puts your wallpaper system back to a clean
     state and turns off the background helper. It is reversible --
     nothing is deleted, only renamed and snapshotted.

     After Reset, the on-screen instructions will guide you through
     either re-saving the wallpaper profiles (to keep using the
     switcher) or uninstalling (if you're done with it).

  3. If you'd rather just have someone look at the logs, double-click
     "Show Logs.command".


------------------------------------------------------------
5. How to remove it
------------------------------------------------------------

Double-click "Uninstall.command" and confirm.

What it does:

  - Stops the background helper.
  - Removes the helper from your system.
  - Moves this whole folder to the Trash (with a timestamp suffix
    in case you ever want to recover it).

What it does NOT do:

  - Won't change your current wallpaper. Whatever is on screen at
    uninstall time stays there.
  - Won't delete any of Apple's built-in wallpapers.

If your wallpaper system is broken (e.g., the wallpaper is stuck or
won't change), run "Reset Wallpaper to Default.command" first, then
Uninstall.


------------------------------------------------------------
6. Things worth knowing
------------------------------------------------------------

  - Each switch causes a brief flicker as macOS reloads the
    wallpaper. This is unavoidable with the current approach.

  - The first time you double-click any .command file, you'll get
    a "from an unidentified developer" warning. Right-click the
    file and choose Open instead -- you only need to do this once
    per file.

  - This works with one display at a time. If you have multiple
    monitors, the wallpaper may only switch on one of them.

  - All your settings, saved wallpaper profiles, and logs live
    inside the "_Private" folder. That folder is specific to your
    Mac and is never shared if you give the zip to someone else.

  - Sun times are computed locally on your Mac (no recurring
    network calls). The only time it touches the internet is when
    you use Change Settings to look up a new city.


That's everything. Enjoy your changing desktop.
