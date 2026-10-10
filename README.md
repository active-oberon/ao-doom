# ao-doom

A Doom clone in Active Oberon built on the separate
[ao-game-engine](../ao-game-engine) project.

## Current state

A runnable Linux64 scene renders at 320 x 200 and scales to a 640 x 400 window.
It has fixed 35 Hz simulation, keyboard movement, turning, wall collision and
sliding. The built-in corridor scene runs without any game assets.

The WAD loader validates classic Doom archives and loads maps with multiple
sectors. Classic SEGS/SSECTORS/NODES provide validated BSP sector lookup;
maps without that data use closed contours, including holes. It reads player
starts, vertices, linedefs, sidedefs, sector heights and light levels. Sector
openings reveal the rooms behind them, with upper/lower wall textures and projected floor/ceiling
flats. Fullbright sky panoramas use SKY1-SKY4 selected by episode/map number;
adjacent sky sectors hide their upper wall even when ceiling heights differ.
Explicitly absent wall textures (`-`) are accepted and omitted. Movement
respects blocking lines, 56-unit player clearance and a maximum 24-unit step.
Exact tangent contact with a wall is valid; inverted sector heights describe
closed regions and remain impassable.
Two-sided middle textures now draw fences and grilles with transparent patch
holes. Opaque black pixels remain visible. Layered grilles retain the nearest
covered pixel, repeat horizontally, and draw their height once inside the
sector opening. Sidedef offsets and top/bottom pegging remain active while
ceilings move. Blocking flags still decide whether the player can cross.
Space activates manual doors from their front side within 64 Doom units.
Types 1, 31, 117 and 118 are unlocked. Types 26/32 require blue, 27/34 yellow,
and 28/33 red: either a card or a skull of that color works without consumption.
Types 26-28 raise, wait and close; 32-34 stay open and consume their line action.
Their ceilings animate, open the passage, and either
stay open or wait 150 ticks before closing. Closing reverses if the player would
lose clearance. Normal doors move two units per tick; fast doors move eight.
Sprites for 116 classic visible object types render at their spawn frames: monsters,
pickups, decorations and corpses. Medium-skill single-player flags select them.
Directional frames support all eight views and paired mirrored lump names;
patch header offsets position each image. Transparent holes, opaque black,
sector lighting, fullbright objects and ceiling attachments are preserved.
Walls, grilles, planes and overlapping sprites share depth checks. Actors
remain at spawn frames without solid actor collision or animation. Unknown
types are skipped for previewing,
and spectres currently render without the original fuzz effect. The WAD
scene loads wall textures from PLAYPAL, PNAMES and TEXTURE1/TEXTURE2, composing
classic column patches. The built-in scene uses original procedural brick textures.

Touching 30 classic placed-item types now updates the player's inventory and
removes accepted pickups: health/armor, ammunition, weapons, backpacks, cards
and skull keys. Health and armor bonuses can reach 200; ordinary medicine stops
at 100. Ammo and armor remain in the map when they cannot improve the current
stock. Bonuses, duplicate keys and backpacks retain their classic consumption
rules. The backpack doubles ammo capacity once. Placed weapons grant ownership
and ammunition; weapon selection and firing are not implemented.
The bottom 20 pixels show health, armor, four ammo stocks, total pickups,
weapon count and colored key indicators (`C` card, `S` skull; blue/yellow/red).
Trying a locked manual door without its key shows the required color in the panel.
The hint clears on the next use, matching key pickup or successful map load;
it has no timed expiry. Collecting a key requires a fresh Space press to use it.
Pickups require horizontal overlap, reachable height and a clear physical path;
solid walls, blocking grilles and closed portals prevent collection through them.
The existing `sprites-grate.wad` grille stays passable by its map flags.
Timed powers and berserk remain visible until their effects are implemented.
Successful map loading resets inventory; failed replacement loads preserve it.

## Build, run and check

Install the MiniA2 Linux64 SDK (`ob`), Task, Python 3, and `timeout`:

```sh
task check
task run
```

Controls: W/S or Up/Down move, A/D strafe, Left/Right turn, Space uses, Escape exits.
Holding Space issues one action until release; losing focus clears held input.
Linux execution needs an X11 display. The installed SDK must contain the
key release and focus notification fixes in MiniA2 `source/Unix.KbdMouse.Mod`; older drivers
leave movement keys held after release or focus loss.

`task build` produces `build/ao-doom`. The default engine checkout is
`../ao-game-engine`; override it with `ENGINE_DIR=/path/to/ao-game-engine`.

