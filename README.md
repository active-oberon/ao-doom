# ao-doom

A Doom clone in Active Oberon built on the separate
[ao-game-engine](../ao-game-engine) project.
The target is a complete Active Oberon implementation of classic Doom and Doom II
on a reusable sector-based engine. Current coverage is partial; the remaining
work and acceptance criteria are in [ROADMAP.md](ROADMAP.md).
These sources require ao-game-engine commit `d90c17d` or a compatible later
revision providing `GameAnimation`, `World.TraceRay`, `World.MovePlayerObserved`
and `GameGeometry.Crossing`, together with `World.WithFloors` and
`World.TouchesSector` for moving floors and occupant checks. Switches/buttons
use `World.WithWallTexture` and its three material-part identifiers.

## Current state

A runnable Linux64 scene renders at 320 x 200 and scales to a 640 x 400 window.
It uses fixed simulation steps at 35 Hz in the standard YAML profile. It supports
keyboard movement, turning, wall collision and sliding. The built-in corridor
scene runs without any game assets.

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
E activates manual doors from their front side within 64 Doom units.
Types 1, 31, 117 and 118 are unlocked. Types 26/32 require blue, 27/34 yellow,
and 28/33 red: either a card or a skull of that color works without consumption.
Types 26-28 raise, wait and close; 32-34 stay open and consume their line action.
Their ceilings animate, open the passage, and either
stay open or wait 150 ticks before closing. Closing reverses if the player would
lose clearance. Normal doors move two units per tick; fast doors move eight.
Tagged use switches/buttons (29/42/50/61/63/99/103/111-116/133-137), walk
triggers (2/3/4/16/75/76/86/90/105-110) and hitscan lines (46) also control
doors. One line starts every idle sector with a matching tag, including tag
zero; an active tagged door ignores additional activations. One-shot use
actions remain available when no door starts; one-shot crossings consume the
action even when targets are busy, as in the original games. Card/skull locks
also apply to the six fast tagged open actions. Close-only doors stop at player
obstruction and continue when clear; raise and close/wait/open doors reverse.
Actions 16/76 restore the original ceiling after `doors.close_wait_ticks`
(1050 in the standard profile). This field is mandatory in custom profiles.
Door sounds, monster activation and obstruction by actors remain unimplemented.
Floors now support 17 lower/raise actions: lower to the highest or lowest
neighbor floor, raise to the next higher floor, or raise to the surrounding
ceiling. Eight normal/fast lift actions lower to the lowest neighboring floor,
wait and return to their original height. Use, accepted player crossings and
hitscan activate the corresponding classic linedefs. Shared action state prevents
multiple movers owning one sector and preserves consumed actions across
controllers. Player and grounded things ride the plane; valid solid volumes
block pinching. Blocked ascending lifts reverse. Existing invalid spawn volumes
retain preview behavior. `floors.speed_per_tick` and the mandatory `platforms`
speed/wait settings supply all tuning; the standard profile uses 1, 4/8 and 105
respectively. Crossing actions 53/87 start perpetual platforms between their
lowest and highest neighboring floors, with a wait at each end. Actions 54/89
stop matching platforms, including ordinary lifts. A later 53/87 resumes their
saved direction and remaining wait without releasing sector ownership or
changing their original lift behavior. Repeated starts leave active motion
unchanged. Blocked ascending platforms reverse without crushing occupants.
Mandatory `platforms.perpetual_speed_per_tick` supplies their speed (1 map unit
per tick in the standard profile, valid range 0.01-64). Custom complete profiles
must add this field. Initial directions use MiniA2's local random generator;
the shared classic random sequence and exact classic mover timing remain open.
Remaining floor variants, surface changes, crushers and sound are not implemented.
Stair actions 7/8 build slow steps and 100/127 build fast steps through use or
crossing triggers. Chains follow two-sided lines from front to back, in WAD
order, while floor names match; untagged neighbors join the chain. Busy steps
remain owned by their existing controller. Newly visible lower wall materials
validate before map replacement. Player and grounded objects use the existing
floor riding and obstruction checks. Mandatory `stairs` YAML supplies speed and
step height: the standard profile uses 0.25/4 units per tick and 8/16-unit steps.
Implemented use/gun switches now toggle their front sidedef's upper, middle or
lower texture, choosing the first authored pair and then upper/middle/lower.
One-shot switches stay changed; repeat buttons restore the initial image after
`switches.button_ticks` (35 in the standard profile). Repeated activations do
not extend a button's first deadline. Use requires a successful action; gun
actions 24/46 toggle even when their sector is busy. Locked/busy use actions,
manual doors and walk triggers do not animate switches. Shared sidedefs update
all their directed walls; old render snapshots retain their original materials.
Mandatory `switches.pairs` supplies the 40 classic texture pairs in order, with
`off` and `on` names; arbitrary custom names also work. Both images of a matched
front sidedef validate before map replacement, including hidden parts. Unused
pairs need no WAD resources. Complete custom profiles must add this section;
missing, duplicate, malformed or excessive definitions fail validation. Exit
switches update before the existing immediate transition or terminal label;
failed transitions retain their current retry behavior. Switch sounds and
original intermissions remain open.
Sprites for 116 classic visible object types load their spawn frames: monsters,
pickups, decorations and corpses. Medium-skill single-player flags select them.
Directional frames support all eight views and paired mirrored lump names;
patch header offsets position each image. Transparent holes, opaque black,
sector lighting, fullbright objects and ceiling attachments are preserved.
Walls, grilles, planes and overlapping sprites share depth checks. The 60 classic
solid object types now block player movement with their original footprint radii:
monsters, barrels and solid decorations. Both horizontal axes must overlap;
exact tangent contact is allowed. Player collision ignores actor height, so
solid hanging bodies block even when their images are above the player.
Pickups, corpses and non-solid hanging variants remain passable. Each axis
substep checks actors before updating position or floor height, preserving
sliding and bounded movement without jumping through a footprint. Actors
switch to configured corpse frames when killed. Demons and spectres wake on
sight, chase the player with wall/step/actor collision, animate walking and
wind up before each bite. An impact rechecks sight and range, so moving away
or killing the attacker prevents damage. Green and blue armor absorb configured
fractions of damage; health clamps at zero and death stops movement, turning,
firing, door actions and further monster updates. Restart or load a map to reset.
Zombiemen and shotgun soldiers also wake on sight and chase into attack range.
Their delayed hitscan attacks aim at the player's current height and stop at
solid walls or closed openings. Grilles pass bullets independently of their
movement flags. Each pellet hits the nearest damageable target: enemies and barrels
can intercept shots meant for the player. Killed enemies cannot attack later in
the same tick. Soldier attacks use fixed damage and symmetric pellet spread;
retaliation against another monster and original randomized AI are absent.
Imps now launch visible fireballs after a configured windup. Flight aims at the
player's position at launch, so movement can dodge it. Walls, openings and sector
planes stop projectiles; other damageable actors can intercept them. Direct
damage uses the existing armor rules, and fired projectiles survive owner death.
Rocket, fireball, plasma and BFG impacts animate their configured frames. Destroyed
barrels animate, detonate after a configured delay and can ignite nearby barrels;
they disappear when their animation ends. Cover and armor also apply to these blasts.
Other unsupported actors retain their spawn positions. Movement, health and pickup snapshots
preserve each other's state and keep previous render snapshots unchanged. Unknown
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
and ammunition. Digits 1–7 select owned weapons using classic Doom slots;
repeating 1 toggles fist/chainsaw and 3 toggles shotgun/super shotgun. The wheel
cycles owned weapons. First selection loads available reserve into its magazine;
later switching preserves magazines and cancels a pending reload. Inventory ammo
includes loaded rounds, so stowed magazines cannot duplicate shared bullets or shells.
LMB fires the selected weapon; R reloads over configured ticks and firing pauses
until completion. Empty magazines require R. Fist/chainsaw use close-range hits,
pistol/chaingun use rays, shotguns use configured pellet fans, and rocket/plasma/BFG
use visible projectiles. Rockets add distance-attenuated blast damage on their
first actor, decoration, wall or plane impact. The standard profile supplies
128 damage over 128 Doom units, in addition to the fixed direct hit. Cover
blocks the blast; open grilles pass it, and the shooter can be hurt through the
normal armor rules. The original BFG secondary effect is absent. The selected weapon,
loaded rounds/reserve or reload status appear above the status panel. Solid walls and closed openings stop shots; two-sided windows and
grilles pass them when the shot fits the open height, even if movement is blocked.
Dead monsters remain visible and no longer block movement.
The bottom 20 pixels show health, armor, four ammo stocks, total pickups,
weapon count and colored key indicators (`C` card, `S` skull; blue/yellow/red).
Trying a locked manual door without its key shows the required color in the panel.
The hint clears on the next use, matching key pickup or successful map load;
it has no timed expiry. Collecting a key requires a fresh E press to use it.
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

