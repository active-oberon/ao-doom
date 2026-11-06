# Lowering floors with surface changes

Player crossings of actions 37 (once) and 84 (repeatable) lower every idle
sector matching the line tag to its lowest neighboring floor. They use the
existing `floors.speed_per_tick`; complete YAML profiles need no new fields.

At activation, the controller captures the first adjacent sector at the target
height in WAD linedef order, considering two-sided boundaries in either
direction. It stores that sector's current floor texture, flat name and special
code. When the floor successfully reaches its destination, all three values
transfer. Until then the moving sector retains its own surface and special.
If no matching model exists, the sector retains its current values. A floor
already at its target can still copy a matching neighbor when its action steps.

Moving or busy targets retain their owner. Action 37 is consumed on a crossing
even when all targets are busy; 84 remains available. Grounded things and the
player ride accepted motion. Rejected movement does not complete the transfer
or release sector ownership. Sectors sharing a tag select their own models.

`DoomFloors.SectorSpecial` exposes the current special code for future sector
rules. This stage preserves metadata; damage, secrets and timed sector effects
are still unimplemented. Changed names affect subsequent stair-chain matching.
When a map includes these changing-floor actions, loader validation follows all
directed neighbors reachable from stair seeds across flat-name boundaries.
This conservatively validates lower wall materials that a future changed
stair chain could reveal. Maps with no changing-floor actions retain the
existing name-limited validation.

The shared engine's `World.WithFloorTexture` copies sector records and retains
geometry, partitions, wall materials and current floor/ceiling height snapshots.
The game publishes the returned world after successful floor movement; earlier
render snapshots retain their surfaces. Every model flat is loaded during map
validation, so no new WAD reads occur during movement. Untextured preview maps
are supported through the engine's optional NIL surface.

Behavior reference: id Software's
[floor controller](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_floor.c)
and [crossing actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c).
Other surface-changing floors, donuts, sounds, crushing and exact classic mover
tick ordering remain open.

## Verification (2026-11-02)

```sh
python3 scripts/build.py --build-dir build/floor-changes check
```

The native engine/game suite passes 39 module checks using 425 generated WAD
fixtures, then builds the Linux window executable. New game checks cover both
actions, rejected use/gun attempts and finite crossings, model ordering, zero
travel, absent models, model capture before motion, busy targets, rejection at
the last movement step, grouped models, player/actor riding, changed stair
chains, hidden-material rejection, accepted versus blocked player movement,
failed and successful map replacement, custom floor speed, untextured maps and
rendered pixels from immutable snapshots.

Engine checks cover validation, optional texture clearing, copied sector
surfaces, floor/ceiling and BSP composition, collision and before/after rendered
pixels. The existing engine/game suites also run, including the preceding door
obstruction stage. Windows, A2, A64/QEMU, interactive X11 and original IWAD
campaigns were not verified for this stage.
