# Original map check

Checked: 2026-10-10. Sources: local IWADs in
`/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2`.

The headless check passed 90 of 132 maps. This checks loading, several rendered
views, 35 forward simulation ticks and 97 turning ticks, then a standing pose
inside the world with valid player clearance. It does not verify a full route,
exact original pixels, dynamic map specials, enemies or complete gameplay.
Rejected maps indicate current loader incompatibility, not corrupt source data.

## Reproduce

```sh
task wad-check -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M1
task run -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/doom2.wad' MAP01
```

The first command exports `build/original-start.ppm` and
`build/original-walk.ppm`, overwriting those diagnostics on each run. The WADs
remain external and are read only. No copyrighted data or rendered captures
are included in this repository.

## Per-archive results

### DOOM.WAD

29/36 maps passed.
SHA-256: `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`.

Passed: `E1M1`, `E1M2`, `E1M4`, `E1M5`, `E1M6`, `E1M7`, `E1M8`, `E1M9`, `E2M1`, `E2M2`, `E2M3`, `E2M4`, `E2M5`, `E2M6`, `E2M7`, `E2M8`, `E2M9`, `E3M1`, `E3M3`, `E3M4`, `E3M5`, `E3M6`, `E3M7`, `E3M9`, `E4M2`, `E4M4`, `E4M6`, `E4M7`, `E4M9`.

- `E1M3`, `E3M2`, `E3M8`, `E4M1`, `E4M3`, `E4M8`: `Sector boundary must form closed contours`.
- `E4M5`: `Wall texture is not defined in TEXTURE1 or TEXTURE2`.

### doom2.wad

21/32 maps passed.
SHA-256: `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255`.

Passed: `MAP01`, `MAP04`, `MAP05`, `MAP06`, `MAP07`, `MAP08`, `MAP09`, `MAP10`, `MAP11`, `MAP12`, `MAP13`, `MAP15`, `MAP20`, `MAP23`, `MAP24`, `MAP25`, `MAP27`, `MAP28`, `MAP29`, `MAP31`, `MAP32`.

- `MAP02`, `MAP14`, `MAP16`, `MAP17`, `MAP18`, `MAP19`, `MAP21`, `MAP22`, `MAP26`, `MAP30`: `Sector boundary must form closed contours`.
- `MAP03`: `Player start intersects a wall or has insufficient clearance`.

### tnt.wad

26/32 maps passed.
SHA-256: `9cbc54a6e46ec9f99dd9e9b59a39c7264460b9041c780344ed7cae899e4d92f9`.

Passed: `MAP01`, `MAP03`, `MAP04`, `MAP05`, `MAP06`, `MAP07`, `MAP08`, `MAP09`, `MAP10`, `MAP11`, `MAP12`, `MAP13`, `MAP14`, `MAP15`, `MAP17`, `MAP18`, `MAP19`, `MAP20`, `MAP22`, `MAP24`, `MAP25`, `MAP26`, `MAP28`, `MAP29`, `MAP30`, `MAP32`.

- `MAP02`, `MAP21`, `MAP27`: `Sector boundary must form closed contours`.
- `MAP16`: `Sector has invalid heights or light level`.
- `MAP23`, `MAP31`: `Sector has no closed boundary`.

### PLUTONIA.wad

14/32 maps passed.
SHA-256: `a83b00c636fa3308286e76b1b3153fc14507caf994b0450770421260b08efed8`.

Passed: `MAP01`, `MAP04`, `MAP05`, `MAP06`, `MAP07`, `MAP10`, `MAP12`, `MAP15`, `MAP19`, `MAP21`, `MAP22`, `MAP23`, `MAP27`, `MAP32`.

- `MAP02`, `MAP03`, `MAP08`, `MAP09`, `MAP13`, `MAP14`, `MAP17`, `MAP18`, `MAP20`, `MAP24`, `MAP25`, `MAP26`, `MAP28`, `MAP29`, `MAP30`: `Sector has no closed boundary`.
- `MAP11`, `MAP31`: `Sector boundary must form closed contours`.
- `MAP16`: `Wall texture is not defined in TEXTURE1 or TEXTURE2`.

## Interactive validation

- Doom `E1M1` and Doom II `MAP01`: X11 visible rendering, forward movement,
  key release, focus loss, turning and Escape shutdown passed.
- Generated corridor, single-sector, multi-sector and sky scenes passed
  `task gui-check`; `task check` passed with 64 original synthetic WADs.
- TNT/Plutonia and the remaining original maps received headless checks only.
- Original-map forward movement can stop against static doors or walls; the
  check is not a playthrough and does not require every forward tick to move.

## Changes and remaining limits

The initial E1M1/MAP01 failures required classic sky selection, fullbright
panorama sampling, shared sky between ceilings of different heights, and
omission of explicitly absent upper/lower wall textures (`-`). These rules
have synthetic regression checks; unknown named wall materials still fail.

The 42 remaining rejections comprise 21 open-contour checks, 17 sectors without
a boundary, two missing wall materials, one start-clearance check and one
sector-height/light check. The contour and start checks remain enabled.
Do not claim whole-IWAD compatibility from the passing subset.

Masked middle walls, sprites, weapons, monsters, moving doors, gravity and
Brutal Doom/Project Brutality PK3 behavior remain unimplemented. Missing wall
tiers are omitted; original hall-of-mirrors effects are not reproduced.
No performance target or non-Linux platform was checked.
