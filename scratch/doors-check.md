# Manual door check

Checked: 2026-10-10. Assets are the external IWADs listed in
[the original-map report](original-map-check.md).

Static closed sectors previously stopped the player permanently. Manual door
types 1, 31, 117 and 118 now animate their ceilings when Space is pressed on
the front side within 64 Doom units. Types 1/31 move two units per tick;
117/118 move eight. The target is the lowest neighboring ceiling minus four
units. Types 1/117 wait 150 ticks and close; 31/118 remain open and consume
their line action. Using an active normal door toggles its direction. A closing
door reverses before the player's standing clearance becomes invalid.

## Architecture

- `DoomDoors` copies line actions and validated front/back sector references
  after `DoomMap` validates the classic map records. Unsupported actions stop
  the use trace without activating another line behind them.
- `GameGeometry.World.WithCeilings` copies heights and shares sealed geometry,
  materials and partition data. Old snapshots remain valid. Each moving plane
  copies eight bytes per sector plus a small world object.
- Ray hits carry the caller's line identifier. Wall anchors shift with the
  owning/neighbor ceiling according to sidedef pegging flags. Potential upper
  materials around moving sectors load even when hidden in the initial frame.
- Simulation consumes one pending use action per tick. Space repeats while
  held do not create more actions; release/focus loss resets its held state.
  Camera and current world are still captured together under the game monitor.

## Verification

`task check` passed engine checks and 103 generated WAD fixtures. Door checks
cover exact 64-unit reach, wrong-facing/back-side use, opaque-wall occlusion,
unsupported/locked actions, absent back sides, animation speed, opening at
56-unit clearance, movement through the passage, waiting, full closure,
direction toggles and reversal under the player. Additional checks preserve
old world snapshots, test texture anchors, reject a hidden unknown upper
material and preserve the loaded game after a failed replacement load.

`task gui-check` passed six scenes: corridor, single-sector, multi-sector, sky,
BSP and door. The door scene tests visible motion, held/released Space,
closing, reopening, forward movement, key release, focus loss, turn and Escape.
Each check owns a unique temporary executable and window.

The strengthened 132-map load/render/movement check passed again after door
integration: Doom 36/36, Doom II 32/32, TNT 32/32, Plutonia 32/32. It does not
activate every door or verify complete routes through those maps.

The local door probe passed these original map cases:

- `DOOM.WAD` E1M1: line 148, type 1.
- `doom2.wad` MAP01: line 47, type 31.
- `tnt.wad` MAP01: line 512, type 31.
- `PLUTONIA.wad` MAP01: line 205, type 117.

The probe places a valid standing camera 32 units in front of the first suitable
closed door, confirms blocked movement, activates it, advances 70 ticks,
renders the open view, crosses its boundary and checks standing clearance.
Line identifiers are zero-based. These are isolated door checks; the probe
does not walk from the map's original player start to that door.

## Reproduce

```sh
task check
task gui-check
task run -- build/door.wad E1M1
task door-check -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M1
```

`door-check` overwrites `build/original-door-closed.ppm` and
`build/original-door-open.ppm`. Synthetic checks also export
`build/door-closed.ppm`, `build/door-opening.ppm` and `build/door-open.ppm`.
No original game data or captures are committed.

The first door window check failed with `Frame contains no visible scene`:
the legitimate close-up door frame had only two colors, while the helper
required four. It now rejects a uniform startup image and background-only
pixels, and accepts this textured two-color scene. The corrected check passed.
The first original-door helper build failed with `missing 'END'`; the missing
loop terminator was added and all four archive probes passed.

## Limits and sources

Only these four unlocked manual door types are implemented. Locked doors,
inventory/keys, tagged switches, walk-over actions, lifts, moving floors,
sector timers and sound remain absent. Collision checks the player circle;
there are no actors to obstruct doors yet. Use traces stop after 256 line hits
and scan walls; edited dense maps may need spatial traversal. Whole-level
completion, pixel accuracy, performance targets and other platforms were not
checked. Brutal Doom PK3 behavior remains unsupported.

Behavior references are id Software's
[p_doors.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c),
[p_spec.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c),
[p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c)
and [r_segs.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_segs.c).
No upstream implementation code was copied.
