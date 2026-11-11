# Floor surface changes

## Lowering actions 37/84

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
Raising-platform variants, donuts, sounds, crushing and exact classic mover
tick ordering remain open.

## Raising actions 59/93

| Action | Activation | Motion | Model and change time |
| --- | --- | --- | --- |
| 59 | Player crossing, once | Raise by `floors.raise_step` | Triggering line's front sector, immediately |
| 93 | Player crossing, repeatable | Same | Same |

The standard YAML profile raises by 24 map units at `floors.speed_per_tick`
(1 map unit per tick). Existing custom step and speed settings apply; no new
configuration fields are required. Both crossing directions use the same authored
front-sector model. Use and gun events do not activate these actions.

After claiming a target sector, activation copies the model's current floor
texture, flat name and special code before any plane movement. The model need
not neighbor the target or share its height. All idle tagged sectors use that
same front-sector model. A target may also be its own model. Busy targets are
unchanged. Action 59 is consumed on crossing even when no target starts; action
93 remains available. Reactivating a moving target neither changes its surface
again nor extends the destination. A later idle activation adds another step
and copies the model as it exists then.

This differs from 37/84: the raising surface changes at activation, whereas the
lowering surface changes only at successful arrival. A subsequent obstruction
retains the raised action's new surface, destination and sector ownership until
motion can continue. No crushing damage is introduced. Grounded actors and
players ride accepted movement using the existing occupancy checks.

The current texture and sector metadata stay in the game controller and shared
immutable world snapshots. Stair matching sees the changed name, and loader
reachability validates lower walls across potentially changed name boundaries.
`ApplyCrossings` publishes its surface snapshot through a `VAR world` argument;
`Use` follows the same mutable activation contract. Old snapshots retain their
original surfaces. The existing engine API is sufficient; there are no new OS
imports, input mappings or platform adapter changes. Special codes remain
metadata; sector damage, secrets and timed effects are still open.

Behavior references: id Software's
[floor controller](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_floor.c)
and [crossing actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c).
The implementation uses the project's existing mover timing and floating-point
coordinates; this stage does not establish exact classic simulation compatibility.

## Raising-stage verification (2026-11-10)

```powershell
python scripts/build.py --platform windows --build-dir build/raise-changes-windows check
python scripts/build.py --platform a2 --build-dir build/raise-changes-a2 --a2-root ../target/Win64 --a2-platform Win64 build
```

- Windows x64 and Linux64 each passed 41 native engine/game check groups using
  461 generated WAD fixtures, then built their window executable.
- `DoomRaiseChangesSmoke` covers immediate publication, actual rendered pixels
  before plane movement, immutable snapshots, front versus adjacent/back models,
  both crossing directions, one-shot/repeat semantics, moving/busy/missing targets,
  rejected movement, grouped and self-model targets, untextured preview maps,
  carried player/actors, later stair names, hidden-material rejection, custom
  speed/step settings and failed/successful map replacement. Existing floor,
  switch, door and engine checks also passed.
- Three Linux X11 scenarios passed: demonstration controls/focus/shutdown,
  action 59 moving a distant floor, and action 93 carrying the player. These
  reuse the existing walk-floor GUI check and assert visible movement and settling;
  exact immediate surface timing is asserted by the native tests.
- A2 Win64 compiled all 37 shared/adapter modules against the full A2 symbols.
  Its 117-entry ZIP passed integrity checking. No A2 desktop/runtime, native boot
  or bare-metal behavior was exercised in this stage.
- Original `DOOM.WAD` E1M1 and `doom2.wad` MAP01 passed loading, rendering,
  walking, turning and firing in the Windows SDK command-context harness.
  Manual door probes opened/crossed E1M1 line 148 (type 1) and MAP01 line 47
  (type 31); saved start/walk/open-door frames were visually inspected. These
  are scoped probes, not campaign playthroughs or original-map 59/93 traversal.

Windows executable: `build/raise-changes-windows/ao-doom.exe`.
A2 package: `build/raise-changes-a2/ao-doom-a2-Win64.zip`.
Local logs and Linux orchestration are under `scratch/raise-changes-*` and
`scratch/verify_raise_changes_linux.py`. Linux used the same isolated September
SDK compatibility copies and `/tmp` linking documented in
[floor variants](FLOOR_VARIANTS.md); neither installed SDK nor MiniA2 was changed.
The standalone Windows original-map probe executable was rejected by the local
antivirus (WinError 225); the reported original-map tests used the normal SDK
module runner, as the native suite does. No security settings were changed.

## Lowering-stage verification (2026-11-02)

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
