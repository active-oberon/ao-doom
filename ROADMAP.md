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
This stage uses immediate transitions; original intermissions, finales, switch
texture changes and secret-exit fallback for editions without MAP31 remain open.
Evidence and exact limits are recorded in scratch/exits-check.md.

## Delivered tagged door stage

Tagged door actions now cover 18 use switches/buttons, 14 walk triggers and
the repeatable hitscan action 46. Matching idle sectors open, close, raise/wait/
close or close/wait/reopen, with normal/fast speeds and card/skull locks.
Accepted player movement supplies crossing observations; actual hitscan pellets
report reached lines after geometry and actor clipping. Existing engine ceiling
snapshots handle movement and rendering. Mandatory YAML supplies all door timing.
Switch texture changes, button reset timing, sound, monster activation and actor
obstruction remain open. Evidence and exact limits are in scratch/tagged-doors-check.md.

## Remaining delivery areas

- Map progression: switch visuals/buttons, floor/ceiling actions, lifts,
  crushers, teleporters, sector damage and secrets, plus original exit visuals
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

Native Linux64 and A64/QEMU remain the current tested environments. Full A2,
other platforms and physical hardware need their own evidence; a hosted run
does not establish bare-metal readiness.
