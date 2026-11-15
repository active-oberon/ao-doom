# Floors raised by texture height

Crossing action 30 starts a one-shot raise; action 96 repeats. Every idle sector
with the triggering tag captures its current floor plus the shortest present
lower wall texture on either side of its two-sided boundaries. One-sided and
unrelated boundaries do not supply candidates. Side orientation does not change
the result. Texture heights come from validated WAD resources, including lower
materials hidden at load time and current switch/button replacements.

The destination is captured once. Changing a wall material during motion does
not retarget that motion; a later repeat activation uses the new material and
current floor. Floor texture, name and sector special remain unchanged. Existing
`floors.speed_per_tick` supplies the speed, with no new YAML fields or fallback
tuning constants. All platforms use the same game controller.

Accepted player crossings activate the action in either direction; use and
gun hits do not. One-shot crossings consume their line even when every target
is busy. Repeat crossings retain it. Grouped targets keep independent ownership.
Obstruction pauses an ascending floor without damage, reversal or releasing
its sector; it continues when clear. Existing snapshots carry the player and
grounded objects. Failed map replacement preserves the active motion.

## Shared engine API

Matching ao-game-engine sources must provide `World.WallAt(index)`. It returns
a copied directed wall with current materials and resolved moving-plane anchors.
The ray caster uses the same resolution, preserving its previous behavior.
The accessor requires a sealed world and a valid insertion index. Editing the
returned record cannot mutate any world. The engine owns geometry and immutable
snapshots; action IDs, boundary selection and target policy remain in Doom.

## Reference and compatibility boundary

Behavior references are id Software's
[raiseToTexture target selection](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_floor.c#L353)
and [crossing actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c#L581).
The implementation skips absent lower materials (`-`). With no candidates,
including geometry-only maps, the action completes with zero travel. It does
not reproduce vanilla's texture-zero alias or missing-candidate arithmetic.
A source shortcut comment records this boundary for later demo compatibility.
Exact classic mover timing, sounds, crushing and campaign compatibility remain
outside this stage.

## Verification (2026-11-15)

```sh
python3 scripts/build.py --build-dir build/texture-floors-linux check
cd build/texture-floors-linux
./ao-doom floor-texture-game.wad E1M1
```

Walk forward with W to cross the trigger and ride the raised floor.

- The new action-30 test failed against the original published game with
  `Trap 5.8 (ASSERT failed)`. Final Linux and Windows SDK suites pass 44 engine/
  game groups using 501 generated WAD fixtures. Windows ran under Wine, not on
  a native Windows host. An initial sandbox Wine attempt ended with SIGSYS;
  the completed check used an owned temporary Wine prefix outside the sandbox.
- Six TEST procedures cover both actions, crossing directions/range, ignored
  use/gun input, shortest materials on both sides, reversed boundaries,
  absent/invalid/hidden resources, negative starting heights, actual switch
  replacements with different image heights, captured and repeated targets,
  busy/grouped sectors, obstruction, actor/player riding, blocked movement,
  failed map replacement, old snapshots and custom floor speed.
- Four Linux scenarios pass on an owned Xephyr display: demo controls, the new
  walk-triggered floors, changing platforms and donuts. Windows on that display
  passes physical W activation, visible motion, settling and Escape shutdown.
  Its before/after frames were visually inspected. The main desktop's keyboard
  layout was not changed. The new case is included in `task gui-check`.
- Full-symbol A2 Unix64/Win64 builds each compile 37 modules. Both 117-entry ZIP
  packages pass integrity checks. These are compilation/package checks.
- Three interleaved runs of the existing 200-frame demo benchmark take 623 ms
  before extraction and 623-634 ms after it. This small scene does not establish
  performance on large original maps.
- Original IWADs and campaigns, native Windows, A2 runtime, A64, CI and hardware
  were not checked. The original IWAD location remains unknown.

Ready executables are `build/texture-floors-linux/ao-doom` and
`build/texture-floors-windows/ao-doom.exe`, with matching profiles and fixtures.
A2 packages are under `build/texture-floors-a2-{unix,win}`. Local logs, hashes
and orchestration are under `scratch/texture-floors-*` and
`scratch/verify-texture-floors-*.py`. No MiniA2 or SDK source changed.
