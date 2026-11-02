# Door occupancy checks

Closing doors validate living solid actors and solid decorations before
publishing a ceiling snapshot. A barrel in a close-only door stops the ceiling
at its 42-unit height. After the barrel dies, the door can finish closing.
Raise doors and close/wait/open doors reverse on obstruction; close-only doors
retain their direction and try again on subsequent ticks. Sector ownership
remains held until the door finishes its action.

`DoomDoors.Controller.StepOccupied` accepts a game-owned occupancy predicate.
The game supplies `DoomSprites.Scene.FitsCeilings`, using the existing engine
`TouchesSector`, `Stand` and immutable ceiling snapshots. The original `Step`
entry point retains its player-only behavior for callers without a sprite scene.
No engine changes or new YAML fields are required.

The predicate checks footprints reaching into the moving sector, including
objects whose origin lies in a neighboring sector. Exact tangent contact does
not obstruct. Ceiling-attached objects use their proposed ceiling-relative
position. Dead actors, collected items and non-solid objects do not obstruct.
As with floors, pre-existing invalid volumes are ignored for map previewing.
Rejected movement changes neither world geometry nor actor state. Doors sharing
a tag progress independently if only one is obstructed.

The stop/reverse policy follows the obstruction branches of id Software's
[p_doors.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c).
This stage does not add crushing damage, corpse flattening, dropped-item removal,
monster activation, sounds or exact original plane timing.

## Verification (2026-11-02)

Run the complete native engine/game checks and compile the Linux window:

```sh
python3 scripts/build.py --build-dir build/door-occupants check
```

The native suite passes 38 module checks using 412 original generated WAD
fixtures. The new `DoomDoorOccupantsSmoke` suite covers normal and fast
close-only doors, normal and fast raise doors, manual doors, close/wait/open,
living monsters, barrels, barrel death and resumed closure, neighbor overlap,
tangent contact, unrelated sectors, invalid spawns, pickups, solid and passable
hanging objects, grouped doors, retained sector claims, immutable snapshots and
the integrated game loop across a failed map replacement.

The Linux window executable builds. The interactive GUI regression could not
start because this environment has no accessible X11 display. Windows, A2,
A64/QEMU and original IWAD playthroughs were not rerun for this change.
