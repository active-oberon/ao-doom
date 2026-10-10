# Pickup and inventory check

Checked: 2026-10-10 UTC / 2026-10-11 Europe/Kyiv. Original assets remain the
external archives listed in [the original-map report](original-map-check.md).

The previous implementation rendered visible objects without collecting them.
A headless probe walked 40 ticks through the passable `sprites-grate.wad`
portal to x=1.6, within reach of its armor bonus at x=2. Comparing the scene
above the future status panel against geometry alone found 24852 differing
pixels. Its expected disappearance assertion returned `Trap 5.8 (ASSERT failed)`.
The same probe passed after pickup integration. The grille's map flags remain
passable as agreed with the user; only the item's gameplay behavior was added.

## Implementation

- `DoomInventory.State` owns health, armor/type, four ammo stocks/capacities,
  nine weapon ownership bits, six key bits, backpack state and pickup count.
  A new game or successful map load resets it to 100 health, no armor/keys,
  fist/pistol and 50 bullets. Failed replacement loads preserve inventory.
- Thirty classic placed-item types apply health/armor, ammo, weapon ownership,
  backpack and key effects. Supply limits determine acceptance. Bonuses,
  duplicate keys and full backpacks retain their consumption rules. Backpack
  capacity increases once. Full armor retains its current type when a
  megasphere supplies health. Placed weapons grant ammo without selecting or
  firing a weapon. Timed powers and berserk are deliberately left in the map.
- `DoomSprites.Touch` checks classic axis overlap using a 20-unit pickup radius
  plus the player radius and a vertical reach of -8 units to player height.
  A bounded portal trace additionally prevents collecting through solid
  walls, blocking lines or openings too short for the player. This physical
  path guard is intentionally stricter than the original thing-first traversal;
  this is not an exact recreation of every original collision ordering detail.
- Actors and image arrays remain shared immutable data. Accepted pickups copy
  one `SET32` bitset per simulation tick and publish a new scene. Its maximum
  copied payload is 8192 bytes for the 65536-record map limit. No useful pickup
  returns the same scene; collected objects never supply effects twice.
  Earlier render snapshots retain their original visible objects. `Count`
  now reports remaining visible objects rather than total loaded actors.
- The game captures camera, world, sprite scene and a value copy of inventory
  together under its monitor; rendering then holds no game lock. The bottom
  20 pixels show health, armor, all ammo stocks, pickup/weapon counts and
  colored card/skull indicators. `DoomHud` owns the layout. Generic `GameText`
  uses an original clipped 3-by-5 font without assets or heap allocation.

## Verification

- `task check` passed four engine executables, generated 142 original WAD
  fixtures, passed the new inventory/pickup checks and all existing archive,
  material, grille, sector, BSP, door and movement checks, then compiled the
  Linux64 window. Inventory checks cover all 30 supported type IDs, refill
  limits, medicine rejection, capped bonuses, weapon ownership/ammo, all keys,
  repeated/full backpacks, full-armor megaspheres, unsupported effects and
  reset behavior. Text checks cover glyph coverage, spacing and edge clipping.
- Pickup integration covers exact horizontal/vertical reach limits, passable
  and blocking grilles, closed portals, absent-material solid boundaries,
  33 simultaneous items across a bitmap-word boundary, rejected medicine and
  powerups, scene identity without effects, immutable old snapshots and
  disappearance from the rendered scene. Game checks confirm tick-driven
  collection, inventory copy isolation, failed-load preservation, load reset
  and a blue key on the displayed panel.
- `task gui-check` passed ten scenes: corridor, single-sector, multi-sector,
  sky, BSP, grille, sprites, sprites behind a grille, pickups and doors. The
  new pickup check walks into actual items and compares the status panel.
  Key release, focus loss, turning, Escape and held/released Space still pass.
  Both GUI and headless visibility checks exclude the panel so text alone
  cannot mask a blank scene; a focused HUD-only rejection check also passed.
- All 132 supplied original maps passed loading, start/walk rendering, 35
  forward ticks, 97 turning ticks and a valid standing pose. Doom passed 36/36;
  Doom II, TNT and Plutonia passed 32/32 each in 25.0 seconds total. All four
  SHA-256 values match the original-map report. These checks ran before the
  final explicit bitmap-width cleanup; focused pickup/sprite/inventory checks,
  GUI compilation, the normal `task check`, the actual pickup window and four
  representative original starts passed afterward on the final binaries.
- Inspected `pickups-before.ppm`, `pickups-after.ppm`, `pickups-hud.ppm` and
  original Doom E1M1 / Doom II, TNT and Plutonia MAP01 start captures. The panel
  reflects six accepted fixture items: health 101, armor 1, ammo 70/12/20/1,
  three owned weapons and a blue key. Assets and captures remain ignored.
  Source operation layout passed 36 modules; whitespace and Python syntax
  checks passed. MiniA2 remains unchanged and clean; the installed Linux64
  SDK was used. No failing checks remain in the final stated suites.

The megasphere case was corrected during source review and checked before
commit. The SDK's plain `SET` follows address width, so the collection array
now explicitly uses `SET32`; the 33-item boundary test passed on that final
representation. No new dependency or original game asset was added.

## Reproduce and limits

```sh
task check
task gui-check
task run -- build/pickups.wad E1M1
task run -- build/sprites-grate.wad E1M1
task run -- '/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2/DOOM.WAD' E1M1
```

Keys are recorded but do not unlock doors yet. Weapon selection/firing, damage,
solid actor collision, monster behavior, actor animation, powerups, sound,
map-to-map inventory continuity and dropped loot remain absent. Megasphere
effects are not restricted by game family. Pickup scans visit loaded actors
each tick and path checks stop after 256 hits; there is no actor spatial index.
Performance targets, full playthroughs, original pixel/collision equivalence,
other platforms and Brutal Doom PK3 behavior were not established.
Implementation and reporting are saved in separate local commits; no pushes,
merges or deployments were made.

Behavior facts were checked against id Software's
[p_inter.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_inter.c),
[p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c)
and [info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).
The inventory, scene updates and font are original implementations.
