# Revisions to the initial plan

This document compares the implementation in this repo against the
original [`chatgpt_initial_plan.md`](chatgpt_initial_plan.md) and
explains the material design changes. It is not a chronological change
log; the focus is "what's different now vs the starting point, and
why."

For Tahoe-specific behaviors we accept, residual risks inherent to the
technique, and open future work, see
[`caveats_and_future_work.md`](caveats_and_future_work.md).

## Goal

Automatically cycle the macOS Tahoe (26) desktop wallpaper between the
four time-of-day Tahoe ocean variants (Morning, Day, Evening, Night)
on a sun-aware schedule, and bundle the result so a non-technical user
can install it with a few clicks.

## What we kept

The core wallpaper-switching mechanism is unchanged from the initial
plan: capture the active
`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`
for each of the four Tahoe variants, swap in the matching one when the
time-of-day window changes, and `killall WallpaperAgent` to reload.

We researched alternatives before committing:

| Method | Verdict on Tahoe |
|---|---|
| AppleScript / `osascript` `set desktop picture` | Image-only; cannot accept aerial assets |
| Shortcuts.app | Image-only |
| `defaults write com.apple.desktop` | Long deprecated |
| [`desktoppr`](https://github.com/scriptingosx/desktoppr) | Uses `setDesktopImageURL` which has no aerial code path |
| [`macos-wallpaper`](https://github.com/sindresorhus/macos-wallpaper) | Static images only |
| `PlistBuddy` surgical edit of `Index.plist` | Works, but adds bootstrapping complexity for marginal benefit |
| `Index.plist` swap + `killall WallpaperAgent` | What we use. Same mechanism the community converged on across Sonoma → Sequoia → Tahoe |

Apple DTS has stated on the developer forums that there is no
supported API for full wallpaper management, and that this is unlikely
to change for security reasons. So `Index.plist` poking is the
documented workaround for the entire era.

We also kept:

- Morning / Day / Evening / Night window semantics.
- 15-minute LaunchAgent cadence (with `StartInterval`).
- All the Finder-clickable controls (Turn On/Off, Switch Now, Use *,
  Status, Logs, Uninstall).
- Per-switch backups of `Index.plist` before each swap.
- Manual capture as the way to populate profiles. There is no clean
  alternative given no programmatic API exists for selecting aerial
  wallpapers.

## What we changed and why

### Distribution: paste-into-Terminal recipe → versioned source repo

**Original.** Roughly 18 sections of bash heredocs in one markdown
file. To install, you opened Terminal and pasted them in order. Each
`<<EOF` heredoc was unquoted, so `$HOME`, `$USER`, and `$(id -u)` got
interpolated *at paste time on the author's Mac* and baked into the
resulting `.command` files. The bundle was non-portable: a copy
generated on one Mac wouldn't work on another.

**Now.** Source files live in [`bundle/`](../bundle). [`build_zip.sh`](../build_zip.sh)
produces `Aerial Switcher Shareable.zip`. Recipients extract and
right-click `Install.command` → Open. All variable expansion happens
at runtime on the recipient's machine via the shared
[`bundle/Scripts/lib/finder_command.sh`](../bundle/Scripts/lib/finder_command.sh)
boilerplate. The LaunchAgent plist is the only file generated at
install time, and it's generated on the recipient's Mac with their
actual `$HOME`/`$USER`/bundle path.

### Sun times: network API → local NOAA computation

**Original.** Once-per-day call to `sunrise-sunset.org`.

**Now.** [`bundle/Scripts/compute_sun_times.py`](../bundle/Scripts/compute_sun_times.py)
implements NOAA's solar position formula in ~50 lines of stdlib
Python. No network, no API key, works offline. Verified accuracy:
~2 min at mid-latitudes, ~20 min at 64°N (Reykjavik). Removes an
entire class of failure mode (rate limits, outages, corporate
firewalls, API deprecation).

### Configuration: single editable file → shipped defaults + per-Mac overrides

**Original.** A single `config.env` users would edit by hand. Two
problems: (1) author's edits leaked into any zip they built for a
recipient, who'd see the author's location as their own "default";
(2) hand-editing `LAT="42.36"` is hostile to non-technical users.

**Now.** Two-file config:

- [`bundle/Scripts/lib/config.env`](../bundle/Scripts/lib/config.env) —
  the *shipped defaults* (Boston, Normal preset, 15-min check). Travels
  with the bundle.
- `bundle/_Private/State/user_config.env` — *per-Mac sparse overrides*,
  auto-managed by Change Settings. Sourced after the shipped defaults
  in [`common.sh`](../bundle/Scripts/lib/common.sh), so any keys it
  sets win. Lives under `_Private/`, which `build_zip.sh` always
  excludes.

[`configure.sh`](../bundle/Scripts/configure.sh) writes only the keys
the user actually changed (sparse), preserving prior overrides across
sessions. The author can dev-test on their own Mac without ever
leaking their state into a shipped zip.

### Settings UX: hand-edit-the-config → interactive Change Settings

**Original.** Edit `config.env` in a text editor, type the right
values for `LAT`/`LNG`/`TZ`, re-run by hand.

**Now.** [`Controls/Change Settings.command`](../bundle/Controls/Change%20Settings.command)
prompts for:

- **City**, geocoded via the [Open-Meteo geocoding API](https://open-meteo.com/en/docs/geocoding-api)
  (free, no API key, returns lat / lng / timezone in one call). User
  picks from up to 10 disambiguated matches.
- **Schedule preset** — Short / Normal / Long, packaging the offset
  combinations the original plan suggested as examples.
- **Check frequency** — 5 / 15 / 30 minutes.

Each prompt has a "keep current" option. The script writes atomically
and offers to apply via `Install.command`. This is the only place we
re-introduce a network dependency (the geocoding lookup), accepted
because: (a) it's one-time per setting change, not recurring, (b) it
degrades gracefully when offline (curl failure prints a clear message
and continues without changing location).

### Setup: manual ritual → idempotent Install.command with welcome

**Original.** First-time setup is a series of shell commands the user
runs in order, with no script entry point and no welcome.

**Now.** [`Install.command`](../bundle/Install.command) is the single
entry point. On first run (no captured profiles), it shows a Welcome
banner explaining what's about to happen, including what the defaults
are if the user skips customization. Optionally invokes Change
Settings before capture. Then walks through the capture flow,
generates the LaunchAgent plist with the correct bundle path, loads
the agent, and runs an immediate dispatch.

Idempotent: re-running it after a config change detects existing
profiles, skips capture, and just re-applies the LaunchAgent. This is
the supported way to "apply a config change."

### Recovery: single backup → three-tier escape hatch

**Original.** Per-switch backups of `Index.plist` before each swap.
No story for "what if a macOS update changes the schema and every
backup is now incompatible?"

**Now.** Three escalating recovery options, documented in
[`bundle/README.txt`](../bundle/README.txt):

1. **Roll back the most recent switch** — copy any
   `_Private/Backups/Index.before-switch.*.plist` back over the live
   file.
2. **Restore the original pre-install state** —
   `Index.original.first-capture.plist` is saved on first capture.
3. **Nuclear: [`Reset Wallpaper to Default.command`](../bundle/Controls/Reset%20Wallpaper%20to%20Default.command)** —
   snapshots current wallpaper state, stops the LaunchAgent (so old
   captures can't immediately re-apply themselves), moves `Index.plist`
   aside (rename, not delete), and lets macOS regenerate it from
   current-OS defaults. Immune to schema drift because macOS itself is
   doing the regeneration.

Reset is intentionally **independent** of Uninstall:

- *"My switcher is acting weird, my wallpaper looks wrong"* → Reset
- *"I'm done with this tool but my wallpaper is fine"* → Uninstall
- *"I'm done AND something is wrong"* → Reset, then Uninstall

### Reliability fixes the original plan didn't anticipate

- **TZ-aware dispatcher.** Original: `NOW="$(date +%H:%M)"` used the
  machine's local timezone, even when the user's configured `TZ` was
  different (testing, travel, misconfigured Mac). Now: every "now" /
  "today" date computation in the dispatcher uses `TZ="$TZ" date ...`
  to respect the configured zone.
- **Location-key sun-times cache.** Original: `needs_sun_refresh()`
  only refreshed when the cached `sun_times.env` was from a different
  day. Now: `compute_sun_times.py` stamps each cache with
  `LOCATION_KEY="lat|lng|tz"`, and the dispatcher refreshes whenever
  the cached key doesn't match the current config (or is missing).
  Catches both the "Change Settings → Install" path and the
  "edit `user_config.env` by hand" path.
- **`mv`-based Uninstall.** Our first cut used `osascript ... tell
  application Finder ... delete (POSIX file p as alias)` to move the
  bundle to Trash. The `as alias` coercion can resolve to a stale
  Finder cache and silently report "moved" without touching the live
  inode (observed during dev). Replaced with plain
  `mv "$BASE" "$HOME/.Trash/Aerial Switcher.uninstalled-<timestamp>"`
  — no AppleScript, no TCC Automation prompt, no Finder cache
  dependency, recoverable from Trash.

## What we explicitly chose NOT to do

- **Code signing / notarization.** Would require an Apple Developer
  membership and ongoing notarization workflow. Out of scope for a
  small-audience tool. Cost: recipients must right-click → Open the
  first time on each `.command`.
- **PlistBuddy surgical edit alternative.** Would preserve unrelated
  wallpaper settings (multi-display, schedule choice, style options)
  and produce smaller saved profiles, but requires bootstrapping the
  per-variant asset UUIDs and adds significant fragile code for
  marginal benefit. Full-file swap is simpler to reason about, easier
  to debug (`diff` two plists), and more robust to schema drift in the
  parts we don't care about.
- **`desktoppr` / AppleScript / Shortcuts integration.** None of these
  support aerial wallpapers — only static images.
- **Log rotation.** Volume is too low (a few lines every 15 minutes,
  almost all "no change") to matter for years.
- **Multi-display support.** See future work in
  [`caveats_and_future_work.md`](caveats_and_future_work.md).
- **Automatic schema-drift detection.** The dispatcher would have to
  know what a "valid" Index.plist looks like for the current macOS,
  which changes per release. Cheaper and more honest to provide the
  manual Reset escape hatch and let the user trigger it when the
  wallpaper looks wrong.
