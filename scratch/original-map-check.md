# Original map check

Checked: 2026-10-10. Sources: local IWADs in
`/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2`.

The final headless check passed all 132 maps; the previous milestone passed
90. Each check loads a map, rejects start/walk frames containing only the two
background colors, renders several views, advances 35 forward ticks
and 97 turning ticks, then verifies a standing pose inside the world with valid
player clearance. Forward movement can stop against static walls or doors.
This does not verify a full route, exact original pixels, dynamic map specials,
enemies or complete gameplay.

## Reproduce

```sh
task wad-check -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M3
task run -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/doom2.wad' MAP03
```

The first command overwrites `build/original-start.ppm` and
`build/original-walk.ppm`. The archives remain external and are read only.
No game data or rendered captures are committed.

## Per-archive results

- `DOOM.WAD`: 36/36 maps passed; SHA-256
  `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`.
- `doom2.wad`: 32/32 maps passed; SHA-256
  `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255`.
- `tnt.wad`: 32/32 maps passed; SHA-256
  `9cbc54a6e46ec9f99dd9e9b59a39c7264460b9041c780344ed7cae899e4d92f9`.
- `PLUTONIA.wad`: 32/32 maps passed; SHA-256
  `a83b00c636fa3308286e76b1b3153fc14507caf994b0450770421260b08efed8`.

No original-map loader or simulation failures remain in this short check.

## Interactive validation

- `task check` passed with 92 original synthetic WAD fixtures, including BSP
  references/ranges/cycles, first-seg subsectors, unused sectors, absent wall
  materials, inverted closed sectors and tangent player starts.
- `task gui-check` passed the corridor, single-sector, multi-sector, sky and
  BSP scenes: visible rendering, movement, release, focus loss, turn and Escape.
- Original Doom II `MAP03`, TNT `MAP16`, Plutonia `MAP02` and Doom `E4M5` passed
  the same X11 input/render/shutdown check sequentially on the final build.
- A parallel Plutonia `MAP02` run initially exceeded the five-second Escape
  shutdown budget. Two isolated reruns passed; the initial cause is unconfirmed.
- GUI checks now launch a unique temporary executable copy so an already
  running game with the same source path cannot receive their test events.
- A two-copy ownership check passed: the pre-existing temporary game's process,
  window and frame stayed unchanged while the second copy received test input.

## Changes since the 90-map baseline

Classic SEGS/SSECTORS/NODES now supply sector lookup instead of requiring every
sector to be a closed contour. The subsector uses its first seg, matching the
original loader even when later segs reference another sector. Every seg index,
subsector range and node child is validated. Child nodes must precede their
parent, making traversal finite without recursion. Empty BSP lumps retain the
closed-contour checks used by the original synthetic fixtures.

BSP fixed the 38 original contour/unused-sector rejections. The intermediate
check passed 125/132 maps and exposed seven remaining cases. Those were fixed:

- Doom II `MAP03` starts exactly 16 units from a wall. Tangency is now valid;
  actual penetration remains blocked.
- TNT `MAP16` contains two ceilings one unit below their floors. These closed
  sectors retain their original heights and cannot provide player clearance.
- Doom `E4M5`/`E4M8`, TNT `MAP21`, Plutonia `MAP16`/`MAP25` include one-sided
  walls whose middle texture is `-`. Their material is omitted; the wall still
  blocks movement and terminates rays. Unknown named textures still fail.

The first E4M5 GUI check still failed with `Frame contains no visible scene`.
Its exported start frame had only the two background colors: the camera sits
exactly on a portal, while ray casting skips zero-distance hits. Selecting the
sector immediately ahead of each ray fixed both portal directions in the
synthetic regression and E4M5's native/window checks. All 132 maps were rerun
with the stronger visible-frame assertion after this fix. The assertion helper
initially used constant `ASSERT(FALSE)`, which the compiler rejected; it now
returns a boolean for the caller's runtime assertion.

## Remaining limits

The renderer still traverses sector walls rather than using BSP for drawing.
BSP identifies the region; the wall bounds reject distant outside positions,
but leaf polygon coverage is not validated for edited maps. Collision remains
a circle with axis sliding rather than an exact original bounding-box solver.
Missing materials leave uncovered pixels as the frame background; original
hall-of-mirrors effects are not reproduced.

Masked middle walls, sprites, weapons, monsters, moving doors, gravity and
Brutal Doom/Project Brutality PK3 behavior remain unimplemented. Whole-level
traversal, exact original rendering, performance targets and non-Linux platforms
were not checked.