Default controls: WASD moves/strafes, mouse motion turns/pitches the view, LMB
fires, RMB aims while held, R reloads, digits 1–7 or the wheel select weapons,
E uses nearby manual doors, tagged switches and exits; Escape closes the window. Pickups are automatic on contact.
Up/Down, Left/Right and Ctrl remain secondary keyboard bindings in YAML.
Letter bindings currently require an English keyboard layout on X11.
Holding E issues one action until release. Losing focus clears held buttons,
keys and pending input, restores normal aim and releases pointer confinement.
The Linux X11 adapter captures only the focused game window and recenters the
hidden pointer for unlimited turning. Escape and loop shutdown release capture.
RMB zooms the view and lowers mouse sensitivity; pitch shifts the existing 2.5D
projection rather than rotating a 3D camera. Hits and projectiles follow its slope.
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
# A closed manual door; press E, then walk through.
task run -- build/door.wad E1M1
# A locked blue door: try E, briefly strafe right with D to collect its key,
# release E, press it again, then walk through.
task run -- build/door-key.wad E1M1
# A tagged switch opens the distant door; press E, then walk through.
task run -- build/tagged-door-gui.wad E1M1
# Crossing the line opens the distant door.
task run -- build/tagged-door-90.wad E1M1
# Shoot the line with the pistol to open the distant door.
task run -- build/tagged-door-gun-portal.wad E1M1
# Stand on the lift, press E, ride down and return.
task run -- build/floor-lift-ride.wad E1M1
# Walk across the trigger to lower the distant platform.
task run -- build/floor-88.wad E1M1
# Walk onto the perpetual platform; cross the far edge to stop it, then return to restart.
task run -- build/platform-riding.wad E1M1
# Press E to raise a staircase, then walk up its steps.
task run -- build/stairs-gui.wad E1M1
# Shoot the line with the pistol to raise the floor.
task run -- build/floor-gun.wad E1M1
# A grille with transparent holes; the line permits crossing.
task run -- build/masked.wad E1M1
# Original synthetic sprites behind a grille.
task run -- build/sprites-grate.wad E1M1
# Walk into health/armor, ammo, a key, a weapon and a backpack.
task run -- build/pickups.wad E1M1
# Shoot a target twice with LMB, then walk over its corpse.
task run -- build/combat.wad E1M1
# A demon approaches and bites; LMB shoots, S retreats.
task run -- build/ai.wad E1M1
# A zombieman fires at range; LMB fires back.
task run -- build/hitscan.wad E1M1
# A shotgun soldier fires three pellets with configured spread.
task run -- build/hitscan-shotgun.wad E1M1
# An imp launches visible fireballs; strafe to dodge and LMB to fire back.
task run -- build/projectiles.wad E1M1
# Walk toward a solid barrel, then strafe or move diagonally around it.
task run -- build/actors-barrel.wad E1M1
# Shoot the first barrel twice; watch the delayed chain clear all three barrels.
task run -- build/barrels-chain.wad E1M1
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

