# Fixed raises and fast floors

Eleven additional linedef actions use the existing floor controller, sector
ownership, switch/button presentation and immutable moving geometry.

| Actions | Activation | Behavior |
| --- | --- | --- |
| 58 / 92 | Walk once / repeat | Raise by `floors.raise_step` (24 units). |
| 140 | Use once | Raise by `floors.large_raise_step` (512 units). |
| 36 / 98 | Walk once / repeat | Turbo lower to the highest neighboring floor. |
| 71 / 70 | Use once / repeat | The same turbo lowering. |
| 130 / 129 | Walk once / repeat | Fast raise to the next higher neighboring floor. |
| 131 / 132 | Use once / repeat | The same fast raise. |

Turbo lowering adds `floors.turbo_lower_gap` (8 units) when the highest
neighbor's floor differs from the starting height. Its destination is capped
at the starting floor, so equal or higher neighbors cannot raise the sector.
An absent lower/next-higher destination completes without travel. Fixed-step
repeat action 92 can add another step after its previous movement finishes.

Fast raises and turbo lowering use `floors.fast_speed_per_tick` (4 units/tick).
Fixed raises use the existing `floors.speed_per_tick` (1 unit/tick). All
distances are authored in Doom map units and converted at configuration load.
The four new fields are mandatory in complete profiles:

```yaml
floors:
  speed_per_tick: 1
  fast_speed_per_tick: 4
  raise_step: 24
  large_raise_step: 512
  turbo_lower_gap: 8
```

Fast speed accepts 0.01–64 units/tick; both steps accept 0.01–1024 units;
the lowering gap accepts 0–128 units. Invalid profiles retain the previous
settings. Tests also exercise a complete profile with different values.

Busy sectors keep their existing mover. Once-only walk actions are consumed
on crossing even when their sectors are busy; once-only use actions require
a successful start. Valid occupants can block upward travel without releasing
the sector, and movement resumes when clear. The existing controller carries
players and grounded things. These actions preserve floor surfaces and sector
specials, including values transferred by earlier actions 37/84. Original
snapshots retain their previous heights and textures.

Other surface-changing floors, crushers, sounds, monster activation
and exact classic plane timing remain open.

Complete profiles also require the later donut speed; see [donut floors](DONUTS.md).

## Verification (2026-11-07)

The final Windows and Linux native suites exercise 40 engine/game check groups
and 449 generated WAD fixtures. `DoomFloorVariantsSmoke` covers all eleven
actions, speeds and destinations, consumption/repetition, equal/higher or absent
neighbors, blocked/resumed planes, immutable snapshots, switch composition,
lower-and-change followed by a large raise, accepted versus blocked movement,
player riding and failed map replacement during motion. Existing floor-change,
door-occupant, combat, loading and rendering regressions are included.

Windows command:

```powershell
python scripts/build.py --platform windows --build-dir build/floor-variants-final-windows check
```

The executable and matching configuration are in `build/floor-variants-final-windows`.
The shared engine is at `0434a6e774cb408d1063c1e8af666f8a09e18859`.

Linux verification uses WSL Ubuntu 24.04 and the local MiniA2 2026.09.26 SDK.
That SDK predates required logging/configuration and X11 focus support. Only
the isolated build receives the vendored `YAML.Mod`/`Logging.Mod`, plus
`Inputs.Mod`/`Unix.KbdMouse.Mod` from local MiniA2 revision
`9dc73cfe91ee000e55615557855a6c2f8cb4e913`. The SDK and MiniA2 sources remain
unchanged. The window executable links on the Linux filesystem before copying
back: this SDK's final chmod step fails when output goes directly to DrvFS.
Standard Linux commands require an SDK with the focus API described in
[PLATFORMS.md](PLATFORMS.md).

Linux X11 scenarios verify the built-in scene, movement/release/focus/turning,
Escape shutdown, fast-nearest and fixed-step walk actions, and the one-shot
turbo-lower switch texture. Local commands and output are recorded in
`scratch/verify_synced_linux.py`, `scratch/floor-variants-final-linux.log` and
`scratch/floor-variants-final-windows.log`. Output is in
`build/floor-variants-final-linux/ao-doom`. This is scoped regression evidence;
original IWAD campaign playthroughs, A2 and A64/QEMU were not rerun.
