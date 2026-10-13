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

This step adds immutable animation playback and shared sloped ray clipping.
Walking, attacks and impact/barrel animations use the same engine timing.
Sight, player/enemy bullets and blast cover use shared world ray geometry.
The game still owns which animation runs and what a collision or frame means.

## Remaining delivery areas

- Map progression: tagged doors and switches, floor/ceiling actions, lifts,
  crushers, teleporters, exits, secret exits, sector damage and secrets.
- Actor behavior: all classic monsters, movement and route finding, sound wake,
  attack/pain/death states, projectiles, infighting, drops and boss actions.
- Classic combat and inventory: all weapon states including BFG spray, damage
  rules and randomness, ammo behavior, powers, protection and timed effects.
  Current magazines/reload, fixed damage/spread and simplified AI differ from
  the originals and must be addressed before claiming classic compatibility.
- Presentation and audio: weapon view animation, HUD/status face, automap,
  effects, sound playback/mixing, music and suitable platform adapters.
- Game flow: title/menu, episodes and skill selection, new/restarted games,
  pause, saves/loads, intermission statistics, campaign transitions and endings.
- Compatibility: remaining map/object semantics, simulation timing, movement,
  demo recording/playback and multiplayer behavior. Split delivery into tested
  stages; these items remain open until implemented and validated.

Expand generic volume sweeps, animation/state scheduling, moving geometry and
audio mechanisms in the engine as the corresponding classic game features
need them. Prioritize playable map progression and remaining classic behavior
after the current engine extraction is validated. Further projects are reviewed
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