The native MiniA2 language server reads `sourcePaths` from `a2pkg.json` to find the
engine without editor-specific environment variables. If the engine checkout is
elsewhere, update that relative or absolute path in the manifest too.
Sources are staged in `build/`, with no shared compiler objects between trees.
Staging clears generated objects/symbols so a changed engine record cannot link
against objects left by a manual `ob compile`.

```sh
# A local compatible WAD, followed by its map name (default E1M1).
task run -- /path/to/local.wad E1M1
# Original synthetic map generated by task check; no Doom assets needed.
task run -- build/valid.wad E1M1
# Three connected rooms, a step and a lower ceiling.
task run -- build/sectors.wad E1M1
# A closed manual door; press Space, then walk through.
task run -- build/door.wad E1M1
# A locked blue door: try Space, briefly strafe right with D to collect its key,
# release Space, press it again, then walk through.
task run -- build/door-key.wad E1M1
# A grille with transparent holes; the line permits crossing.
task run -- build/masked.wad E1M1
# Original synthetic sprites behind a grille.
task run -- build/sprites-grate.wad E1M1
# Walk into health/armor, ammo, a key, a weapon and a backpack.
task run -- build/pickups.wad E1M1
# Local base-game archives; quote paths containing spaces.
task run -- '/path/to/DOOM.WAD' E1M1
task run -- '/path/to/doom2.wad' MAP01
# Load, render, advance movement and turn without an X11 display.
task wad-check -- '/path/to/DOOM.WAD' E1M1
# Place a probe near a closed manual door, open it and verify crossing.
task door-check -- '/path/to/DOOM.WAD' E1M1
# Probe a locked door: verify denial, supply keys to the probe, then cross.
task door-check -- '/path/to/DOOM.WAD' E1M2 --keys
# Targeted events and frame reads in the program's own X11 window.
task gui-check
```

`task check` runs engine checks, generates 157 original WAD fixtures, rejects
malformed archives and maps, and checks movement/collision before building the
windowed executable. Door checks cover animation, clearance, closing/reopening,
use range/side/occlusion and texture anchoring. Locked-door checks cover all six
types with cards and skulls, wrong colors, key retention, active-door toggles,
hidden material validation and actual tick-driven pickup/unlocking.
It exports `build/locked-door-missing.ppm`, `build/locked-door-key.ppm` and
`build/locked-door-open.ppm`, plus
`build/pickups-before.ppm`, `build/pickups-after.ppm` and `build/pickups-hud.ppm`, plus
`build/sprites-scene.ppm`, `build/sprites-layered.ppm`,
`build/sprites-grate.ppm` and `build/sprites-facing.ppm`, plus
`build/masked-scene.ppm`, `build/masked-reverse.ppm` and
`build/masked-layered.ppm` for grille inspection, plus
`build/scene.ppm` and `build/wad-scene.ppm` for
inspection, plus four views of the multi-sector map and `build/sky-scene.ppm`.
`task wad-check` rejects completely empty start/walk frames and writes
`build/original-start.ppm` and `build/original-walk.ppm`;
it requires an absolute WAD path because the check runs in `build/`.
`task door-check` writes `build/original-door-closed.ppm` and
`build/original-door-open.ppm`; it requires an absolute WAD path and fails if
there is no supported closed door with a valid probe position. It checks an
isolated crossing, not the route from the map's player start. With `--keys`,
it selects locked manual doors, verifies denial with no keys, then explicitly
grants all six keys to the probe; it does not find the keys along a playable route.
`task gui-check` additionally verifies eleven scenes: corridor, single-sector,
multi-sector, sky, BSP, grille, sprites, sprites behind a grille, pickups, doors
and a locked door with an actual key pickup.
Each checks movement, release, focus loss, turning, and Escape shutdown.
The pickup scene walks into items and checks that the inventory panel changes.
Both windowed and headless visible-scene checks exclude the status panel so
text alone cannot hide an empty map frame.
The door scene also checks held/released Space, closing and reopening.
The locked-door scene checks the missing-color hint, card pickup, hint clearing,
opening after a new Space press and movement through the doorway.
It needs Xlib and an accessible X11 server. Each check launches a temporary
copy of the executable so it identifies
its own window even when another copy of the game is running.
`task bench` measures 200 textured frames without display transfer.
Invalid WAD startup returns failure rather than entering the loop. The texture
loader validates patch references, column offsets, post lengths and terminators.
It bounds dimensions to 1024, decoded cache pixels to 16 million and decode work
to 64 million samples/posts/columns. Flats require exactly 4096 palette indices
and share these resource budgets with wall textures; their caches are separate
even when names match. Sprite patches share these budgets but cache by lump
index. Sprite frame directory lookup has a separate 64-million-work budget;
THINGS is capped at 65536 records. Missing, malformed, conflicting or incomplete
directional frames reject a known visible object. Map contour validation is
capped at 64 million work units.
BSP decoding caps SEGS at 65536 and SSECTORS/NODES at 32768 each, validates
indices/ranges and requires child nodes to precede parents, preventing cycles.
Subsector membership follows its first seg; unused sectors are retained.
It supports opaque wall materials, masked middle textures and classic patches;
extended tall-patch support is absent.

