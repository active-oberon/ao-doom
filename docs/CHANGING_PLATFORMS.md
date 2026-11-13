# Raising platforms with surface changes

Nine classic actions use the existing shared floor controller:

- Use actions 15/66 raise by `floors.raise_step` (standard 24 map units), once
  or repeatedly. Use actions 14/67 use `platforms.large_raise_step` (32 units).
- Use actions 20/68 and crossing actions 22/95 raise to the next higher adjacent
  floor, once or repeatedly. Gun action 47 performs the same nearest raise once.
- All nine use `platforms.raise_speed_per_tick` (standard 0.5 units per tick).

An accepted activation immediately copies the triggering line's authored front
sector floor texture and flat name. Both crossing directions use that same
model, including when it is not adjacent to the target. Fixed raises retain
the target sector's special code; nearest raises clear it to zero. Later model
changes do not replace the already-published surface. Old world snapshots keep
their original materials and heights.

Busy targets retain their existing mover and surface. One-shot use requires a
successful start; one-shot walk and gun actions are consumed even when targets
are busy. The gun switch image still changes on a reached hit. Repeat use
cannot extend an active motion; a later activation of an idle target computes
its new destination from its current height. Grouped targets act independently.
A nearest raise with no higher neighbor can still change its surface and
complete without travel.

Accepted movement carries the player and grounded actors. Upward obstruction
reverses these platforms without damage, preserving the already-changed
surface. They return to their captured initial floor and retry after a state
transition with zero wait. Stop actions 54/89 and resume actions 53/87 preserve
their direction, bounds and original raising behavior. Successful arrival at
the upper destination releases the sector; no return or endpoint wait follows.
Failed map replacement preserves active motion and surfaces.

## Configuration and APIs

Complete profiles must extend `platforms` with:

```yaml
platforms:
  raise_speed_per_tick: 0.5
  large_raise_step: 32
```

Speed accepts 0.01-64 map units per tick; the large step accepts 0.01-1024 map
units. Missing and invalid values reject the profile without replacing prior
settings. The 24-unit actions reuse the existing `floors.raise_step`, avoiding
a second authored value for the same small increment. The alternate test
profile exercises speed 1.5, large step 40 and small step 16.

`DoomFloors.Controller.Shot` now takes `VAR world`, matching the existing
mutable use/crossing APIs. A shot can publish a new surface before a plane
moves. The game's line-hit callback passes its active world to that method;
pellet traces retain their captured geometry. `DoomSprites.LineHit` retains
its observer signature, so callbacks publish through their owning world rather
than binding the mutable method directly. Existing floor/switch test callers
follow the same pattern. Game tests cover actual firing and failed replacement.

Geometry, floor surfaces, rendering, ray clipping and occupant checks remain
reusable engine mechanisms. Activation IDs, WAD model choice, sector metadata
and authored parameters stay in Doom. No platform code, engine, MiniA2 or SDK
source changes were needed. Linux, Windows and A2 share the same implementation.

## Reference and compatibility boundary

Behavior references are id Software's
[platform controller](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_plats.c#L128),
[use actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_switch.c#L337)
and [crossing/gun actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c#L569).
The project uses validated initial bounds and a bounded zero-wait transition
when a blocked raising platform returns. Exact classic mover timing, undefined
original bounds on obstructed raises, sounds, crushing, sector effects and
demo compatibility remain outside this stage. A source shortcut comment marks
the retry-policy boundary for later classic compatibility work.

## Verification (2026-11-13)

```sh
python3 scripts/build.py --build-dir build/changing-platforms-linux check
cd build/changing-platforms-linux
./ao-doom platform-change-gui.wad E1M1
./ao-doom platform-change-gun-gui.wad E1M1
```

Press E in the first demonstration; fire the pistol in the second.

- The new test failed against published 568020c with `Trap 5.8 (ASSERT failed)`
  at the missing action 14. The completed Linux and native Windows SDK suites
  pass 43 engine/game groups using 488 generated WAD fixtures. Windows SDK
  execution and its window executable were checked under Wine, not on a native
  Windows host.
- Six new TEST procedures cover all nine actions, immediate surface/special
  policy, speed, bounds, consumption and repeat destinations, busy/grouped
  targets, absent higher neighbors, obstruction reversal/retry, stop/resume,
  real gun publication, immutable snapshots, carried actors/player, hidden
  materials, failed/successful replacement and custom settings. Reload checks
  compare authored texels because each map load owns fresh texture objects.
  Configuration checks reject missing and out-of-range new fields.
- Four Linux X11 scenarios pass on an owned Xephyr display: demo controls,
  changing-platform use, changing-platform gun and the existing donut action.
  Windows on the nested display passes physical E and physical mouse-button
  activation, visible movement, settled frames and Escape shutdown in two
  separate scenarios. Windows gun before/after frames were visually inspected.
- Full A2 Unix64 and Win64 builds each compile 37 shared/adapter modules and
  produce 117-entry ZIP packages that pass integrity checking. No A2 desktop,
  native boot or physical hardware was exercised.
- Original IWAD/campaign probes were not run because the previous local asset
  directory is absent. Native Windows, A64 and hardware were not checked.

Local logs, source/artifact hashes and orchestration are under
`scratch/changing-platforms-*` and `scratch/verify-changing-platforms-*.py`.
Ready executables are `build/changing-platforms-linux/ao-doom` and
`build/changing-platforms-windows/ao-doom.exe`, with matching configurations and
fixtures. A2 packages are under `build/changing-platforms-a2-{unix,win}`.
