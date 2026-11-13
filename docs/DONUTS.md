# Donut floors

Use action 9 starts a one-shot paired floor action. Every idle tagged pillar
selects its first adjacent two-sided sector as the ring, then that ring's first
other neighbor as the outer model, preserving WAD linedef order. Either sidedef
orientation is supported. The pillar lowers and the ring rises to the captured
model height. The model must lie between their starting heights.

Both sectors must be idle. If either is owned by another door or floor action,
neither starts and no ownership is lost. Missing neighbors, absent tags and
inverted heights leave the switch available for a later valid attempt. An
accepted use consumes the line and changes its switch image through the shared
action table. Crossings and gun hits do not activate action 9.

The ring captures the model's floor texture and flat name at activation. It
publishes them only after successfully reaching its destination, clearing its
sector-special code to zero. The pillar retains its own surface and special.
Model changes during motion do not alter the captured result. Equal starting
and destination heights still complete the surface transfer on the next tick.

Player and grounded actors ride accepted movement. Valid solid volumes can
block a plane without damage; the other plane may continue independently.
Blocked planes retain ownership and retry. Prior immutable snapshots retain
their heights and surfaces, and failed map replacement preserves active motion.
Loading validates hidden lower wall resources for untagged rings as well as
tagged pillars. Changed flat names participate in later stair matching.

The existing engine `World.WithFloors`, `World.WithFloorTexture`, collision,
rendering and occupant queries provide all reusable mechanisms. Selection of
WAD neighbors, activation, sector metadata and authored speed remain game rules.
No engine, MiniA2 or SDK source change is needed for this stage. The simulation
contains no platform imports; Linux, Windows and A2 use the same controller.

## Configuration

Complete YAML profiles must include:

```yaml
floors:
  donut_speed_per_tick: 0.5
```

This extends the existing `floors` section. The value is in map units per tick;
the accepted range is 0.01-64. The standard profile uses 0.5 and the alternate
test profile uses 1.5. Missing or invalid settings fail before replacing the
previous configuration. There is no compiled fallback.

## Reference and boundaries

The behavior reference is id Software's
[EV_DoDonut](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c#L1091),
[floor completion](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_floor.c#L200)
and [use action 9](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_switch.c#L325).
The implementation preserves the project's safe mover behavior: malformed
neighbors are rejected, both sectors retain shared ownership, and a blocked
plane cannot finish its surface transfer. It does not reproduce the original
unsafe sidedef assumptions or replacement of an already-moving ring.
Sound, crushing, sector-special effects, exact classic mover timing and demo
compatibility remain open.

## Verification (2026-11-13)

```sh
python3 scripts/build.py --build-dir build/donuts-linux-final check
cd build/donuts-linux-final
./ao-doom donut-gui.wad E1M1
```

Press E to raise the ring and lower the pillar in the three-room demonstration.
`donut-nested.wad` additionally exercises actual nested square sectors.

- The unchanged baseline passed 41 engine/game check groups and a Linux window
  build. The new test initially failed with `Trap 5.8 (ASSERT failed)` because
  action 9 did not activate. Final Linux and Windows checks pass 42 groups and
  use 472 generated WAD fixtures. Windows uses its native Windows SDK under
  Wine, including the Windows window executable; this is not a native Windows
  host claim.
- `DoomDonutsSmoke` covers paired directions and speed, delayed surface change,
  nested sectors, reversed sidedefs, untextured maps, busy ownership/rollback,
  missing/invalid targets, equal bounds, obstruction and retry, captured models,
  player/actor riding, immutable snapshots, failed/successful map replacement,
  hidden-material rejection and custom speed. Configuration checks reject
  missing, zero and excessive donut speeds.
- Three Linux GUI scenarios pass on an owned Xephyr display: demonstration
  controls/focus/release/shutdown, action 9, and existing stairs. The Windows
  window on the same nested display passes physical E activation, visible
  geometry changes, settled frames and physical Escape shutdown. Before/after
  Windows frames were visually inspected. No host keyboard layout was changed.
- Full A2 Unix64 and Win64 builds each compile 37 modules against the matching
  full-distribution symbols. Both 117-entry ZIP packages pass integrity checks.
  A separate adapter fix replaces commented conditional markers with real Fox
  directives; see [platform checks](PLATFORMS.md#a2-conditional-compilation-check-2026-11-13).
- Original IWAD probes were not run: the previous local asset directory
  `/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2` is absent.
  Campaign playthroughs, native Windows, A2 desktop/runtime, A64 and hardware
  were not checked in this stage.

Local evidence is under `scratch/donuts-*` and `scratch/verify-donuts-*.py`.
Ready outputs are `build/donuts-linux-final/ao-doom`,
`build/donuts-windows/ao-doom.exe` and the two `build/donuts-a2-*` packages.
The user-owned root `scene.ppm` is preserved and ignored as generated output.
