# Solid actor collision check

Checked: 2026-10-11 Europe/Kyiv. Both repositories started clean on main;
the live handoff already contained locked manual doors. Local commits remain
authorized; pushes are not authorized. External assets remain the four local
IWADs listed in [the original-map report](original-map-check.md).

Player movement previously checked only walls and sector clearance. A probe
loaded `sprite-rotations.wad`, advanced 70 forward ticks and confirmed that the
player had passed the monster's center. The subsequent assertion that the
player stopped before its footprint returned `Trap 5.8 (ASSERT failed)`.

## Implementation

- `GameGeometry.PositionCheck` is a game-owned occupancy delegate. The new
  `MovePlayerChecked` retains the existing validation and bounded axis substeps,
  then checks the proposed coordinates before accepting position and floor.
  Rejected axes preserve their position; the other axis can still slide.
  Existing `MovePlayer` callers retain their interface and wall-only behavior
  by passing NIL through the same implementation. No game imports were added
  to the engine.
- `DoomThings` assigns a positive footprint radius to the 60 known visible
  types with the classic `MF_SOLID` flag. Zero means non-solid. All 60 values
  were compared with id Software's [info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).
  Examples: barrels 10, zombies/imps 20, demons 30, arachnotrons 64 and the
  spider mastermind 128 Doom units. The sprite image does not define collision.
- `DoomSprites.Free` requires overlap on both horizontal axes, using the sum
  of the player and actor radii. Exact tangent contact is free. Player collision
  ignores vertical separation, including solid hanging decorations, following
  [PIT_CheckThing in p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).
  Non-solid hanging variants, pickups and corpses remain passable. Skill and
  single-player filtering still select the immutable actors at map load.
- Doom invokes this check on each movement substep under its existing monitor.
  Collection snapshots share the unchanged actor metadata and still copy only
  collection bits. Successful replacement loads replace footprints; failed
  loads retain them. An initially overlapping actor blocks movement without
  adding a startup rejection or a tick assertion failure.
- Eight new fixtures use original synthetic art and map data. The existing
  `sprites-grate.wad` flags and passability remain unchanged. No external WAD
  assets, dependencies, MiniA2 source changes or spatial index were added.

## Verification

- `task check` passed all four engine executables, generated 165 original WAD
  fixtures and passed archive, texture, grille, sprite, inventory, pickup,
  actor, sector, BSP, unlocked/locked door and movement checks. The original
  map/door probes passed on fixtures, and the Linux64 window compiled.
- Engine occupancy checks cover blocked axes without a false floor update,
  diagonal sliding across a step, exact tangent movement, excessive motion
  rejection without mutation and the NIL delegate path.
- The new `DoomActorsSmoke` checks monsters, barrels and decorations; exact
  tangents, square corner contact, six-unit movement without crossing an actor,
  diagonal escape, solid/non-solid hanging variants, passable corpses/items,
  excluded spawn flags, collection snapshots, real game ticks, a stepped floor,
  overlapping starts and successful/failed map replacement.
- `task gui-check` passed all twelve scenes. The new barrel case approached
  the actor, held forward again and verified an unchanged frame, then moved
  diagonally around it. Release/focus/turn/Escape checks also passed. Previous
  grille, item collection, manual door and key-denial/pickup/unlocking cases
  passed unchanged.
- All 132 supplied maps passed loading, start/walk rendering, 35 forward ticks,
  97 turning ticks and standing clearance: Doom 36/36, Doom II 32/32, TNT 32/32
  and Plutonia 32/32. All four SHA-256 values match the original-map report.
- Inspected synthetic blocked/sliding captures and the first map's start view
  from each IWAD. The images remain visible, including HUD and original scene
  sprites. Source operation layout passed 38 modules; Python syntax and both
  repositories' whitespace checks passed. Logs are local `/tmp/ao-doom-actors-`
  files; captures and generated WADs remain ignored.

## Failed attempts and limits

The temporary red probe first used a wrong relative output path, then an
unsupported `KernelLog.Real` selector. Both were corrected before reproducing
the old movement failure. The first new engine sliding assertion expected
`x > 0.5`; actual valid sliding ended at approximately 0.4545 after bypassing
the obstacle and stepping onto the higher floor. The test now requires
`x > 0.25`, correct floor height and a free final footprint. The first engine
run and its enclosing task stopped on this assertion; the corrected full
`task check` passed. There are no remaining failing required suites.

Actors still remain at spawn positions/frames. Shooting, damage, death, actor
animation/movement and explosion effects are absent. Solid monsters can block
routes until combat is implemented. Door obstruction is still player-only;
actor crushing and actor-triggered reversal remain absent. Collision scans
all loaded actors; worst-case performance at the 65536-thing limit was not
measured. Initially overlapping starts are not made escapable. Full level
playthroughs, exact original collision/pixel equivalence, all original actor
placements, other platforms and Brutal Doom PK3 remain unverified or unsupported.

## Reproduce

```sh
task check
task gui-check
task run -- build/actors-barrel.wad E1M1
task run -- build/sprite-rotations.wad E1M1
task run -- build/actors-hanging-passable.wad E1M1
task wad-check -- '/path/to/DOOM.WAD' E1M1
```

Use W to approach the barrel, then W+D to slide around it. Actor bounds are
independent of the transparent holes in the synthetic sprite image.
