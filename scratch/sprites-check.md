# Static sprite check

Checked: 2026-10-10 UTC / 2026-10-11 Europe/Kyiv. The external IWADs are
the same local assets listed in [the original-map report](original-map-check.md).

Previously THINGS supplied only the player start. The unchanged baseline passed
`task check`, but adding a visible armor bonus produced a byte-for-byte identical
start frame to the otherwise identical empty map. Static spawn-frame rendering
now makes monsters, pickups, decorations and corpses visible.

## Implementation

- `GameSurface.Frame` reuses one FLOAT64 depth buffer alongside BGRX pixels.
  `Background` resets depth; `DepthSpan` writes only pixels no farther away;
  `Occlude` records depth without replacing color. Walls, planes, grilles and
  sprites use camera-forward depth. Solid boundaries hide sprites even with
  explicitly absent materials. This replaces the earlier local grille-row
  buffer and adds 512000 bytes at 320 x 200. Rendering allocates no per-frame
  heap data. Equal-depth covered pixels use the last submission.
- `GameRenderer.DrawSprite` projects a camera-facing image from caller position,
  pixel offsets and texel density. It clips before integer conversion, rejects
  images behind the near plane, bounds UV sampling, mirrors columns and applies
  light/distance shading unless fullbright. Holes preserve earlier pixels;
  explicit black remains covered. Overlapping sprites require no depth sort.
- `DoomThings` records factual spawn images, fullbright flags and ceiling heights
  for 116 visible classic object types. `DoomSprites` filters medium-skill and
  single-player flags, resolves the owning sector and keeps immutable actors.
  It selects eight directions or a rotation-zero frame and supports paired
  mirrored names. Last exact lump names win; malformed names, conflicting
  rotations, missing views and invalid positions fail for known visible types.
- `DoomTextures.Sprite` shares the existing validated patch decoder and resource
  budgets, caches by lump index and preserves signed header offsets. THINGS
  is capped at 65536 records. Frame scans have a separate 64-million-work budget;
  image decode shares the existing 16-million-pixel and 64-million-work bounds.
- `Doom.Game` captures the sprite scene, world and camera together under its
  monitor, then renders outside the lock. Failed replacement loads preserve
  the current world and sprites. Ceiling-attached objects read the current
  world snapshot; earlier snapshots retain their original sprite positions.

## Verification

- The normal final `task check` passed four engine executables, generated 136
  original WAD fixtures, passed map/resource rejection and Doom movement,
  sector, BSP, grille and door checks, and compiled the Linux64 window.
  `DoomSpritesSmoke` covers covered black, holes, cache identity, patch offsets,
  sprite layering independent of THINGS order, near/far grille occlusion,
  closed portals, absent-material solid walls, spawn flags, ceiling placement,
  fullbright pixels, last duplicate lumps, directional/mirrored views and
  rejected incomplete/malformed resources. Failed loads preserve the frame.
- `task gui-check` passed nine scenes: corridor, single-sector, multi-sector,
  sky, BSP, grille, sprites, sprites behind a grille and doors. Each checks
  visible rendering, movement, key release, focus loss, turning and Escape.
  Door animation and held/released Space still pass. After the final map
  publication-order adjustment, the ordinary `task check`, four representative
  original starts and the sprite/grille X11 scene passed on the final binary.
- All 132 original maps passed headless loading, start/walk rendering, 35
  forward ticks, 97 turning ticks and a valid final standing pose. Doom passed
  36/36; Doom II, TNT and Plutonia each passed 32/32. Hashes remain:
  DOOM.WAD: `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`
  doom2.wad: `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255`
  tnt.wad: `9cbc54a6e46ec9f99dd9e9b59a39c7264460b9041c780344ed7cae899e4d92f9`
  PLUTONIA.wad: `a83b00c636fa3308286e76b1b3153fc14507caf994b0450770421260b08efed8`
- Inspected synthetic single, layered and grille frames, plus original Doom
  E1M1 and Doom II/TNT/Plutonia MAP01 captures. Doom's corpse and Doom II's
  monsters are visible at their starts. Assets and captures remain external
  or ignored. The source operation layout check passed all 31 Active Oberon
  files; whitespace checks passed in both repositories. MiniA2 remains clean
  and unchanged; the installed Linux64 SDK was used.
- A final focused `sprites-check` passed an additional ceiling-motion test:
  lowering a ceiling moves its attached image while re-rendering the old world
  reproduces the previous sprite frame exactly.

Initial tests returned `Trap 5.8 (ASSERT failed)`: assertions sampled a row
outside the generic test image and a hole in
the near-grille patch. Adjusting those fixture offsets/pixels fixed the tests.
The directional fixture initially allowed an island wall to occlude the object;
using a clean room and the actual mirrored black column fixed that check.
The layout helper initially treated multiline parameter separators as operations;
tracking parentheses removed those false positives. The sandbox reference
download failed with `Temporary failure in name resolution`; the authorized
native download succeeded. No product failures remain in the final stated suites.

## Reproduce and limits

```sh
task check
task gui-check
task run -- build/sprites.wad E1M1
task run -- build/sprites-grate.wad E1M1
task run -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M1
```

Actors stay at their spawn frames. Animation, actor collision, pickups,
inventory, weapons, monster behavior and the original spectre fuzz effect are
absent. Unknown thing types are skipped for previews; no difficulty selector
or multiplayer simulation exists. Depth reset and sprite drawing add work
per frame; performance targets were not measured. Full routes, original pixel
accuracy, other platforms, extended tall patches, translucency, and Brutal Doom
PK3 behavior remain unverified or unsupported. No pushes, merges or deployments
were made; original game data is not distributed.

Factual metadata and behavior references are id Software's
[info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c),
[r_things.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_things.c),
[p_mobj.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_mobj.c)
and [r_data.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_data.c).
The parser and renderer are original implementations, not copied upstream code.
