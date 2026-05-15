# Caveats, risks, and future work

This document collects three things the design doesn't (and can't)
make go away:

- **Caveats** — Tahoe-specific behaviors the user has to accept.
- **Residual risks** — failure modes inherent to the technique, with
  mitigations where they exist.
- **Open questions / future work** — improvements that would be nice
  but aren't worth the complexity yet.

For the rationale of how the implementation differs from the original
ChatGPT plan, see [`revisions.md`](revisions.md).

## Caveats

### Tahoe "dynamic" wallpapers only animate on the lock screen

Per multiple sources (including
<https://blog.hloth.dev/tahoe-dynamic-video-wallpapers/> and Apple
Community threads), Apple's "dynamic" wallpapers in Tahoe — including
the Tahoe ocean variants — animate **only on the lock screen, not on
the desktop**. The desktop shows a still frame.

Switching between four still-frame variants throughout the day is, in
a sense, the *only* way to get any visual change on the desktop with
these wallpapers. The technique would be moot if Apple supported true
dynamic-on-desktop, but they don't.

### Tahoe Day Ocean is the system default — captured plist is unusual but correct

When you select the **Tahoe Day Ocean** variant in System Settings on
a fresh Tahoe (26.x) install, the resulting `Index.plist` does *not*
contain an explicit aerial asset UUID. Instead it has
`Provider: default` and an empty `Configuration`, because on Tahoe the
system default wallpaper *is* the Tahoe Day Ocean. Morning, Evening,
and Night each capture a real asset UUID via
`com.apple.wallpaper.choice.aerials`; Day captures as "use the system
default." The file sizes differ accordingly (~506 bytes for Day vs
~630 bytes for the others) and at first glance Day looks broken — but
it isn't.

Implications:

- **Single-Mac use:** completely fine. Applying the Day capture sets
  the wallpaper to "system default," which on Tahoe is Tahoe Day
  Ocean.
- **Sharing:** also fine in the common case. If a recipient has
  customized their system default wallpaper, applying the Day capture
  would resolve to *their* default, not Tahoe Day Ocean — but since
  recipients run Capture on their own Mac, they'd capture whatever's
  correct for their machine, so this self-heals.
- **Future Apple changes:** if Apple changes the Tahoe system default
  in a point release, the Day capture would silently start applying
  the new default. The Reset escape hatch handles this if it becomes
  a problem.

### Captured profiles are device-specific

Each captured `Index.plist` is specific to the Mac that captured it
(it references local asset UUIDs and possibly device-specific paths).
The shareable bundle therefore explicitly excludes `_Private/`, and
each recipient runs Capture themselves on their own Mac. This is
enforced by `build_zip.sh` and documented in
[`bundle/README.txt`](../bundle/README.txt).

### macOS-update fragility

Apple can change the `Index.plist` schema at any point release. The
`Reset Wallpaper to Default.command` escape hatch is the explicit
answer — but the user needs to know to run it when things look wrong.

## Residual risks (inherent to the technique)

These are inherent to the problem domain and no plan can eliminate
them:

1. **We poke a private macOS file** (`Index.plist`). Any Tahoe point
   release could change the schema. *Mitigation:* `Reset Wallpaper to
   Default.command`.
2. **Brief desktop flicker** when `WallpaperAgent` reloads. Inherent
   to the technique.
3. **Gatekeeper friction.** Every `.command` triggers an "unidentified
   developer" warning the first time. *Mitigation:* documented
   right-click → Open in `bundle/README.txt`.
4. **First-time wallpaper capture is manual.** No Apple API to script
   System Settings selections.
5. **`Install.command` bakes the bundle's current absolute path** into
   the LaunchAgent plist. Moving the folder later requires re-running
   `Install.command`. Trade-off for "install from anywhere."
6. **`StartInterval` doesn't fire during sleep.** First wake-from-sleep
   transition could lag up to one check interval (default 15 min).
   *Mitigation:* the dispatcher's stale-check on its next tick handles
   overnight transitions cleanly.
7. **Sun-time computation has known accuracy limits at high latitudes.**
   Off by ~20 minutes at Reykjavik (64°N), within ~2 minutes at
   mid-latitudes. Doesn't matter for wallpaper switching but worth
   noting if anyone reuses the formula for tighter purposes.

## Open questions / future work

- **Multi-display support.** Currently the captured `Index.plist` may
  or may not include all displays' state — untested. A multi-monitor
  user might see only one display's wallpaper switch.
- **Automatic schema-drift detection.** A dispatcher pre-flight that
  diffs the structure of the live `Index.plist` against the captured
  profiles and triggers a clear "go run Reset and re-Capture" message
  would reduce the blast radius of macOS updates. Currently the user
  has to notice the wallpaper looking wrong and remember the recovery
  flow.
- **Sleep/wake awareness.** Could subscribe to NSWorkspace
  `didWakeNotification` (via a small Swift helper) for sub-15-minute
  wake transitions, but probably not worth the complexity.
- **Tighter sun computation at high latitudes** (NREL SPA or
  astropy-style algorithm) if users complain. Not currently worth the
  complexity.
- **Detect "user picked the shipped default" in Change Settings.**
  Currently if the user picks a city that happens to match the shipped
  default exactly, it still writes those keys to `user_config.env`
  (harmless but redundant). A small enhancement could detect this and
  remove the override instead, keeping `user_config.env` minimal.
