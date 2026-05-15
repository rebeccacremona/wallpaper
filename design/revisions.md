# Revisions to the initial plan

This document explains how the implementation in this repo diverged from
[`chatgpt_initial_plan.md`](chatgpt_initial_plan.md) and why. It also captures
the trade-offs we explicitly considered and rejected, the open questions, and
the residual risks that no amount of polish can eliminate.

## Context

**Goal:** automatically cycle the macOS Tahoe (26) desktop wallpaper between
the four time-of-day Tahoe ocean variants (Morning, Day, Evening, Night) on a
sun-aware schedule, and bundle the result so a non-technical user can install
it with a few clicks.

**Starting point:** ChatGPT produced a single markdown file
([`chatgpt_initial_plan.md`](chatgpt_initial_plan.md)) consisting of ~18 sections
of bash heredocs to paste into Terminal. The architecture (LaunchAgent +
dispatcher + captured `Index.plist` profiles) was sound. Several details were
not.

**Refactor approach:** keep the architecture, fix the broken bits, turn the
"recipe to paste into Terminal" into a real source repo with a one-double-click
recipient install.

## What we kept and why

The core wallpaper-switching mechanism — capture the active
`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` for each
of the four Tahoe variants, swap in the matching one when the time-of-day
window changes, and `killall WallpaperAgent` to reload — is unchanged.

We researched alternatives:

