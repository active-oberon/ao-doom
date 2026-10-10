# Locked manual door check

Checked: 2026-10-10 UTC / 2026-10-11 Europe/Kyiv. Original assets remain the
external IWADs listed in [the original-map report](original-map-check.md).

Collected keys previously had no door effect: manual types 26-28 and 32-34
were unsupported. Before changing the controller, a game probe collected a
blue card by strafing six ticks in the new synthetic room, asserted that the
card was in inventory, then pressed Use. Its assertion that the type-32 door
started opening returned `Trap 5.8 (ASSERT failed)`. The same probe passed
after integration.

## Implementation

- Types 26/32 require blue, 27/34 yellow and 28/33 red. Either the card or skull
  of that color works. Keys are not consumed. Types 26-28 use the existing
  two-unit-per-tick raise/wait/close cycle and can toggle while active; types
  32-34 stay open and consume their line action. Key authorization happens
  before changing an active door's direction. Existing unlocked normal/fast
  types and player-clearance reversal retain their behavior.
- Front-side, 64-unit range and occlusion guards still apply. Supporting the
  additional actions also preloads their future upper materials through the
  existing `Moving` check; malformed or missing hidden materials reject the
  map before publication.
- `DoomDoors.Use` receives the player's inventory on the simulation tick.
  Denied locked-door use sets a required-color hint. `DoomHud` draws it in
  the existing panel, using the same captured inventory value as the key
  indicators. The next use attempt, matching key pickup or successful map
  load clears it. Failed loads preserve it. Hints deliberately have no expiry.
- A key picked up after a denied Use does not reuse that old interaction:
  releasing and pressing Space again is required. The new `door-key.wad`
  contains an open-only blue door and a blue card 64 units to the player's
  right. It uses the existing original synthetic sprite and map resources.
  The passable grille's flags and actor collision rules were not changed.
- The engine and MiniA2 source trees remain unchanged. This milestone uses
  the installed Linux64 SDK, existing immutable geometry and bitmap text.

## Verification

- `task check` passed four engine executables, generated 157 original WAD
  fixtures and passed the archive, materials, grilles, sprites, inventory,
  pickups, sectors, BSP, unlocked doors, locked doors and movement suites.
  The original-map and unlocked-door probes passed on fixtures; the Linux64
  window compiled. A separate `--keys` probe passed on `door-blue.wad`.
- The new locked-door suite checks all six types with each matching card and
  skull, denial with no keys or all other colors, exact range/back-side guards,
  blocked/one-sided traces, key retention and active-door authorization.
  It verifies motion speed, the 150-tick wait, closure/reopening, persistent
  open-only behavior, immutable old worlds and six hidden-material rejections.
  The real game case checks queued denial, actual sprite pickup, hint clearing,
  a fresh Use, opening/crossing, snapshot isolation and successful-load reset.
- `task gui-check` passed all eleven scenes. The new owned-window check first
  confirms an unchanged closed view and a blue missing-key hint, then actually
  strafes into the blue card, checks its indicator and cleared hint, presses
  Space again and observes the open doorway. Movement, release, focus loss,
  turning and Escape also passed. Existing held/released Space, closing and
  reopening checks passed. A focused locked-door window run passed too.
- All 132 supplied maps passed load, start/walk rendering, 35 forward ticks,
  97 turning ticks and standing clearance: Doom 36/36, Doom II 32/32, TNT 32/32
  and Plutonia 32/32. All four SHA-256 values match the original-map report.
- Original locked-door probes passed Doom E1M2 line 528/type 28, Doom II MAP02
  line 396/type 32, TNT MAP02 line 704/type 26 and Plutonia MAP04 line 199/type
  27. Line indices are zero-based. The probe checks denial with no keys, grants
  all six keys explicitly, opens for 70 ticks and verifies crossing/clearance.
  It places the player in front of a door; it does not collect original keys
  along a route from the player start.
- Inspected `locked-door-missing.ppm`, `locked-door-key.ppm` and
  `locked-door-open.ppm`: the hint appears on denial, clears when the blue
  card is collected, and the passage becomes visible after opening. Captures,
  external archives and generated fixtures remain ignored. Operation layout
  passed 37 modules; whitespace and Python syntax passed.

## Failed attempts and environment

The initial broad caller edit accidentally added an inventory parameter to a
test helper; its `less actual than formal parameters` compiler errors were
fixed before the full checks. The new original-door probe initially used
`CONTINUE`, which this Active Oberon compiler rejected as `Undeclared
Identifier`; a conditional body replaced it. Both corrected modules passed.

TNT MAP01's fixed-position door probe returned `No reachable supported manual
door was found` and `Command not successful`. Its two blue lines exist (395 and
398), but this probe did not find a usable standing/blocked-trace position.
The aggregate script stopped there after all 132 map checks had passed.
A subsequent four-archive probe run used TNT MAP02 and passed every case.
This does not establish that the MAP01 door is unusable in normal play.

One sandboxed read failed before execution with `bwrap: Can't bind mount / on
/: Unable to apply mount flags` for the unavailable `music-mxbox` mount.
Authorized native commands completed the affected reads/builds/window checks.
No failing checks remain in the final required task suites.

## Reproduce

```sh
task check
task gui-check
task run -- build/door-key.wad E1M1
# Try Space without a key, briefly hold D, release Space and press it again.
task door-check -- '/path/to/DOOM.WAD' E1M2 --keys
```

## Limits and sources

Locked tagged switches (99 and 133-137), other tagged/walk-over actions, lifts,
moving floors, combat, solid actor collision, monster behavior, sound and
timed powers remain absent. Messages do not expire until another interaction,
matching pickup or map reset. Whole-level completion, finding every original
key along a route, every original door, exact pixels/collision equivalence,
performance targets, other platforms and Brutal Doom PK3 behavior were not
verified or remain unsupported. Use retains its existing 256-hit trace limit.

Manual action colors, card/skull equivalence, active-door authorization and
raise/open cycles are referenced from id Software's
[p_doors.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c).
No upstream implementation code was copied.
