# Non-crushing ceiling actions

Use action 41 lowers tagged idle ceilings to their captured floor and consumes
its line after a successful start. Action 43 performs the same lowering with a
repeat button. Busy targets retain their current owner; an entirely busy group
does not consume a use action or toggle its switch. Matching idle targets start
independently. Buttons retain the existing material and release-timer behavior.

Crossing action 40 raises tagged ceilings to the highest adjacent ceiling,
without the gap used by doors. Accepted player crossings in either direction
activate it; use, gun hits and blocked movement do not. The one-shot line is
consumed even if targets are busy. The original action tries ceiling motion
before floor motion; its shared sector owner prevents the subsequent floor
operation. This implementation preserves that effective ceiling-only behavior.

Destinations are captured at activation. Floors, surfaces and sector specials
remain unchanged. The existing `DoomDoors.Controller` handles both doors and
these non-crushing ceilings. Manual door toggles cannot reverse an active
ceiling action. No engine, MiniA2, SDK or platform source changes were needed.

Lowering checks the player and valid solid actor volumes before publishing each
ceiling snapshot. An obstruction pauses motion without damage or reversal,
retaining ownership. Movement resumes after clearance. Non-solid and invalid
spawn volumes retain the existing preview policy. Failed map replacement keeps
the current world and motion; hidden upper wall resources validate first.
The engine still owns immutable geometry, anchors, collision and rendering.

## Configuration

Every complete external profile must add:

```yaml
ceilings:
  speed_per_tick: 1
```

The speed accepts 0.01-64 Doom map units per simulation tick. It is independent
of door and floor speeds. Missing fields, invalid types and out-of-range values
reject the profile without replacing prior settings. The alternate test profile
uses speed 3, compared with door speed 4 and floor speed 2. No compiled fallback
values or duplicate YAML settings were added.

## Reference and limits

References are id Software's [ceiling controller](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_ceilng.c#L163),
[use actions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_switch.c#L379)
and [crossing action 40](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c#L617).
Raise destinations never fall below the initial ceiling. Isolated or already
high sectors complete with zero travel; negative heights use the real maximum
neighbor rather than a zero sentinel. These are deliberate safe bounds rather
than reproductions of vanilla edge-map quirks. A source shortcut comment marks
the boundary. Exact classic plane timing, sound and crushing remain open.

## Running

```sh
python3 scripts/build.py --build-dir build/ceilings-linux check
cd build/ceilings-linux
./ao-doom ceiling-use-gui.wad E1M1
./ao-doom ceiling-40.wad E1M1
```

Press E in the first map; walk forward with W in the second. Matching Windows
files are under `build/ceilings-windows`; A2 packages are under
`build/ceilings-a2-{unix,win}`. Both new cases are included in `task gui-check`.

## Verification (2026-11-15)

- The first action-41 test failed on the preceding game state with
  `Trap 5.8 (ASSERT failed)` at the rejected use. Final Linux and Windows SDK
  suites pass 45 engine/game groups using 513 generated WAD fixtures. Windows
  uses its native SDK under Wine, not a native Windows host.
- Six TEST procedures cover all three actions, use/repeat/consumption, ignored
  gun and out-of-range crossings, blocked movement, maximum neighbor selection,
  negative/isolated/already-high sectors, busy/grouped targets, player and actor
  obstruction/release, manual-door isolation, button materials/deadlines,
  old rendered snapshots, failed map replacement and custom speed. Configuration
  checks cover missing settings, invalid types/ranges and preserved settings.
- Five Linux X11 scenarios pass in an owned Xephyr display: demo controls,
  lowering/raising ceilings, texture-height floors and a tagged door. Windows
  physical E/W cases pass with motion after key release, settling and Escape
  shutdown. Before/after frames were visually inspected.
- Default-camera Windows/Wine captures were ambiguous because the view tilted;
  the decisive GUI cases use a separate copied profile with mouse sensitivity
  0.00001 and pitch limit 0. Ceiling tuning, game sources and the executable are
  unchanged. A fixed-camera headless render confirms the expected closing view.
  Fixed-delay checks caught changes before input and after walking; the final
  driver waits for three unchanged frames before input and after motion.
  This does not establish native Windows mouse/camera behavior.
- Full-symbol A2 Unix64/Win64 builds each compile 37 modules. Both 117-entry ZIP
  packages pass integrity checks. No A2 runtime or hardware was exercised.
- Original IWAD/campaign checks remain unavailable because their asset location
  is unknown. Native Windows, A2 runtime, A64, CI, hardware, crushing, sounds and
  exact classic timing remain unchecked or unimplemented.

Local logs, hashes and orchestration are under `scratch/ceilings-*` and
`scratch/verify-ceilings-*.py`. The preceding uncommitted texture-floor stage,
engine changes, previous builds and root `scene.ppm` are preserved.