| Method | Verdict on Tahoe |
|---|---|
| AppleScript / `osascript` `set desktop picture` | Image-only; cannot accept aerial assets |
| Shortcuts.app | Image-only |
| `defaults write com.apple.desktop` | Long deprecated |
| [`desktoppr`](https://github.com/scriptingosx/desktoppr) | Uses `setDesktopImageURL` which has no aerial code path; maintainer confirms Apple would need to extend the API |
| [`macos-wallpaper`](https://github.com/sindresorhus/macos-wallpaper) | Static images only |
| `PlistBuddy` surgical edit of `Index.plist` | Works, but bootstrapping the per-variant UUIDs adds 50+ lines of fragile code for marginal benefit over file-swap |
| `Index.plist` swap + `killall WallpaperAgent` | What we use. Same mechanism the community converged on across Sonoma → Sequoia → Tahoe |

Apple DTS has stated on the developer forums that there is no supported API
for full wallpaper management and that this is unlikely to change for security
reasons. So `Index.plist` poking is the documented community workaround for
the entire era. We're not missing a cleaner door.

We also kept:

- Morning / Day / Evening / Night window semantics.
- 15-minute LaunchAgent cadence (with `StartInterval`, which doesn't fire while
  asleep — handled gracefully by stale-check on wake).
- All the Finder-clickable controls (Turn On/Off, Switch Now, Use *, Status,
  Logs, Uninstall).
- Per-switch backups of `Index.plist` before each swap.
- Manual capture as the way to populate profiles. There's no clean alternative
  given no programmatic API exists for selecting aerial wallpapers.

## What we changed and why

### 1. Heredoc-expansion bug → real source files in a repo

The initial plan's generators used unquoted heredocs (`<<EOF` rather than
`<<'EOF'`), which means `$HOME`, `$USER`, and `$(id -u)` are expanded *at the
time you generate the bundle on your Mac*. The resulting `.command` files
would have hardcoded paths like `/Users/rcremona/...` baked in, breaking
cross-Mac sharing entirely.

Fix: instead of generating files from heredocs, the `.command` files are
**static files in this repo**. Each one resolves the bundle root from
`${BASH_SOURCE[0]}` at runtime via the shared
[`bundle/Scripts/lib/finder_command.sh`](../bundle/Scripts/lib/finder_command.sh)
boilerplate. The only file generated at install time is the LaunchAgent plist
(by `Install.command` on the recipient's machine), which legitimately needs
absolute paths to the bundle's actual location.

### 2. Network sunrise/sunset API → local NOAA computation

The initial plan called `sunrise-sunset.org` once per day. That introduces an
external dependency that can rate-limit, fail silently, be blocked on a
corporate network, or be down when the dispatcher runs.

Fix: [`bundle/Scripts/compute_sun_times.py`](../bundle/Scripts/compute_sun_times.py)
implements NOAA's solar position formula directly in ~50 lines of stdlib
Python. No network, no API key, works offline, identical accuracy for non-polar
latitudes. We verified output against published values for Boston, Sydney, and
Reykjavik (Reykjavik is ~20 min off due to known NOAA-formula limitations at
high latitudes; ±10 min is irrelevant for wallpaper switching).

A subtle bug worth noting: the NOAA formula uses *positive east* longitude
convention, with the hour angle *positive* for sunrise and *negative* for
sunset. Our first cut had the sign of the hour angle reversed (a common
mistake — different NOAA write-ups use different conventions). This was caught
by sanity-checking against a known-correct value for Boston in May.

### 3. "Paste 15 heredocs into Terminal" install ritual → versioned repo + `Install.command`

The initial plan asked the user (or recipient) to paste ~18 sections of bash
into Terminal in order. Tedious for the original author, untenable for a
"non-technical user shareable" tool.

Fix: this repo is the source-of-truth. Source files live under `bundle/`.
[`build_zip.sh`](../build_zip.sh) produces `Aerial Switcher Shareable.zip`
using `ditto` (preserves macOS metadata and exec bits, suppresses AppleDouble
sidecar files). The recipient extracts the zip, right-clicks
`Install.command` → Open, and that's the entire install path.

`Install.command` is **idempotent**: it generates the LaunchAgent plist with
the recipient's actual `$HOME`/`$USER`/bundle path, runs Capture only if any of
the four expected profile plists is missing (per-file check, not "is the
directory empty"), and reloads the agent. Re-running it is the supported way
to apply `config.env` changes — it does *not* re-trigger the capture flow if
profiles already exist, so editing config and re-installing takes a few
seconds with no UI interaction.

### 4. Window offsets entangled with sun-time fetcher → standalone `config.env`

In the initial plan, the morning/day/evening/night offsets lived inside the
sun-times fetcher script, mixed in with the Boston-specific lat/lng. Editing
windows required editing the same script that fetched the times, even though
the two concerns are unrelated.

Fix: [`bundle/Scripts/lib/config.env`](../bundle/Scripts/lib/config.env) is
a single file with `LAT`, `LNG`, `TZ`, the four offsets, the LaunchAgent label
suffix, and the check interval. Sourced by both the dispatcher and the
installer.

### 5. README described but never written → actually shipped

The initial plan ended with a long `README.txt` snippet but had no shell step
to write it to disk. So the bundle never actually contained a README.

Fix: [`bundle/README.txt`](../bundle/README.txt) is a real shipped file with
end-user docs, and [`README.md`](../README.md) at the repo root is the
dev-facing version.

### 6. Gatekeeper friction unaddressed → documented

The initial plan didn't mention that `.command` files distributed via zip
trigger an "unidentified developer" warning the first time the recipient
double-clicks them. Non-technical users routinely give up at this dialog.

Fix: `bundle/README.txt` and `Install.command`'s preamble both explain
right-click → Open as the one-time bypass. Not perfect, but it's the best we
can do without code-signing.

### 7. Recovery story → three-layer escape hatch

The initial plan had per-switch backups but no story for "what if a macOS
update changes the `Index.plist` schema and now nothing works?" In that
scenario, every backup is also schema-mismatched.

Fix: three escalating recovery options, documented in `README.txt`:

1. **Roll back the most recent switch** — copy any
   `_Private/Backups/Index.before-switch.*.plist` back over the live file.
2. **Restore the original pre-install state** —
   `Index.original.first-capture.plist` is saved on first capture. May not
   work after a macOS update that drifted the schema.
3. **Nuclear: `Reset Wallpaper to Default.command`** — snapshots the current
   wallpaper state for forensics, moves `Index.plist` aside (rename, not
   delete), kills `WallpaperAgent`, and lets macOS regenerate
   `Index.plist` from current-OS defaults. Immune to schema drift because
   macOS itself is doing the regeneration. The user then re-picks any
   wallpaper in System Settings, and (if they want to keep using the
   switcher) re-runs Capture.

`Reset` is intentionally **independent** of `Uninstall`. They cover three
distinct user intents:

- *"My switcher is acting weird, my wallpaper looks wrong"* → Reset
- *"I'm done with this tool but my wallpaper is fine"* → Uninstall
- *"I'm done with this tool AND something is wrong"* → Reset, then Uninstall

## What we explicitly chose NOT to do, with rationale

- **No code signing / notarization.** Would require an Apple Developer
  membership ($99/yr) and ongoing notarization workflow. Out of scope for a
  small-audience tool. Cost: recipients must right-click → Open the first
  time on each `.command`.
- **No PlistBuddy surgical edit alternative.** Would preserve unrelated
  wallpaper settings (multi-display, schedule choice, style options) and
  produce smaller saved profiles. But requires bootstrapping the per-variant
  asset UUIDs and adds significant fragile code for marginal benefit. The
  full-file swap approach is simpler to reason about, easier to debug
  (`diff` two plists), and more robust to schema drift in the parts we don't
  care about.
- **No `desktoppr` / AppleScript / Shortcuts integration.** None of these
  support aerial wallpapers — they only work for static images.
- **No log rotation.** Volume is too low (a few lines every 15 minutes,
  almost all "no change") to matter for years.
- **No multi-display support.** Tagged as future work in the open
  questions below.
- **No automatic schema-drift detection.** The dispatcher would have to
  know what a "valid" Index.plist looks like for the current macOS, which
  changes per release. Cheaper and more honest to provide the manual Reset
  escape hatch and let the user trigger it when the wallpaper looks wrong.

## Caveats discovered during planning

### Tahoe "dynamic" wallpapers only animate on the lock screen

Per multiple sources (including
<https://blog.hloth.dev/tahoe-dynamic-video-wallpapers/> and an Apple
Community thread), Apple's "dynamic" wallpapers in Tahoe — including the
Tahoe ocean variants — animate **only on the lock screen, not on the
desktop**. The desktop shows a still frame.

The user explicitly accepted this trade-off before we started building.
Switching between four still-frame variants throughout the day is, in a
sense, the *only* way to get any visual change on the desktop with these
wallpapers — the technique would be moot if Apple supported true
dynamic-on-desktop, but they don't.

### Single-user / single-Mac profiles

Each captured `Index.plist` is specific to the Mac that captured it (it
references local asset UUIDs and possibly device-specific paths). The
shareable bundle therefore explicitly excludes `_Private/`, and each
recipient runs Capture themselves on their own Mac. This is enforced by
`build_zip.sh` and documented in `README.txt`.

### Tahoe Day Ocean is the system default — captured plist is unusual but correct

Discovered during the first live install: when you select the **Tahoe Day
Ocean** variant in System Settings on a fresh Tahoe (26.x) install, the
resulting `Index.plist` does *not* contain an explicit aerial asset UUID.
Instead it has `Provider: default` and an empty `Configuration`, because
on Tahoe the system default wallpaper *is* the Tahoe Day Ocean. Morning,
Evening, and Night each capture a real asset UUID via
`com.apple.wallpaper.choice.aerials`; Day captures as "use the system
default". The sizes differ accordingly (~506 bytes for Day vs ~630 bytes
for the others) and at first glance Day looks broken — but it isn't.

Implications:

- **Single-Mac use:** completely fine. Applying the Day capture sets the
  wallpaper to "system default" which on Tahoe is Tahoe Day Ocean.
- **Sharing:** also fine in the common case (recipient is on a fresh
  Tahoe install whose default is also Tahoe Day Ocean). If the recipient
  has somehow customized their system default wallpaper, applying the
  Day capture would resolve to *their* default, not Tahoe Day Ocean.
  Since recipients run Capture on their own Mac, they'd capture
  whatever's correct for their machine — so this self-heals.
- **Future Apple changes:** if Apple changes the Tahoe system default in
  a point release, the Day capture would silently start applying the new
  default. The Reset escape hatch handles this if it becomes a problem.

### macOS-update fragility

Apple can change the `Index.plist` schema at any point release. The Reset
escape hatch is the explicit answer — but the user needs to know to run it
when things look wrong. We document this prominently.

## Residual risks

These are inherent to the problem domain and no plan can eliminate them:

1. **We poke a private macOS file** (`Index.plist`). Any Tahoe point release
   could change the schema. *Mitigation:* `Reset Wallpaper to Default.command`.
2. **Brief desktop flicker** when `WallpaperAgent` reloads. Inherent to the
   technique.
3. **Gatekeeper friction.** Every `.command` triggers an "unidentified
   developer" warning the first time. *Mitigation:* documented right-click → Open.
4. **First-time wallpaper capture is manual.** No Apple API to script
   System Settings selections.
5. **Install.command bakes the bundle's current absolute path** into the
   LaunchAgent plist. Moving the folder later requires re-running
   `Install.command`. Trade-off for "install from anywhere."
6. **`Uninstall.command` triggers a one-time Finder automation permission
   prompt** because it uses `osascript ... tell application Finder ... delete`
   to move the folder to the Trash (rather than a destructive `rm -rf`).
7. **`StartInterval` doesn't fire during sleep.** First wake-from-sleep
   transition could lag up to one check interval (default 15 min). *Mitigation:*
   the dispatcher's stale-check on its next tick handles overnight
   transitions cleanly.
8. **Sun-time computation has known accuracy limits at high latitudes.** Off
   by ~20 minutes at Reykjavik (64°N), within ~2 minutes at mid-latitudes.
   Doesn't matter for wallpaper switching but worth noting if anyone reuses
   the formula for tighter purposes.

## Post-launch refinements (after first live install)

A few rough edges surfaced once we ran Install.command end-to-end. We
addressed them in a follow-up pass; documenting here so the rationale
isn't lost.

### 8. "Press any key to close" trap → just exit

Every Control originally registered an EXIT trap (`pause_then_exit`) that
forced a keypress before the script would exit. Intent was "give the
user time to read output before Terminal closes." Reality on macOS:
Terminal.app does NOT auto-close on process exit by default — it shows
"[Process completed]" and leaves the window open, letting the user
close it whenever. So the keypress was redundant friction.

Fix: removed the EXIT trap from `finder_command.sh`. Scripts exit
cleanly, Terminal stays open with their final output, user closes the
window when ready. If a user has explicitly configured Terminal to
auto-close on exit, they presumably want that behavior anyway.

### 9. Install.command jargon → friendly welcome

The original install banner used the word "idempotent" twice and led
with a wall of label/path metadata. Targets non-technical users badly.

Fix: rewrote the banner into a "Welcome!" message that explains in
plain English what's about to happen ("we'll set your wallpaper to
cycle…"), with a separate "Welcome back" path for re-runs. The
"useful next clicks" footer was also rewritten to drop technical
phrasing like "force a re-check now."

### 11. Stale sun-times cache + machine-TZ vs config-TZ (location-change bugs)

Caught during the second live test (changing config from Boston to Paris
via Change Settings, with the Long preset). Two distinct bugs surfaced:

**Bug A: stale cache survived the location change.** The dispatcher's
`needs_sun_refresh()` only refreshed when the cached `sun_times.env`
file's date differed from "today." After Change Settings → Install on
the same day, the cache was still "today" (just with Boston's sun times)
and got reused — so the dispatcher kept treating us as if we were in
Boston. Fix in two places:

1. `Install.command` now `rm -f "$SUN_FILE"` after writing the
   LaunchAgent plist, forcing the immediate dispatch to recompute. This
   covers the documented happy path of "change settings → re-install."
2. `compute_sun_times.py` now stamps the output with
   `LOCATION_KEY="lat|lng|tz"`, and the dispatcher's
   `needs_sun_refresh()` also refreshes when the cached
   `LOCATION_KEY` doesn't match the current config (or is missing
   entirely, which covers caches from before this feature). This
   covers the case where someone edits `config.env` by hand without
   re-running Install.command.

**Bug B: dispatcher used machine-local time against config-TZ sun times.**
Even after fixing Bug A, the live test still applied the wrong profile
because the dispatcher did `NOW="$(date +%H:%M)"` — which uses the Mac's
system timezone (Boston EDT 17:18) — and compared it against sun-time
windows that were correctly in Paris time (23:18 should fall in the
Night window). The mismatch made it think we were in Day. Fix: every
"now" / "today" date computation in the dispatcher now uses
`TZ="$TZ" date ...` so it respects the configured timezone explicitly.

Why this matters: in the common case (config TZ = system TZ), there's no
behavior change. But the moment someone configures a TZ different from
the machine's — for testing, travel, or just because their Mac's TZ is
misset — the comparison has to happen in the configured zone or the
windows are nonsense.

### 10. Config-by-text-editing → interactive `Change Settings.command`

Originally the only way to change LAT/LNG/TZ/window-offsets was to open
`Scripts/lib/config.env` in a text editor and type the right
incantations. Even with a small file, this is hostile to non-technical
users.

Fix: added [`bundle/Scripts/configure.sh`](../bundle/Scripts/configure.sh)
and a wrapping [`Change Settings.command`](../bundle/Controls/Change%20Settings.command).
The script prompts for:

- **City**, geocoded via the [Open-Meteo geocoding API](https://open-meteo.com/en/docs/geocoding-api)
  (free, no API key, returns lat / lng / timezone in one call). User
  picks from up to 10 disambiguated matches.
- **Schedule preset** — Short / Normal / Long, packaged from the offset
  combinations the original ChatGPT plan suggested.
- **Check frequency** — 5 / 15 / 30 minutes.

Each prompt has a "keep current" option. The script writes changes
atomically to a temp file and `mv`'s into place only after the user
confirms. It also offers to invoke `Install.command` afterward to
apply, with one subtlety: when called *from* Install.command (signaled
by `CONFIGURE_FROM_INSTALL=1`), it skips the apply prompt and just
exits, letting the parent installer continue. This avoids a re-exec
loop and a double-install.

We also weave configure into the first-run install: when no profiles
exist yet, `Install.command` asks "Customize your location and
schedule first? (y/N)" before launching the capture flow. Defaults to
N so the path of least friction is "use the Boston defaults."

This is the one place we re-introduce a network dependency (the
geocoding lookup), having previously eliminated it for sun times. The
trade-off is acceptable because the lookup is one-time, runs only
when the user explicitly chooses to change settings, and degrades
gracefully (the script catches curl failure and prints "could not
reach the geocoding service. Skipping location update." rather than
breaking the flow).

## Open questions / future work

- **Multi-display support.** Currently the captured `Index.plist` may or may
  not include all displays' state — untested. A multi-monitor user might
  see only one display's wallpaper switch.
- **Automatic schema-drift detection.** A dispatcher pre-flight that diffs
  the structure of the live `Index.plist` against the captured profiles and
  triggers a clear "go run Reset and re-Capture" message would reduce the
  blast radius of macOS updates. Currently the user has to notice the
  wallpaper looking wrong and remember the recovery flow.
- **Sleep/wake awareness.** Could subscribe to NSWorkspace
  `didWakeNotification` (via a small Swift helper) for sub-15-minute wake
  transitions, but probably not worth the complexity.
- **Tighter sun computation at high latitudes** (NREL SPA or astropy-style
  algorithm) if users complain. Not currently worth the complexity.
