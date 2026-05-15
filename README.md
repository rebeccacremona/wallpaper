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
│   ├── chatgpt_initial_plan.md       # initial plan from ChatGPT (preserved verbatim)
│   ├── revisions.md                  # end design vs original plan, themed by topic
│   └── caveats_and_future_work.md    # Tahoe-specific caveats, residual risks, open questions
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

Two-file model:

- `bundle/Scripts/lib/config.env` is the **shipped defaults**. Travels
  with the bundle. Boston / Normal preset / 15-min check by default.
  Edit only if you want to change what *every* recipient gets.
- `bundle/_Private/State/user_config.env` is the **per-Mac user override**.
  Auto-managed by `Controls/Change Settings.command`. Sourced after the
  shipped defaults so any keys it sets win. Lives under `_Private/` so
  it's never shipped in the zip.

End users typically use Change Settings (interactive: city geocoding +
schedule preset + check frequency), which only writes the keys they
actually changed into `user_config.env`. Manual hand-editing of
`user_config.env` works too. The shipped `config.env` should generally
be left alone unless you're updating defaults for everyone.

`Install.command` is idempotent: re-running it only re-prompts for
wallpaper capture if profiles are missing. After any config change,
re-run it to rewrite the LaunchAgent and reload.

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

See [`design/revisions.md`](design/revisions.md) for the rationale and
the explicit set of trade-offs we accepted. Tahoe-specific caveats and
residual risks live in [`design/caveats_and_future_work.md`](design/caveats_and_future_work.md).

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

See [`design/caveats_and_future_work.md`](design/caveats_and_future_work.md)
for the full discussion. Short list:

- Pokes a private macOS file; future point releases could break things.
- Brief desktop flash on each switch (WallpaperAgent reload).
- Manual capture step (no Apple API to script wallpaper selection).
- Tahoe "dynamic" wallpapers only animate on the lock screen, not the
  desktop — this tool gives you variation on the desktop by switching between
  the four still-frame variants.
- Single-display only for now.
- Recipients see Gatekeeper "unidentified developer" warnings on each
  `.command`; first run requires right-click → Open. Not signed/notarized.