`task check` runs engine checks, generates 397 authored WAD fixtures, rejects
malformed archives and maps, and checks movement/collision before building the
windowed executable. Door checks cover animation, clearance, closing/reopening,
use range/side/occlusion and texture anchoring. Locked-door checks cover all six
types with cards and skulls, wrong colors, key retention, active-door toggles,
hidden material validation and actual tick-driven pickup/unlocking.
Tagged-door checks cover all 33 actions, multi-sector tags, busy targets,
one-shot/repeated activation, both key forms, player obstruction, accepted
crossings, clipped hitscan and preservation after a missing texture fails loading.
Floor checks cover all 25 actions, shared consumption, busy sectors, riding,
solid obstruction, lift reversal, terrain snapshots and hidden-material failure.
Actor checks cover solid monsters/barrels/decorations, tangent and corner
contact, long movement, sliding, steps, passable corpses/hanging variants/items,
spawn flags, overlapping starts and successful/failed replacement loads.
They export `build/actors-blocked.ppm` and `build/actors-sliding.ppm`.
Explosion checks export `build/explosion-first.ppm` and `build/explosion-second.ppm`.
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
`task gui-check` additionally verifies thirty-five scenarios: corridor, single-sector,
multi-sector, sky, BSP, grille, sprites, sprites behind a grille, pickups, doors
and a locked door with an actual key pickup, plus solid barrel collision, two
pistol scenarios with default/remapped keys, a chasing demon, a ranged soldier,
an imp, a rocket blast, a barrel explosion chain and the modern mouse controls,
plus normal/secret exits, campaign completion and a missing next map.
Three scenarios activate tagged doors by use, crossing and shooting; three
more check lift riding/return and floor activation by crossing or hitscan.
One checks perpetual platform movement, waiting and reversal while riding.
One raises a staircase through a use action and checks the visible result.
Three check a permanent switch, button release and a hitscan switch texture.
Combat checks verify ammunition, corpse rendering, release and focus-loss handling.
Remapping runs the same executable with another complete YAML file.
The existing scenes check movement, release, focus loss, turning and Escape.
The modern scenario checks yaw/pitch, repeated recentering, LMB, RMB/release,
magazine depletion, R reload, digit/wheel selection and actual focus transfer to
another owned window. It verifies pointer release and clears firing on refocus;
all GUI checks restore the prior focus and pointer after closing their processes.
The demon scenario waits for chase and bite without player input, then uses
a complete startup YAML with higher pistol damage to kill it and verifies
that its movement, animation and attacks stop.
The soldier scenario verifies health loss at range and stopped attacks after a
kill. Weapon/input scenarios use a complete YAML with static target behavior to
isolate keyboard effects from autonomous attacks and animated frames.
The pickup scene walks into items and checks that the inventory panel changes.
The barrel scene approaches the actor, verifies that another forward input
leaves the view unchanged, and checks diagonal sliding around it.
Both windowed and headless visible-scene checks exclude the status panel so
text alone cannot hide an empty map frame.
The door scene also checks held/released E, closing and reopening.
The locked-door scene checks the missing-color hint, card pickup, hint clearing,
opening after a new E press and movement through the doorway.
It needs Xlib and an accessible X11 server. The same scenarios validate JSON startup/shutdown records, typed fields and
component context. A separate logging probe checks the headless entry and four
startup errors, including an escaped missing-file path. `gui-check` builds its
headless probe and runs it from the WAD fixture directory.
Each check launches a temporary
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

