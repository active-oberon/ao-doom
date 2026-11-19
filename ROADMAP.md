# Classic Doom and Doom II

## Target

Implement complete classic Doom and Doom II games in Active Oberon, backed by
reusable sector-based mechanisms in ao-game-engine. Doom 3, Doom 3: BFG Edition
and Quake are deferred. The original BFG weapon belongs to the classic games
and remains part of this target. Current map probes and combat features do not
constitute complete game implementations.

## Ownership

ao-game-engine owns reusable simulation, clocks, sector geometry, collision,
rendering, animation timing, buffers, display presentation and bounded reads.
Move a mechanism when the running game supplies a concrete caller and tests;
keep game formats, authored data, actor rules, damage and progression in ao-doom.
Existing YAML remains the sole authored source for tuning and entity appearance.

Implemented shared mechanisms include immutable animation playback, sloped ray
clipping and observations of accepted movement. Walking, attacks and effects
use engine timing; sight, bullets and blast cover use engine ray geometry.
Exit crossings follow accepted axis substeps, including collision sliding.
The game owns activation, routes, inventory policy and resource validation.

## Delivered progression stage

Normal and secret exits work through use actions (11/51) and line crossings
(52/124). Mandatory YAML routes cover Doom episodes 1-4 and Doom II, including
secret-map returns. A transition validates the next map and carried projectile
images before replacement, preserves health/armor/weapons/ammo/backpack, and
clears keys and level pickup state. Failed transitions preserve the active map
and inventory. Terminal routes freeze gameplay and show an authored completion
label. Typed transition events are logged outside simulation and rendering.
This stage uses immediate transitions; original intermissions, finales and
secret-exit fallback for editions without MAP31 remain open. Exit switch
materials are covered by the later switch/button stage below.
Evidence and exact limits are recorded in scratch/exits-check.md.

## Delivered tagged door stage

Tagged door actions now cover 18 use switches/buttons, 14 walk triggers and
the repeatable hitscan action 46. Matching idle sectors open, close, raise/wait/
close or close/wait/reopen, with normal/fast speeds and card/skull locks.
Accepted player movement supplies crossing observations; actual hitscan pellets
report reached lines after geometry and actor clipping. Existing engine ceiling
snapshots handle movement and rendering. Mandatory YAML supplies all door timing.
Closing doors now stop or reverse for valid solid actor volumes, including
footprints reaching from neighboring sectors; see docs/DOOR_OCCUPANTS.md.
Sound, monster activation and actor crushing remain open. Switch presentation
is covered below. Earlier evidence is in scratch/tagged-doors-check.md.

## Delivered floor and lift stage

Seventeen floor actions lower to neighboring heights or raise to the next floor
or surrounding ceiling; eight normal/fast lift actions lower, wait and return.
Mandatory YAML supplies floor/lift speeds and wait timing. Shared DoomActions
keeps consumed lines and sector occupancy consistent across doors, floors and
exits. A completed floor action no longer hides a later door behind its portal.
Engine WithFloors snapshots preserve ceilings and update geometry, collision,
ray clipping, texture anchors and rendering. TouchesSector limits occupant checks.
Player and grounded things ride accepted planes; valid solid volumes prevent
pinching, and obstructed rising lifts reverse. Pre-existing invalid spawn
volumes keep the preview behavior and do not stop planes. Remaining floor
variants, crushers, sound and classic
ordering/timing fidelity remain open. Evidence is in scratch/floors-check.md.

## Delivered additional floor variants

Actions 58/92 raise by a configured fixed step; 140 raises by a larger step.
Actions 36/70/71/98 lower quickly to the highest neighboring floor plus a gap
when its height differs, without raising the target sector. Actions 129-132
raise quickly to the next higher floor. Mandatory YAML supplies fast speed,
both fixed raises and the lowering gap. Existing shared ownership, obstruction,
switches, surface snapshots and player riding apply. Regression coverage includes
lower-and-change followed by a fixed raise, accepted versus blocked crossings
and failed map replacement during motion. See docs/FLOOR_VARIANTS.md.
Remaining floor/ceiling actions, crushers, sound and exact classic timing remain open.

## Delivered player teleport stage

