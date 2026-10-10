# Masked wall check

Checked: 2026-10-10 UTC / 2026-10-11 Europe/Kyiv. Original assets remain the
external IWADs listed in [the original-map report](original-map-check.md).

Two-sided middle textures were previously skipped by `DoomMap.Side`.
A generated grille map reproduced this on the old implementation: its
first portal hit had no texture and the regression ended with
`Trap 5.8 (ASSERT failed)`. The renderer now displays that material while
retaining the rooms visible through its holes.

## Implementation

- `GameMaterials.Texture` initializes untouched texels to `-1`. `Set` writes
  covered RGB, including opaque black. `SampleMasked` retains coverage;
  ordinary `Sample` preserves its RGB contract and maps untouched texels to
  black. Classic patch composition therefore preserves holes and the coverage
  of earlier patches without a separate mask allocation.
- `GameRenderer` traverses portals as before and records the first covered
  grille texel for each screen row. It applies those colors after the rooms
  behind them render. A local 4096-row array matches the framebuffer height
  limit, has no per-frame heap allocation and bounds storage independently
  of the number of crossed grilles. Columns without grilles skip this pass.
- A two-sided wall's existing middle `texture` now supplies its grille.
  Physical sector openings clip it, horizontal coordinates wrap, and vertical
  coordinates cover one texture height. The lower ceiling anchors normal
  materials; the higher floor plus texture height anchors bottom-pegged ones.
  Offsets and current ceiling snapshots determine the sampled position.
- `DoomMap.Side` loads both one-sided and two-sided middle materials through
  the existing validated texture cache. Explicit `-` remains absent; unknown
  names and malformed patches fail. Linedef blocking and player clearance
  still control collision independently of texture coverage.

## Verification

- The unchanged baseline passed `task check` outside the sandbox. Its first
  sandbox run stopped at `UnixFiles.File.CreateUnixFile: open failed:
  Read-only file system` while writing the neighboring engine's build output.
- Final `task check` passed engine checks, 113 generated WAD fixtures, map and
  resource rejection, movement, doors, short native map/door probes and
  Linux64 GUI compilation. The new `DoomMaskedSmoke` checks holes, opaque
  black, caching, ordered overlapping patches, top/bottom pegging, offsets,
  lack of vertical repetition, both viewing directions, two layered grilles,
  upper/lower tier clipping, same-sector lines and immutable ceiling snapshots.
  Passable and blocking grilles retain their respective movement behavior;
  unknown middle names and missing post terminators are rejected.
- `task gui-check` passed seven scenes: corridor, single-sector, multi-sector,
  sky, BSP, grille and door. Each checks visible rendering, movement, release,
  focus loss, turning and Escape. Door motion and held/released Space still
  pass. The first sandbox GUI run returned
  `RuntimeError: No X11 display is accessible for the window check`; the
  authorized native run accessed X11 and passed the complete suite.
- The final native `original-check` passed every supplied stock map again:
  Doom 36/36, Doom II 32/32, TNT 32/32 and Plutonia 32/32. It loads and renders
  start/walk views, advances 35 forward and 97 turning ticks and verifies a
  valid standing pose. All four SHA-256 values match the original-map report.
- Inspected `masked-scene.ppm`, `masked-reverse.ppm` and `masked-layered.ppm`.
  They show grilles with visible rooms through their gaps. Captures and WAD
  assets remain ignored. Source operation layout and whitespace checks passed.
  MiniA2 was unchanged; this uses its installed Linux64 SDK.

The first new fixture placed its black post above the camera's field of view,
so its black-pixel assertion failed despite correct coverage decoding. Moving
the post into the visible part of the texture fixed that fixture. A later
offset assertion sampled a row where both textures were correctly absent;
selecting a visible displaced post fixed the test. The initial layout helper
also matched parameter separators, quoted text and activity annotations;
excluding those constructs made the layout check reflect actual statements.
All affected checks passed afterward.
The additional reverse-view and horizontal-offset assertions also passed in
the focused `masked-check` rerun after the complete suites.

## Reproduce and limits

```sh
task check
task gui-check
task run -- build/masked.wad E1M1
task run -- build/masked-bottom.wad E1M1
task run -- build/masked-layered.wad E1M1
task wad-check -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M1
```

This milestone implements binary coverage, not translucency. Extended tall
patches, sprites/actors, weapons, monsters, keys, other map actions, sound and
gravity remain absent. Stock map checks are short regressions, not complete
routes or comparisons against original Doom pixels. Original grille positions,
performance targets, other platforms and Brutal Doom PK3 behavior were not
validated. No game assets or upstream implementation code were copied. No
pushes, merges or deployments were made.

Behavior references are id Software's
[r_segs.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_segs.c)
for masked anchoring and clipping,
[r_things.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_things.c)
for masked posts and back-to-front drawing, and
[r_data.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_data.c)
for composite textures. This implementation uses bounded RGB coverage and
portal traversal rather than copying those routines.