## Startup configuration

Active Oberon uses `CONST` for fixed values and records for runtime settings.
`DoomConfig.values-` exports the validated settings as read-only data; consumers
use typed fields instead of repeatedly querying a generic YAML tree.

`DoomConfig` reads `doom.yaml` from the working directory before the window opens.
Edit it and restart the same executable; recompilation is unnecessary. Use
`./build/ao-doom --config /path/to/doom.yaml [wad [map]]` for another file.
`task build` copies the repository's configuration into `build/` for runs from
that directory. The window remains 640 x 400; `video` controls the rendered frame,
which must fit the display. Missing files, unknown keys, invalid types, duplicate
keys, values outside their limits and HUD layouts outside the frame abort startup.
The file must contain every section and setting; missing fields also abort
startup. `doom.yaml` is the only source of the standard profile, with no compiled
fallback values. Failed reads preserve previously loaded settings.

Distances use Doom map units. Player and door speeds are per simulation tick;
turning uses radians per tick. `simulation`, `player`, `doors` and `hud` control
timing, collision dimensions, motion, door interaction and panel layout/colors.
`player.pickup_radius` and `pickup_below_feet` control item reach.
`stairs` requires `speed_per_tick`, `fast_speed_per_tick`, `step` and `fast_step`.
Speeds accept 0.01-64 map units per tick; steps accept 0.01-128 map units.
Complete external profiles must add this section; there are no fallback values.
`inventory` supplies initial health/bullets, health/armor limits, ammo capacities,
pickup amounts, box/weapon/backpack multipliers and green/blue armor damage
divisors; values must fit HUD digits.
`combat.pistol` supplies fixed damage, cooldown/flash ticks, ammo cost and range.
`combat.aim` supplies crosshair radius/gap in pixels and normal/shot RGB colors.
`things` defines the visible object types. Every entry requires `kind`,
`spawn_frame`, `fullbright`, `ceiling`, `height` and `radius`. The standard profile
contains all 116 previously supported classic types. Frame names have five
characters: the sprite prefix plus a frame letter. Heights and radii use Doom map
units and can be fractional; zero radius leaves an object passable. Height sets
the ceiling offset for hanging objects and the target volume for combat actors.
Ceiling objects require positive height. The table accepts at most 128 unique
IDs from 1 to 65535; dimensions must lie between 0 and 1024. Spawn resources for
objects used by a map are validated before replacing the live scene.
`combat.actors` references `things` by `kind` and supplies starting health,
five-character death frames and `behavior: static`, `melee`, `hitscan` or `projectile`.
Every actor rule also requires `explosion`: explicit `null` disables it; a mapping
supplies `thing`, `frames`, `ticks`, `blast_damage`, `blast_radius` and `delay_ticks`.
The standard barrel uses 128 damage over 128 Doom units after 15 ticks. Its five
frames last 5, 5, 5, 10 and 10 ticks; the delay must be positive and shorter than
the complete animation. Newly destroyed neighbors start their own delay,
independently of their order in THINGS. Dead players freeze pending explosions.
Actor height and radius come exclusively from `things` and must be at least one
map unit;
the old `combat.actors.height` and `radius` fields are rejected. Active rules require
`speed_per_tick`, `step`, `sight_range`, `range`, `damage`, `windup_ticks`,
`cycle_ticks`, `frame_ticks`, `walk_frames` and `attack_frames` under the matching
`melee` or `hitscan` section. Hitscan rules also require `pellets` (1-32) and
`spread_radians` (0-1). Pellets spread symmetrically from negative to positive
spread; a single pellet uses the center direction. Damage applies per pellet.
Range measures Euclidean horizontal center distance; melee range must cover
the configured footprints. Ranged actors aim vertically at the player's center.
Speeds and steps use Doom units; attack and animation intervals use simulation
ticks. Each frame list contains 1-16 sprite prefixes with frame letters.
Windup must be shorter than the attack cycle; step must fit actor height and
attack range must fit sight range. Projectile rules also require `thing` and
`shot_speed_per_tick`: the referenced `things` entry supplies the projectile's
spawn frame, fullbright flag, height and radius. The standard profile uses the
local entity ID 60000 for an imp fireball; this is not a classic WAD object ID.
Projectile speed is total three-dimensional distance per tick, between 0.01 and
1024 Doom units; the attack range also limits total flight distance. The flight
aims at the player's center once at launch, allowing dodges, and starts at the
attacker's center. Projectiles require positive dimensions and ground attachment.
Static rules reject attack settings; active
rules reject a mismatched or additional attack section.
Actor health/height and terminal frame names follow
[id Software's actor/state table](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).
Each map validates its used corpse and animation resources before replacing
the live scene. The standard profile enables melee for demons/spectres and
hitscan for zombiemen/shotgun soldiers and projectiles for imps. Settings can enable other configured
ground actors with suitable sprite resources.
`controls` lists integer X11-compatible key symbols for all eighteen actions; aliases
must be unique across actions. Letters ignore Shift case so releasing Shift
cannot leave a key held. Releasing one physical alias preserves another held alias.
`aim` may have an empty key list because RMB supplies the default binding.
`mouse` supplies sensitivity, aim sensitivity multiplier, vertical inversion,
pitch limit (radians), aim zoom and fire/aim buttons (0 left, 1 middle, 2 right).
`combat.pistol` and `combat.weapons` supply ammunition, magazine capacity,
reload/cooldown ticks, damage/range, pellets/spread and display labels. Projectile
weapons reference `things` for flight appearance/dimensions and configure speed.
All projectile sections also require `blast_damage` and `blast_radius`; both
must be zero to disable the blast, or both positive to enable it. Damage is an
integer up to 65535 and radius is a finite value up to 65535 Doom units.
Imp, plasma and BFG blasts are explicitly disabled in the standard profile.
Every projectile also requires an `impact` mapping with `thing`, `frames` and
`ticks`. Impact and barrel animations take their first frame, height and
fullbright flag exclusively from the referenced `things` entry. `frames` lists
the following 1-15 frames; `ticks` provides one positive integer (1-1000) for
each complete frame, including the first. The standard effect IDs are 60004-60008.
The standard frame names and timing follow
[id Software's state table](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).
All used frames are validated and cached before a map replaces the live scene.
The blast uses maximum horizontal axis distance minus the target footprint,
quantized to whole Doom units, with linear falloff and sight traces between
impact and target centers. The distance model follows id Software's
[radius-attack reference](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c#L1097-L1126);
center-ray cover is conservative and does not reproduce the original sight cone.
Existing custom profiles need these new mandatory sections/fields. Chase moves
directly toward the player and slides along obstacles; route finding, sound
wake, original randomized attacks, monster death animations, drops,
boss actions/immunity, randomized spread/autoaim, weapon view animations,
full original BFG behavior and sound remain later milestones.
Imp fireballs have visible flight and direct fixed damage. Their swept actor
tests prevent tunneling at high speeds; walls, sector openings, floors and
ceilings clip flight. Movement-blocking grilles pass projectiles when their
openings fit. Solid decorations intercept them when YAML supplies positive
height/radius; legacy zero-height decorations currently have no projectile
volume. A fired projectile survives its owner's death; map replacement clears
all projectiles and effects only after validating resources. Old render snapshots preserve
flight positions, effect frames, actor health, pickups and detonation timing. The active-shot resource cap
is 256; launches above it are dropped. Visible impact/barrel effects have a separate
256-entry limit; exceeding it drops only the animation, preserving blast damage
and chain timing. Flight uses the configured spawn frame and switches to its
impact animation on collision. Blast damage
is applied once at the clipped impact position; range exhaustion does not
create a blast. Wall-face sweeps are expanded along the center ray; complete corner
footprint collision remains a later physics refinement.
`demo.colors` controls the procedural scene's outer walls, partitions and pillar,
including their brick textures. `demo.eye` and `demo.wall_height` use Doom map
units; the eye must not exceed the wall height. `demo.light` ranges from 0 to 255.
`demo.bricks` sets the square texture size, course height, brick width and mortar
width in pixels; alternating courses shift by half a brick width. Texture sizes
range from 1 to 1024; bricks must fit the texture and retain an interior. A mortar
width of zero removes joints; `mortar_shade` divides each RGB channel by a value
from 1 to 256. Demo and HUD colors are RGB integers from
`0x000000` to `0xffffff`. The panel renderer derives value
positions from label lengths and draws ammunition/key groups in loops.
Configuration is read once; changing a running game's geometry is unsupported.
Library callers must call `DoomConfig.Load(path, error)` before creating a game,
loading a map or drawing the HUD. `DoomConfig.loaded` reports whether loading
succeeded. The old `Doom.Player*` and `Doom.TicksPerSecond` constants are removed;
callers use the corresponding fields in `DoomConfig.values`.

The MiniA2 SDK must include the new `YAML` module in `std/encoding`; rebuild it
from the adjacent MiniA2 checkout after updating its sources. YAML uses the
existing `JSON.Value` containers and supports bounded configuration documents,
including nested mappings/sequences, inline collections, quoted strings and
finite numeric values. Tags, anchors/aliases, multiline scalars, complex/typed
keys and multiple documents are outside this parser's supported subset.
See MiniA2 `docs/YAML.md` for its API and exact limits.

`DoomFormat` holds file-format constants such as WAD record sizes and coordinate
scaling. Classic object IDs, item categories, internal states and sprite rotation
rules remain constants in code. Bounds, numeric precision and resource budgets
remain validation invariants. Gameplay, appearance and entity properties come
from YAML; `DoomThings` keeps identifiers and a lookup over the validated table.
`simulation.ticks_per_second` remains a startup setting, with 35 in the standard
profile. Speeds and durations are expressed per tick, so changing this frequency
changes game tempo. Code implements behavior algorithms; YAML selects their
parameters. Existing custom profiles must add `things` and move combat actor
heights/radii into it. There is no compiled entity table or fallback profile.
The procedural demo's wall coordinates and start position remain its authored
scene data.

`task check` runs `{TEST}` procedures from `DoomConfig`, `DoomHud`,
`DoomConfigSmoke`, `DoomInventorySmoke`, `DoomCombatSmoke`, `DoomAISmoke`,
`DoomHitscanSmoke`, `DoomProjectilesSmoke`, `DoomExplosionsSmoke`, `DoomExitsSmoke`,
`DoomControlsSmoke`, `DoomPlatformsSmoke`, `DoomStairsSmoke` and `DoomInput`
in executables with file fixtures. They verify complete YAML
loading, rejection of every missing section/field, invalid values, configured
wall colors, heights, lighting, brick dimensions/joints, movement, panel pixels,
door timing/range and failure preservation, plus target selection, ray height/range,
closed/open doors, blocking grilles, corpses, ammo/cooldown, custom tuning and
input aliases, wake/occlusion, chase collision, steps, animated frames,
windup/dodge, armor damage, death freeze and map replacement. Ranged checks cover
pellet spread/damage, sloped floor/ceiling occlusion, friendly interception,
same-tick death, complete custom tuning and resource failures. Modern-control
checks cover edge input, mouse focus clearing, pitch limits, aimed sensitivity,
partial/timed/cancelled reloads, shared ammo conservation, classic slots, owned
weapon cycling, melee/pellets/player projectiles, map reset and automatic pickups.
Rocket checks additionally cover footprint falloff/boundaries, diagonal distance,
walls/closed portals, open grilles, height-changing openings, self-damage/armor,
nearby victims, independent snapshots, no repeat damage, range expiry and custom YAML tuning.
Explosion checks cover frame boundaries and expiry, delayed and reversed chains,
cover, armor, frozen death, retained snapshots, custom delays, resource failure
preservation and 300 barrels exceeding the visual-effect limit.
Exit checks cover normal/secret use and accepted crossings, front-side/range
checks, episode/Doom II routes, carried inventory/projectile images, missing or
invalid next maps, retries, completion input freeze and authored custom routes.
Platform checks cover normal/fast lift stop/resume, both movement directions,
paused waits, shared ownership, grouped/unrelated tags, obstruction reversal,
custom speed/wait, accepted movement, carried player and failed replacement.
Stair checks cover all four actions, front/back direction, floor-name boundaries,
busy and grouped sectors, initial height differences, riding, obstruction,
hidden materials, failed map replacement, custom speeds/steps and old snapshots.
These executables run in `build/`:
these tests require real YAML/WAD files, which `ob test` does not copy into its
isolated case directories.

## Project boundary and next milestones

Reusable simulation, geometry, rendering, animation timing, buffers, display presentation,
and bounded binary reads belong in `ao-game-engine`. Doom WAD interpretation,
map semantics, player rules and compatibility belong here. `DoomWad` handles the
archive, `DoomTextures` handles graphics data, and `DoomMap` constructs the scene.
`DoomThings` owns object identifiers and searches the YAML entity definitions.
All spawn metadata and footprints come from `things`. `DoomActors` combines shared world sight traces with chase
and attack timing. `DoomSprites` resolves melee/hitscan impacts, loads immutable metadata and images, chooses
directional/animated/death frames and publishes collection/health/motion snapshots.
`DoomInput` collects keyboard/mouse actions; `DoomMouse` owns Linux X11 capture.
`DoomCombat` owns selection, magazines, reload/firing timing and aim/status overlays.
`DoomProjectiles` owns fixed flight directions, volume clipping and sector traces;
`DoomSprites` owns projectile state, rendering and impact damage.
`DoomInventory` owns item effects; `DoomHud` owns the status panel layout.
Game state uses a monitor; rendering captures camera, inventory,
the sprite scene and the sealed world together before
working without the game lock.
`GameAnimation` computes frame indices for walking, attacks and impact/barrel
effects from immutable timing clips. The game chooses images, start times,
looping, expiry and damage. `GameGeometry.World.TraceRay` supplies the shared
sloped ray used by player/enemy bullets and blast cover. It also clips floors
and ceilings within a sector, preventing rays from continuing through a plane
before reaching the next wall. `MovePlayerObserved` reports accepted axis
substeps; `Crossing` detects finite segment side changes. `DoomExits` queues the
first exit, and `DoomCampaign` resolves authored routes after movement finishes.

## Level exits and campaigns

Use E on front-facing exit lines 11/51, or cross lines 52/124, for normal/secret
exits. A mandatory `campaign` YAML section supplies `routes`, `status_x`,
`status_y`, `status_color`, `complete_text` and `error_text`. Each route requires
`name`, `normal` and `secret`; targets name another configured route, or use
explicit null to end the campaign. Names are case-insensitive WAD names of
1-8 letters/digits/underscores; duplicate names and invalid targets are rejected.
The standard profile covers all 68 Doom episode and Doom II map routes,
including secret-map returns. Custom complete YAML files must add this section.

The next map comes from the resident WAD archive. Its geometry, start and all
required images, including carried projectile weapons, validate before the
current level changes. Health, armor, weapons, ammunition, backpack capacities,
selected weapon and loaded magazines persist. Keys, pickup counters and hints
reset; active firing/reload/effects and camera pitch reset for the new spawn.
Failure keeps the current level and inventory, displays `error_text`, and allows
a new attempt. A null target freezes gameplay and displays `complete_text`.
Transitions are immediate: intermission statistics, original finale scenes
and the missing-MAP31 secret fallback remain open.

For an owned two-map demonstration, run `./build/ao-doom build/exits-use.wad E1M1`
after `task check`, then press E. Evidence: [the exit report](scratch/exits-check.md).

## Application logging

The SDK must include MiniA2 `Logging` (`std/logging`, introduced in commit
`890ac86`). Older installed bundles need rebuilding from updated MiniA2 sources.
`Doom.log` owns one JSON handler and a dedicated KernelLog stream writer with
`component=doom`. Game entries use INFO for configuration/map load and window
start/stop, and ERROR for startup/resource/display failures. Records carry UTC
timestamps and typed path/map/error, dimensions, tick rate and final tick/result
fields. No synchronous logging is added to simulation ticks or rendering.
The window drains rare transition events and logs `level transitioned`,
`campaign completed` or `level transition failed`, with typed previous/target,
kind, linedef index and error fields. Successful events use INFO, failures ERROR.
Kernel/driver diagnostics and test summaries can still use their existing output.

## Full A2 port assessment

Source inspection suggests moderate porting effort; no full-A2 compile or run
has been performed. The game rules, renderer and WAD reader mainly use common
Active Oberon libraries. The current executable entry and pointer capture use
Unix/X11 and require a native A2 launcher, display/window and input adapter.
A2 provides keyboard, wheel and relative mouse messages, but the port must also
handle focus, capture, key release and shutdown through its window system.

The inspected `a2oberon` tree has JSON and the parser/logging dependencies, but
lacks the MiniA2 YAML and Logging modules. Port those modules and verify compiler
and library API compatibility before estimating runtime performance. Start with
a 320x200 windowed scene in a running A2 system; a native boot image and physical
hardware performance are later checks. A64/QEMU headless tests do not validate
full A2 desktop or bare-metal execution. The user deferred the port and chose
to continue the game implementation.

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
Solid actor checks, the twelve-scene X11 run and a fresh 132-map regression are
recorded in [the actor report](scratch/actors-check.md). The engine accepts a
game-owned occupancy delegate without importing Doom types or changing the
existing `MovePlayer` interface. Actor collision currently scans the bounded
thing array; no spatial index or per-movement allocation was added.

Pistol, configuration, fourteen-window checks and the preceding 132-map regression
are recorded in [the combat report](scratch/combat-check.md). Shot hits copy at
most a bounded actor-health array; frames without hits reuse the previous scene.

Melee AI, armor damage, fifteen-window checks and the preceding 132-map regression
are recorded in [the AI report](scratch/ai-check.md). Active monster ticks copy
the bounded motion array; static or sleeping scenes reuse the previous snapshot.

Ranged soldiers, configurable pellet spread, sixteen-window checks and the preceding
132-map regression are recorded in [the ranged-attack report](scratch/hitscan-check.md).
Player and enemy shots share the same nearest-volume clipping; per-attack enemy
health copies are bounded, and multiple pellets reuse the private health snapshot.

Imp fireballs, projectile collision/resource bounds, seventeen-window checks and
the latest 132-map regression are recorded in
[the projectile report](scratch/projectiles-check.md). Five A64 suites passed
under QEMU. There is no complete-original-fidelity or full-playthrough claim.

Rocket blasts and visible impact/barrel explosions are recorded in
[the blast report](scratch/blast-check.md) and
[the explosion report](scratch/explosions-check.md).

Next: route finding, further monster attacks and map actions. Door obstruction remains player-only;
actor crushing and actor-triggered door reversal are not implemented.
Door motion publishes copied ceiling heights on shared immutable geometry, so
rendering and collision use a consistent world snapshot. Floor motion and walking update eye height immediately; drops
snap to the floor without gravity or view smoothing. Short checks do not prove
whole-level traversal, original pixel accuracy or complete game compatibility.
Remaining floor/ceiling actions, other lift variants and sound are unsupported.
Tagged-door evidence is in
[the tagged-door report](scratch/tagged-doors-check.md) and
[the floor/lift report](scratch/floors-check.md).
Switch/button evidence is in [the switch report](scratch/switches-check.md):
native checks and final focused reruns, ten A64/QEMU suites, 33 isolated window
scenarios, 132 short original-map checks and 14 isolated original-switch probes.
These do not establish campaign completion or full original fidelity.
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
Ranged soldier attack and target interception references are
[p_enemy.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c)
and [p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).
Current damage and symmetric pellet spread are simplified, configurable rules.
The current parser and engine are original implementations; no upstream source
has been copied. Preserve applicable license notices when porting code later.

Doom WAD game data is separately licensed and is not included. Generated test
WADs are original fixtures under ignored `build/`. Keep local WADs out of Git.