Player crossing actions 39/97 select a type-14 destination by sector and thing
order. Valid landings use the current floor and marker facing. Telefrag damage
is published only with a successful landing. Crossing observations stop at
the successful trigger, and complete YAML profiles supply reaction time and
damage. Coverage includes front/back boundaries, consecutive triggers,
one-shot consumption after failure, blocked landings and movement after the
reaction pause. See the [configuration and behavior](README.md#current-state).
Monster teleports, teleport fog and sound remain open.

## Delivered switch and button stage

Implemented use/gun actions toggle authored front-side texture pairs; repeat
buttons restore their initial image on an independent timer without extending
the deadline on reactivation. Shared sidedefs update every wall that uses them.
Game activation and mandatory YAML own pair order, names and release timing;
the engine only replaces wall materials in immutable geometry snapshots.
Upper/middle/lower selection, dimensions, pegging and moving plane composition
are covered by engine and game checks. Both matched images validate before
publishing a level. Existing immediate exits update their material first;
intermissions, switch sounds and edition-specific behavior remain open.
Evidence and exact validation limits are in scratch/switches-check.md.

## Delivered perpetual platform stage

Crossing actions 53/87 start perpetual platforms between the lowest/highest
neighboring floors. Actions 54/89 pause platforms by tag, including normal/fast
lifts. Activation through 53/87 resumes the saved direction or remaining wait;
ordinary lifts still finish at their original height. Paused platforms retain
sector ownership, repeated starts/stops preserve state, and ascending obstruction
reverses motion. The existing engine handles snapshots, collision and occupants.
Mandatory YAML supplies perpetual speed and the existing platform wait.
Initial direction uses a controller-local random generator; shared classic
randomness, exact classic mover timing, monster activation and sound remain
open. Evidence and validation limits are in scratch/platforms-check.md.

## Delivered stair actions

Actions 7/8 and 100/127 build slow/fast stair chains through use or crossings.
Directed two-sided adjacency preserves WAD order and floor-name matching,
including untagged steps and busy-sector behavior. Loader reachability covers
hidden lower wall materials before map publication; the existing engine handles
plane snapshots, riding and obstruction. Mandatory YAML owns both speeds and
step sizes. Sound, crushing and exact classic plane timing remain open.
Evidence and limits are in scratch/stairs-check.md.

## Detailed application logs

Application logs now include use results, focus, inventory, damage, death,
weapon and ammunition changes outside the simulation/rendering methods.
Evidence and limits are in scratch/stairs-check.md.

## Delivered lowering floors with surface changes

Crossing actions 37/84 lower tagged floors and copy the first matching
neighbor's captured floor surface and sector special after successful arrival.
The existing floor speed, occupancy/riding and shared action table apply.
Updated names participate in later stair chains, with conservative directed
reachability for hidden-material validation when surface-changing actions exist.
The engine adds immutable `World.WithFloorTexture`; model choice, sector
metadata and timing remain game-owned. Sector-special effects remain open.
Evidence: docs/FLOOR_CHANGES.md.

## Delivered raising floors with surface changes

Crossing actions 59/93 raise tagged idle floors by the configured fixed step.
They immediately copy the triggering line's front-sector floor texture, name
and special code, before the first movement tick. Busy targets retain their
surface and owner; blocked motion retains the newly copied surface and resumes
when clear. Changed names feed later stairs and their hidden-material validation.
Existing YAML, shared immutable snapshots, riding and occupancy mechanisms apply
without platform-specific gameplay code or new engine APIs. Windows/Linux checks,
Linux X11 scenarios and a full-symbol A2 Win64 build cover this stage; the A2
build does not establish runtime behavior. Evidence: docs/FLOOR_CHANGES.md.

## Delivered donut floors

Use action 9 lowers tagged pillars and raises their untagged rings to a captured
outer-neighbor height. Both sectors must be idle before the pair starts; each
keeps ownership through obstruction and completion. Ring texture/name changes
and clearing its sector special happen only after successful arrival. Existing
engine snapshots, collision and riding apply on every platform; mandatory YAML
supplies the speed. Hidden ring materials, true nested sectors, reversed sides,
failure/rollback and custom settings are covered. Linux and Windows SDK checks,
Linux/Windows GUI scenarios and full-symbol A2 Unix64/Win64 builds pass with the
limits recorded in docs/DONUTS.md. Classic unsafe malformed-map behavior,
sound, crushing and exact mover timing remain open.

## Delivered changing platforms

Actions 14/15/20/22/47/66/67/68/95 immediately copy the triggering front-sector
floor surface and raise by a fixed step or to the next higher neighbor.
Fixed raises preserve sector effects; nearest raises clear the special code.
Shared ownership, reversal/retry, stop/resume, switches and carried occupants
use the existing controller and engine snapshots. Gun hits publish surfaces to
the active game world while traces retain captured geometry. YAML supplies
raising speed and the 32-unit step; the 24-unit step reuses floor tuning.
Linux and Windows SDK checks, six GUI scenarios and full-symbol A2 Unix64/Win64
builds pass with the limits in docs/CHANGING_PLATFORMS.md. Exact classic timing,
original obstructed-raise quirks, sound and sector effects remain open.

## Delivered texture-height floors

Crossing actions 30/96 raise tagged floors by the shortest present lower wall
texture on both sides of their two-sided boundaries. Targets capture current
switch materials at activation. Existing floor speed, ownership, riding,
obstruction and map replacement rules apply. The engine's copied `WallAt`
accessor shares plane-anchor resolution with ray hits; Doom retains action
classification and texture-height selection. Linux and Windows SDK checks,
five GUI scenarios and A2 Unix64/Win64 builds pass. Absent lower materials are
skipped rather than emulating vanilla texture-zero quirks; original-map and
campaign evidence remains open. See docs/TEXTURE_FLOORS.md.

## Delivered non-crushing ceilings

Actions 41/43 lower tagged ceilings to their captured floor through one-shot
or repeat use. Crossing action 40 raises them to the highest adjacent ceiling
without a door gap. The existing ceiling controller, immutable engine snapshots,
occupancy checks and shared sector ownership apply. Blocked lowering retains
ownership and resumes without reversal or damage. Mandatory `ceilings` YAML
owns the speed. Manual doors cannot reverse an active non-door ceiling.
Action 40 retains the original ceiling-first ownership behavior, leaving floors
unchanged. Safe bounds for isolated/already-high sectors, exact classic timing,
sounds and crushing remain compatibility boundaries. See docs/CEILINGS.md.

## Remaining delivery areas

- Map progression: remaining floor/ceiling actions,
  crushers, monster teleporters, sector damage and secrets, plus original exit visuals
  and edition-specific behavior.
- Actor behavior: all classic monsters, movement and route finding, sound wake,
  attack/pain/death states, projectiles, infighting, drops and boss actions.
- Classic combat and inventory: all weapon states including BFG spray, damage
  rules and randomness, ammo behavior, powers, protection and timed effects.
  Current magazines/reload, fixed damage/spread and simplified AI differ from
  the originals and must be addressed before claiming classic compatibility.
- Presentation and audio: weapon view animation, HUD/status face, automap,
  effects, sound playback/mixing, music and suitable platform adapters.
- Game flow: title/menu, episodes and skill selection, new/restarted games,
  pause, saves/loads, intermission statistics and original campaign endings.
- Compatibility: remaining map/object semantics, simulation timing, movement,
  demo recording/playback and multiplayer behavior. Split delivery into tested
  stages; these items remain open until implemented and validated.

Expand generic volume sweeps, animation/state scheduling, moving geometry and
audio mechanisms in the engine as the corresponding classic game features
need them. Prioritize playable map progression and remaining classic behavior
after the current progression stage. Further projects are reviewed
after the classic game target is achieved.

## Completion evidence

Require scoped engine tests and Doom integration tests for each added behavior,
plus original-map loading, rendering and interaction regressions. Complete the
supported Doom and Doom II campaigns using real exits, keys and actions, rather
than granting resources in isolated probes. Validate game flow, inventory,
weapons, monsters, saves, audio and compatibility separately. Record differences
from original behavior and do not equate short start/walk probes with playthroughs.

Native Linux64, A64/QEMU and Windows x64 have scoped test evidence. The A2
desktop adapter compiles against full A2 symbols and its hosted harness starts
the window system and game window; see docs/PLATFORMS.md. Native A2 boot,
other targets and physical hardware still need their own evidence; a hosted
run does not establish bare-metal readiness.