## Project boundary and next milestones

Reusable simulation, geometry, rendering, buffers, timing, display presentation,
and bounded binary reads belong in `ao-game-engine`. Doom WAD interpretation,
map semantics, player rules and compatibility belong here. `DoomWad` handles the
archive, `DoomTextures` handles graphics data, and `DoomMap` constructs the scene.
`DoomThings` owns spawn-frame facts; `DoomSprites` loads immutable actors,
chooses directional images and publishes copied collection bits after pickups.
`DoomInventory` owns item effects; `DoomHud` owns the status panel layout.
Game state uses a monitor; rendering captures camera, inventory,
the sprite scene and the sealed world together before
working without the game lock.

A short headless load/render/movement check passed all 132 maps from the supplied
Doom, Doom II, TNT and Plutonia IWADs, up from 90 before BSP lookup. Interactive
validation and archive hashes are in [the original-map report](scratch/original-map-check.md).
Exact portal starts, including Doom E4M5, select the sector ahead of each ray
to avoid a blank view at a zero-distance boundary.
Manual doors from Doom E1M1 and Doom II/TNT/Plutonia MAP01 passed the opening
and crossing probe. Details and limits are in [the door report](scratch/doors-check.md).

The masked-wall checks and a fresh 132-map regression are recorded in
[the grille report](scratch/masked-check.md).
Sprite checks, another 132-map regression and inspected captures are recorded
in [the sprite report](scratch/sprites-check.md). The reusable frame depth buffer
adds 512000 bytes at 320 x 200 and avoids sprite sorting or per-frame allocation.
Pickup checks and the new original-map regression are recorded in
[the inventory report](scratch/pickups-check.md). Collection copies at most an
8192-byte bitset per tick that accepts items; frames without pickups reuse it.
Locked-door checks and another 132-map regression are recorded in
[the key-door report](scratch/locked-doors-check.md).

Next: solid actor collision, combat and other map actions.
Door motion publishes copied ceiling heights on shared immutable geometry, so
rendering and collision use a consistent world snapshot. Floors remain fixed;
stepping changes eye height immediately, and drops
snap to the floor without gravity or view smoothing. Short checks do not prove
whole-level traversal, original pixel accuracy or complete game compatibility.
Tagged switches (including locked switches), walk-over triggers, lifts and sound
are unsupported.
Brutal Doom/Project Brutality PK3 scripts and gameplay are not supported.

## Source style and references

Follow [AGENTS.md](AGENTS.md): each Active Oberon operation and control-flow body
has its own line.

Use id Software's [linuxdoom-1.10](https://github.com/id-Software/DOOM/tree/master/linuxdoom-1.10)
as the behavior reference. The archive and map format references are
[w_wad.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/w_wad.c)
[doomdata.h](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/doomdata.h),
[r_data.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_data.c),
and [r_segs.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_segs.c).
Sky selection/mapping follow [g_game.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/g_game.c)
and [r_sky.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_sky.c).
BSP loading/lookup and tangent collision follow
[p_setup.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_setup.c),
[r_main.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_main.c)
and [p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).
Manual door types, speed, waiting and targets are referenced from
[p_doors.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c)
and [p_spec.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c).
Sprite metadata, directional naming and spawn flags are referenced from
[info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c),
[r_things.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_things.c)
and [p_mobj.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_mobj.c).
Pickup quantities and limits follow
[p_inter.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_inter.c).
The current parser and engine are original implementations; no upstream source
has been copied. Preserve applicable license notices when porting code later.

Doom WAD game data is separately licensed and is not included. Generated test
WADs are original fixtures under ignored `build/`. Keep local WADs out of Git.
