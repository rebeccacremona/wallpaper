# Tahoe Aerial Switcher

A macOS Tahoe (26) tool that automatically cycles your desktop wallpaper between
the four time-of-day Tahoe ocean variants based on local sunrise/sunset.

This repo is the source-of-truth for the shareable end-user bundle. Build
artifacts (a single zip) are produced via `./build_zip.sh`.

## Repo layout

```
.
├── README.md                 # this file (dev/repo)
├── design/
│   ├── chatgpt_initial_plan.md   # initial plan from ChatGPT (preserved verbatim)
│   └── revisions.md              # what we changed and why
├── build_zip.sh              # produces "Aerial Switcher Shareable.zip"
└── bundle/                   # the shareable folder (becomes "Aerial Switcher/" in the zip)
    ├── README.txt            # end-user docs (shipped in the zip)
    ├── Install.command       # one-double-click recipient install (offers to run configure first on first run)
    ├── Controls/             # Finder-clickable .command files (incl. Change Settings)
    └── Scripts/              # logic, plus Scripts/lib/{config,common,finder_command}, plus configure.sh
```

`bundle/_Private/` is created on the user's Mac at install time and is intentionally
absent from the repo (and excluded from the zip).

## Building the shareable zip

```bash
./build_zip.sh
```

Produces `Aerial Switcher Shareable.zip` in the repo root with `Aerial Switcher/`
as the top-level folder.

## Installing on your own Mac (dev install)

You can install directly from the repo without building a zip:

```bash
bundle/Install.command
```

The installer derives all paths from its own location at runtime, so this works
identically to a recipient installing from `~/Aerial Switcher/`. To re-point the
LaunchAgent if you move the repo later, just re-run `Install.command`.

## How configuration works

End users have two paths:

1. **Interactive (recommended):** double-click `Controls/Change Settings.command`.
   Prompts for city (geocoded online via the free Open-Meteo API),
   schedule preset (short / normal / long), and check frequency
   (5 / 15 / 30 min). Writes to `config.env` atomically and offers to
   reapply via Install.command.
2. **Manual:** edit `bundle/Scripts/lib/config.env` directly. Keys are
   `LAT`, `LNG`, `TZ`, `MORNING_OFFSET_MIN`, `DAY_OFFSET_MIN`,
   `EVENING_OFFSET_MIN`, `NIGHT_OFFSET_MIN`, `LABEL_SUFFIX`, and
   `CHECK_INTERVAL_SECONDS`. Window offsets are minutes relative to
   sunrise/sunset (negative = before). Then re-run `Install.command`.

`Install.command` is idempotent: re-running it only re-prompts for
wallpaper capture if profiles are missing.

## How wallpaper switching works

The macOS wallpaper system stores its current state in a private file:

```
~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
```

`Capture Wallpaper Profiles.command` snapshots that file four times (once per
Tahoe variant). The dispatcher swaps in the matching snapshot and reloads
`WallpaperAgent`. This is the same mechanism that's worked across Sonoma →
Sequoia → Tahoe; there is no documented Apple API for setting aerial
wallpapers programmatically.

See [`design/revisions.md`](design/revisions.md) for the full rationale and
the explicit set of trade-offs we accepted.

## Recovery

Three layers, escalating:

1. Roll back the most recent switch by copying any `Index.before-switch.*.plist`
   from `_Private/Backups/` over the live file, then `killall WallpaperAgent`.
2. Restore the pre-install state from `Index.original.first-capture.plist` (same
   way). Caveat: may not work after a macOS update if the schema drifted.
3. Run `Controls/Reset Wallpaper to Default.command`. Snapshots state, moves
   `Index.plist` aside, lets macOS regenerate it from current-OS defaults.
   Immune to schema drift.

## Caveats

See `bundle/README.txt` and `design/revisions.md` for the full discussion.
Short list:

- Pokes a private macOS file; future point releases could break things.
- Brief desktop flash on each switch (WallpaperAgent reload).
- Manual capture step (no Apple API to script wallpaper selection).
- Tahoe "dynamic" wallpapers only animate on the lock screen, not the
  desktop — this tool gives you variation on the desktop by switching between
  the four still-frame variants.
- Single-display only for now.
- Recipients see Gatekeeper "unidentified developer" warnings on each
  `.command`; first run requires right-click → Open. Not signed/notarized.
