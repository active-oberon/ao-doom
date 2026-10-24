# ao-doom session handoff

Updated: 2026-10-25

## Delivery checkpoint: detailed application logs (2026-10-25)

The user requested separate logical commits and joint publication to origin/main.
Stair actions are isolated in f7ccbc7, followed by feat(log): expand gameplay
event diagnostics. The earlier platform stage was published as 17227ca. This
publication approval is single-use. Engine main remains clean at d90c17d;
no engine or SDK source changed. Existing builds and scene.ppm are preserved.

Logs now include configuration/map details, focus, use acceptance/key denial,
pickups, damage/death, weapon selection, reload and ammunition. The window drains
the last use result and summarizes state changes outside simulation/rendering.
Cross/gun actions have no individual action record; state summaries are not
per-hit replays. Spawn coordinates use typed integers in map units because the
installed float formatter produced invalid JSON.

The final product sources match the previously validated snapshot: native task
check with 397 fixtures, seven A64/QEMU suites, 35 isolated GUI scenarios, five
logging cases, 132 original-map probes and 54 stair-line probes checking 446
changed-sector heights. Splitting also passed fresh native configuration/stair
tests and the window build on the independent stair-only snapshot. No broad
runtime suite was repeated after the documentation-only delivery updates.
Evidence: scratch/stairs-check.md, stairs-verification.json,
commit-split-check.log and commit-split-state.json.

Ready build: cd build/stairs, then ./ao-doom stairs-gui.wad E1M1. Its matching
YAML and a local original Doom II command are included. Next map work: surface
changes and donuts, then remaining plane actions, crushers, teleporters,
sector damage/secrets and sound. Full campaigns, classic randomness/timing,
CI, other platforms/hardware and maximum-scene stress remain unverified.
Non-English letter input remains unsupported.

## Delivery checkpoint: stair actions (2026-10-25)

This stage adds actions 7/8 and 100/127 for directed same-floor-name stair chains,
including untagged steps, busy-sector behavior and hidden-material validation.
Mandatory stairs YAML supplies both speeds and step heights. Existing floor
snapshots, player/actor riding and non-crushing obstruction are reused.
The user requested separate logical commits and joint publication to origin/main.
The platform stage was already published as 17227ca; the engine remains clean
at d90c17d. User-owned scene.ppm and existing builds are preserved.

Integrated validation passed native task check with 397 fixtures, seven A64/QEMU
suites, 35 isolated GUI scenarios, five logging cases, 132 original-map probes
and 54 stair-line probes. The stair-only commit also receives a separate native
configuration/stair build check after splitting. Evidence is in
scratch/stairs-check.md, stairs-verification.json and commit-split-check.log.
These checks are not full campaign playthroughs. Next map work remains surface
changes and donuts; the following commit adds the integrated log improvements.

## Delivery checkpoint: perpetual platforms (2026-10-25)

The user authorized committing and pushing the existing platform stage on
ao-doom main, then continuing the roadmap and expanding application logs.
A fresh isolated native task check passed all six engine executables and the
game suite with 387 authored WAD fixtures. Evidence: scratch/resume-baseline.log
and scratch/resume-state.json. The existing platform sources and ready demo
matched the saved verification hashes before this documentation update.
The sibling engine remains clean at d90c17d. User-owned scene.ppm is excluded.
Earlier A64, GUI and original-map evidence is retained below; those families
were not rerun for this delivery. This checkpoint supersedes the exit-only
stopping instruction below. Next: stair actions and detailed rare-event logs.

## Exit checkpoint: 2026-10-24

The user explicitly requested saving memory and leaving. Stop implementation
and testing; resume only after a new request. This checkpoint supersedes the
historical continuations below. No commit or push was requested or performed;
no publication approval is pending.

- Game main remains at ad9b2d1ad935b8560d7fe62a418abf4fc28fb811 with the
  perpetual-platform stage uncommitted. Engine main is clean at
  d90c17d0e74eeb615ff2ba1cd0f6d2c4a832a12c. Preserve all dirty game work,
  new tests/DoomPlatformsSmoke.Mod and user-owned untracked scene.ppm.
- Platforms: actions 53/87 start/resume and 54/89 stop normal, fast and
  perpetual lifts without losing direction, wait or sector ownership.
  Complete profiles require platforms.perpetual_speed_per_tick. See the
  continuation below and scratch/platforms-check.md for behavior and limits.
- Prior verification passed native task check, five A64/QEMU suites,
  34 isolated Xephyr scenarios, five logging cases, 132 original-map probes,
  ten original-platform probes and a separate ready-demo GUI check.
  Final equal-bounds tests pass native/A64: 387 fixtures and ten new TEST
  procedures. No runtime tests were rerun for this exit bookkeeping.
- The user ran build/platforms/ao-doom and reported needing arrow keys.
  WASD/E bindings are already in its matching YAML. Isolated layout tests
  pass English E/W/D and fail Russian/Ukrainian E activation. The user did
  not confirm their active layout, so the original symptom's cause remains
  unconfirmed. No input code, executable or YAML was changed for diagnosis;
  README and demo instructions document the English-layout requirement.
  Evidence: scratch/keyboard-layout-check.md and keyboard-layout-check-final.log.
  Non-English input remains unresolved. Do not describe it as fixed.
- Ready demo: cd build/platforms, then ./ao-doom platform-riding.wad E1M1.
  Use an English layout for letter bindings. WASD moves, E uses doors/switches;
  this platform starts/stops/resumes through line crossings.
- Resume from AGENTS.md, this checkpoint, ROADMAP.md, README.md and the two
  reports above, then verify both live worktrees and SDK paths. Source/artifact
  hashes are in scratch/platforms-verification.json; it precedes this exit-only
  SESSION update. Final exit hashes are in platforms-exit-state.json; staging
  and SDK paths are in platforms-state.json. /tmp/ao-doom-platforms-cmxzp990 is temporary.
  Full campaigns, classic random/timing fidelity, sound, CI, other platforms,
  physical hardware and maximum-scene stress remain unverified.

## Current continuation: perpetual platforms (2026-10-23)

The user requested continuing Doom implementation. This continuation supersedes
the historical checkpoints below. Game main remains at
ad9b2d1ad935b8560d7fe62a418abf4fc28fb811; engine main remains clean at
d90c17d0e74eeb615ff2ba1cd0f6d2c4a832a12c. The platform stage is local and
uncommitted. No commit or push was requested or performed; earlier publication
approvals remain consumed.

- Added crossing actions 53/87 for perpetual platforms and 54/89 for stopping
  platforms, including normal/fast lifts. Resume retains direction, target,
  remaining wait, original lift behavior and sector ownership. Repeated
  activation preserves state; upward obstruction reverses; grouped and unrelated
  tags, equal bounds, carried player and failed map replacement are covered.
- Complete YAML now requires platforms.perpetual_speed_per_tick, standard 1
  and alternate test profile 2. Existing platform wait supplies both endpoint
  delays. Initial direction uses the controller-local MiniA2 random generator;
  the shared classic random stream and exact plane timing remain open.
- Native task check passes all six engine executables and the game suite;
  five A64/QEMU suites, all 34 isolated Xephyr scenarios and five logging cases
  pass. All 132 original-map probes and ten original-platform probes pass,
  including five actual stop/resume pairs. Final equal-bounds coverage passes
  fresh Linux64 and A64 builds: 387 fixtures and ten new platform TEST procedures.
  These checks are not full campaigns. Initial failures and corrections remain
  in scratch/platforms-check.md; no required check remains failing.
- Ready demo: cd /home/andrejjj/Projects/A2/ao-doom/build/platforms, then
  ./ao-doom platform-riding.wad E1M1. Hold W to enter, release to ride,
  cross the far edge when reachable to stop, and return across the entry to
  resume. The matching complete YAML is included. A separate GUI check passes.
  All 538 pre-existing scene/build files retain their hashes. No engine or SDK
  sources changed. scene.ppm remains user-owned and untracked.
- Evidence: scratch/platforms-check.md, platforms-state.json and
  platforms-verification.json. Isolated sources/outputs:
  /tmp/ao-doom-platforms-cmxzp990. Native SDK:
  /home/andrejjj/Projects/A2/minia2/target/bundle/ob. A64 uses the existing
  logging-build/sdk/ob, build -t a64, qemu-aarch64 and target/A64/sysroot.
  Check families use separate output and TMPDIR paths; older builds are intact.
- Next: remaining floor/ceiling actions, surface changes, stairs/donuts,
  crushers, teleporters, sector damage/secrets and sound, following ROADMAP.md.
  Monster activation, classic randomness/demo fidelity and exact mover ordering
  remain open. Existing door obstruction remains player-only. Full campaigns,
  CI, Windows, ARMhf, full A2, hardware and maximum-scene stress are unverified.

## Delivery checkpoint: switch and button materials

The user requested committing and pushing the validated switch/button stage in
both main branches. This checkpoint accompanies feat(map): animate switches and
buttons and requires ao-game-engine commit d90c17d0e74eeb615ff2ba1cd0f6d2c4a832a12c,
feat(geometry): add wall material snapshots. Exact commits, committed source
hashes and remote verification are recorded in scratch/switches-delivery.json.
The continuation below is the historical pre-delivery state. Publication
approval covers this delivery only; earlier approvals remain consumed.

## Previous continuation: switch and button materials (2026-10-15)

The user requested continued Doom work according to the plan. This continuation
supersedes the prior exit checkpoint while preserving its text below. Game main
remains at 82a5c8fd8561672155d45fcecfeb4f9339ad9969; engine main remains at
db5e8742f1a724d1cd95ea2381da76843239d4c9. This switch/button stage is local and
uncommitted in both repositories. No commit or push was requested or performed;
previous publication approvals remain consumed.

- Added presentation for all 34 implemented use/gun switch bindings, including
  exits: front upper/middle/lower image changes, permanent one-shot states,
  timed button restoration without extending the first deadline, shared
  sidedefs, busy-gun activation and failed-level replacement preservation.
- Mandatory YAML switches supplies button_ticks and ordered off/on pairs.
  Standard values are 35 ticks and 40 classic pairs. Custom profiles must add
  the complete section; arbitrary names and alternate timing are verified.
- Generic engine WithWallTexture snapshots preserve old materials, partition
  data, moving planes and image alignment across different dimensions. Only
  GameGeometry.Mod, SectorSmoke.Mod and README.md changed in the engine;
  tested sources were promoted after clean-tree/base/hash guards.
- Native task check and final focused checks pass six engine executables,
  369 final fixtures and 85 game TEST procedures. Ten A64/QEMU suites plus
  final focused reruns, 33 isolated Xephyr scenarios, five logging cases,
  132 short original-map checks and 14 isolated original-switch probes pass.
  An exact-source build against the live engine and a separate ready-demo
  GUI check pass. Initial test/harness failures and corrections remain in
  scratch/switches-check.md; no final required check remains failing.
- Ready demo: cd /home/andrejjj/Projects/A2/ao-doom/build/switches, then
  ./ao-doom switch-button.wad E1M1; press E to change and release the button.
  switch-103.wad is a permanent use switch; shoot switch-24.wad to activate it.
  The matching complete YAML is included. Prior scene/build artifacts retain
  their hashes; scene.ppm and the previous SESSION text are preserved.
- Evidence: scratch/switches-check.md, switches-verification.json,
  switches-state.json and switches-engine-promotion.json. Isolated outputs:
  /tmp/ao-doom-switches-2m233w8h. The historical /tmp resume SDK no longer
  exists; the verified native SDK is now
  /home/andrejjj/Projects/A2/minia2/target/bundle/ob. Prepend its directory to
  PATH and use a fresh unique TMPDIR. A64 uses the existing logging-build/sdk
  with build -t a64 and qemu-aarch64 plus target/A64/sysroot. No SDK edits.
- Next: remaining map progression in ROADMAP.md: other floor/ceiling actions,
  surface changes, stairs/donuts, perpetual platforms/stops, crushers,
  teleporters, damage/secrets and sound. Switch sounds and original
  intermissions remain open. Full campaigns, demo fidelity, CI, Windows,
  ARMhf, full A2, physical hardware and maximum-scene performance are
  unverified. Door obstruction remains player-only.

## Exit checkpoint: 2026-10-15

The user requested saving state and leaving the session. Stop implementation;
resume only after a new request. This checkpoint supersedes all historical
continuations below. Both authorized floor/lift pushes completed and their
single-use approvals are consumed. No publication approval remains pending.

- ao-doom main: 82a5c8fd8561672155d45fcecfeb4f9339ad9969,
  feat(map): add floor and lift actions.
- ao-game-engine main: db5e8742f1a724d1cd95ea2381da76843239d4c9,
  feat(geometry): add moving floor snapshots.
- Both HEADs match cached origin/main. Both live remote heads were verified
  after publication at 2026-10-14T20:59:32.427088+00:00; evidence is in
  scratch/floors-delivery.json. No fetch, push or new commit was performed for
  this exit checkpoint. Game product sources/tests/YAML and engine changes
  are committed and published. Engine is clean. This SESSION.md update is the
  only tracked game edit; user-owned scene.ppm remains untracked and preserved.
- Delivered: 17 floor actions and eight normal/fast lifts, shared consumed
  actions and sector ownership across doors/floors/exits, immutable moving
  floor snapshots composed with ceilings, texture/ray/collision updates,
  carried player/grounded things, valid-volume obstruction and lift reversal.
  Complete YAML requires floors.speed_per_tick and platforms.speed_per_tick,
  fast_speed_per_tick and wait_ticks. Standard values are 1, 4, 8 and 105.
- Prior validation passed native task check, six engine executables, 323
  authored WAD fixtures, 78 game TEST procedures, ten A64/QEMU suites, 30
  isolated Xephyr scenarios, five logging cases, 132 short original-map checks,
  ten isolated original floor/lift probes and a separate ready-demo GUI check.
  Red baseline Trap 5.8 and the corrected early GUI sampling failure remain
  documented in scratch/floors-check.md. Tests were not rerun for publication
  metadata or this exit checkpoint; source/artifact hashes were rechecked.
- Ready demo: cd /home/andrejjj/Projects/A2/ao-doom/build/floors, then
  ./ao-doom floor-lift-ride.wad E1M1; press E to ride down/wait/return.
  Matching YAML and floor-88.wad/floor-gun.wad are included. Existing
  build/ao-doom, build/doom.yaml, scene.ppm and build/demo captures retain their
  recorded hashes. Preserve these files and keep them out of source commits.
- Evidence: scratch/floors-check.md, floors-delivery.json,
  floors-verification.json and floors-state.json. The verification manifest
  is the historical pre-delivery snapshot; delivery.json records publication.
  Isolated sources/outputs remain at /tmp/ao-doom-floors-pr0w4cow.
  Native SDK: /tmp/ao-doom-resume-1khrtq_c/minia2/target/bundle/ob; prepend its
  directory to PATH and use a fresh unique TMPDIR when resuming. The installed
  older SDK lacks Logging.
  A64 SDK: /home/andrejjj/Projects/A2/minia2/target/logging-build/sdk/ob.
  Use build -t a64 and qemu-aarch64 with sysroot
  /home/andrejjj/Projects/A2/minia2/target/A64/sysroot. These paths currently
  exist; /tmp paths are temporary, so recheck.
- Resume by reading AGENTS.md, this checkpoint, ROADMAP.md, README.md and
  scratch/floors-check.md, then verify both real branches/worktrees and SDKs.
  Previous unanswered push requests below are historical and resolved by the
  later explicit publication instruction. Further pushes need new approval.
- Next: remaining map progression in ROADMAP.md, including other plane
  actions, surface changes, stairs/donuts, perpetual platforms/stops, crushers,
  switch/button visuals, teleporters, damage/secrets and sound. These remain
  incomplete. Door obstruction is player-only; already invalid spawn volumes
  retain preview behavior. Full campaigns, classic fidelity, CI, Windows,
  ARMhf, full A2, hardware and maximum-scene performance are unverified.

## Delivery checkpoint: floor and lift actions

The user explicitly requested committing and pushing the validated floor/lift
stage in both main branches. The engine stage is committed and its remote main
verified at db5e8742f1a724d1cd95ea2381da76843239d4c9,
feat(geometry): add moving floor snapshots. This game checkpoint accompanies
feat(map): add floor and lift actions and requires that exact engine revision.
Exact commits, committed file hashes and game/engine remote verification are
recorded in scratch/floors-delivery.json. Approval covers this delivery only;
the earlier pending approval and uncommitted states below are historical.

- Delivered 17 floor actions and eight lifts, shared consumed actions and
  sector ownership, carried occupants and valid-volume obstruction checks.
- Product sources retain their validated hashes. Native task check, ten
  A64/QEMU suites, 30 isolated GUI scenarios, five logging cases, 132 short
  original-map checks and ten original floor/lift probes passed before delivery.
  Runtime tests were not repeated for commit metadata and documentation changes.
- Evidence and limits: scratch/floors-check.md and floors-verification.json.
  Ready demo: cd build/floors, then ./ao-doom floor-lift-ride.wad E1M1 and E.
  Existing builds, captures and user-owned scene.ppm remain preserved.
- Next: remaining map progression in ROADMAP.md. Full campaigns, classic
  fidelity, CI, other platforms and hardware remain unverified.

## Previous continuation: floor and lift actions (2026-10-14)

The user requested committing/pushing the tagged-door stage and continuing
ROADMAP implementation, then asked how to launch the game. Game main and the
verified remote main are now 29a76b7573238aa7a928e22b90b1d5ed7d126f47. The
tagged-door push approval is consumed. Engine HEAD remains
63c04e5dccfd68b76e3b92585a062430a1f58341; a separate approval request to push
the two existing engine commits up to that fixed SHA is unanswered. Do not
infer approval from the launch question. The new floor/lift stage is local and
uncommitted in both repositories; no further commit or push was performed.
This continuation supersedes the checkpoints below while retaining their history.

- Added 17 floor actions and eight normal/fast down/wait/return lifts. Shared
  DoomActions coordinates consumed lines and sector ownership across doors,
  floors and exits. Use, accepted crossings and clipped player hitscan activate
  matching tags. Mandatory YAML now requires floors/platforms speeds and wait.
- Generic engine WithFloors snapshots compose with ceilings and update ray,
  collision, renderer and texture heights. TouchesSector narrows occupant
  checks. Player and grounded things ride accepted floors; valid solid volumes
  block pinching and obstructed rising lifts reverse. Engine changes are exactly
  GameGeometry.Mod, SectorSmoke.Mod and README.md, promoted from tested staging.
- Native task check passes six engine executables, 323 authored WAD fixtures
  and 78 game TEST procedures. Ten A64/QEMU suites, 30 isolated Xephyr scenarios,
  five logging cases, 132 short original-map probes and ten isolated original
  floor/lift probes pass. G1 busy-target consumption was corrected and verified
  by final native/A64 reruns. The initial GUI crossing wait was too short;
  corrected timing passes the full repeat. Failures remain in the evidence.
- Final exact-source build against the live sibling engine passed. Ready demo:
  cd /home/andrejjj/Projects/A2/ao-doom/build/floors, then
  ./ao-doom floor-lift-ride.wad E1M1; press E to ride down/wait/return.
  The ready artifact has matching YAML and three synthetic maps, and its own
  isolated GUI check passes. Existing build/ao-doom, build/doom.yaml, scene.ppm
  and build/demo remain preserved; the launch advice given earlier still works.
- Evidence: scratch/floors-check.md, floors-verification.json and source/artifact
  manifests. Setup: scratch/floors-state.json and /tmp/ao-doom-floors-pr0w4cow.
  Native SDK: /tmp/ao-doom-resume-1khrtq_c/minia2/target/bundle on PATH;
  installed older ob lacks Logging. A64 uses the existing logging-build SDK.
  No SDK, MiniA2, original IWAD or SSH configuration edits were made.
- Limits: remaining plane actions, surface changes, stairs/donuts, perpetual
  platforms/stops, crushers, switch/button visuals, sound and monster activation
  remain open. Door obstruction is player-only; already invalid spawn volumes
  keep preview behavior. No full campaigns, classic fidelity, CI, Windows,
  ARMhf, full A2, hardware or maximum-scene performance validation. Next:
  remaining map progression according to ROADMAP.md.

## Delivery checkpoint: tagged doors

The user requested committing and pushing the validated tagged-door stage, then
continuing ROADMAP implementation. This checkpoint accompanies
feat(map): add tagged door activation. It requires ao-game-engine commit
63c04e5dccfd68b76e3b92585a062430a1f58341. Exact commit and remote verification
are recorded in scratch/tagged-doors-delivery.json. The continuation below is
the historical pre-delivery state; publication approval covers this delivery.

## Current continuation: tagged doors (2026-10-14)

Resumed implementation at the user's request according to ROADMAP.md. This
continuation supersedes the previous exit checkpoint while retaining its history.
Game main remains at c5f9ff19375c6ff2829445351598f5e00ce5049a; engine main remains
at 63c04e5dccfd68b76e3b92585a062430a1f58341 and is clean. Game changes are local
and uncommitted. No commit or push was requested or performed.

- Added 33 tagged door actions: 18 use, 14 walk and repeatable hitscan type 46;
  normal/fast opening/closing, raise/wait/close, close/wait/reopen, grouped tags,
  card/skull locks, busy target handling and one-shot/repeat behavior.
- Player movement observations feed doors/exits; clipped actual player hitscan
  feeds gun actions. Existing ceiling snapshots require no engine changes.
  Hidden moving-wall textures validate before replacement. Complete custom
  profiles now require doors.close_wait_ticks; standard delay is 1050 ticks.
- Native task check, six A64/QEMU suites, 27 isolated Xephyr scenarios, five
  logging cases, 132 short original-map probes, six original tagged-switch
  probes and three original manual/locked-door probes passed. An expanded
  distant-door crossing assertion passed final native and A64 reruns.
- Evidence: scratch/tagged-doors-check.md and tagged-doors-verification.json.
  Setup: scratch/tagged-doors-state.json, /tmp/ao-doom-tagged-v71f_o7s.
  Use the existing Logging-capable SDK directory from that state file on PATH;
  the installed older SDK remains unsuitable. No SDK/MiniA2 sources changed.
- scene.ppm, the previous user-owned SESSION edit and existing build/demo
  captures remain preserved. Default sibling-engine task build passed.
  Demo: ./build/ao-doom build/tagged-door-gui.wad E1M1, press E, then walk.
- Limits: switch visuals/button timers, sound, monster activation and actor
  obstruction remain open. No full campaigns, original fidelity, CI, Windows,
  ARMhf, full A2, hardware or maximum-scene performance validation. Next:
  floor/lift actions and remaining switch presentation, following ROADMAP.md.

## Exit checkpoint: 2026-10-14

The user requested saving state and leaving the session. Stop implementation;
resume only after a new request. This checkpoint supersedes historical states
below. Pushes remain explicitly deferred, with no pending publication approval.

- ao-doom main: c5f9ff19375c6ff2829445351598f5e00ce5049a,
  feat(game): add level exits and campaign transitions.
- ao-game-engine main: 63c04e5dccfd68b76e3b92585a062430a1f58341,
  feat(geometry): observe accepted movement and line crossings.
- Both branches are two commits ahead of cached origin/main. No fetch or push
  was performed for this exit checkpoint. Engine is clean. Game product code,
  tests and YAML are committed; this SESSION.md update is intentionally the
  only tracked local edit, and user-owned scene.ppm remains untracked.
- Completed: shared animation/ray geometry and accepted movement observations;
  normal/secret exits 11/51/52/124; 68 authored classic campaign routes; carried
  health/armor/weapons/ammo/backpack/magazines; key reset; validated replacement
  with failure preservation; terminal freeze and rare typed transition logs.
  Direct Load movement semantics are preserved. Custom YAML requires campaign.
- Verification: native task check, six engine executables, 242 owned WAD
  fixtures, 63 game TEST procedures, ten A64/QEMU suites, 24 isolated Xephyr
  scenarios, five logging cases, 132 short original-map probes and default
  sibling-engine task build passed. Initial failures and fixes remain documented
  in scratch/exits-check.md. Tests were not rerun for this bookkeeping update.
- Native SDK with Logging: /tmp/ao-doom-resume-1khrtq_c/minia2/target/bundle/ob.
  Prepend its directory to PATH; the installed older ob lacks Logging.
  Unique work/output setup: scratch/exits-state.json and
  /tmp/ao-doom-exits-ma8srrj_. A64 SDK is read-only at
  /home/andrejjj/Projects/A2/minia2/target/logging-build/sdk/ob; use build -t a64.
  GUI checks require owned isolated Xephyr; preserve host focus/pointer.
- Resume by reading AGENTS.md, this checkpoint, ROADMAP.md, README.md and
  scratch/exits-check.md, then verify both real branches/worktrees and SDK paths.
  Exact commits/hashes: scratch/exits-delivery.json and exits-verification.json.
  Preserve scene.ppm and existing build/demo GIF/MP4/logs; exclude them from
  commits. Demo: ./build/ao-doom build/exits-use.wad E1M1, then press E.
- Next planned progression: tagged switches/doors and further sector actions,
  extending only common geometry mechanisms in ao-game-engine. Keep Doom
  activation semantics and authored tuning/routes in ao-doom, following ROADMAP.
- Limits: immediate transitions; original intermissions/finales/switch visuals
  and absent-MAP31 secret fallback remain open. Full campaigns, classic fidelity,
  CI, Windows, ARMhf, full A2, hardware and maximum-scene performance are not
  validated. Doom 3/BFG Edition/Quake are deferred; classic BFG stays in scope.

## Delivery checkpoint: level exits and campaign transitions

The user requested local commits and explicitly deferred pushes. This checkpoint
accompanies feat(game): add level exits and campaign transitions. It requires
ao-game-engine commit 63c04e5dccfd68b76e3b92585a062430a1f58341,
feat(geometry): observe accepted movement and line crossings. Exact game/engine
commits and verification are recorded in scratch/exits-check.md and
scratch/exits-delivery.json. No push is authorized or performed. The continuation
below is the historical pre-delivery state.

## Previous continuation: level exits and campaign transitions

The user explicitly deferred pushes and requested continued work on ROADMAP.md.
Local game main is b19fd8f3bca45ccc7afedb0ed1702afa2d009aaa; local engine main
is 96545948c43940116fbf5849ae0af94aaf53a42f. Both have one unpublished commit
from the previous delivery. This progression work remains uncommitted, and no
push is authorized. Previous checkpoint descriptions below are historical.

- DoomExits supports normal/secret use lines 11/51 and crossing lines 52/124.
  GameGeometry.MovePlayerObserved reports accepted nonzero axis substeps;
  Crossing detects finite segment side changes. The game queues the first exit
  and resolves it after movement, without replacing geometry inside callbacks.
- Mandatory campaign YAML supplies 68 classic Doom/Doom II routes, explicit
  null terminal targets and authored completion/failure label layout. Route
  names/targets/duplicates/counts and label bounds validate before replacement.
- Next-map geometry, spawn and images validate before publication, including
  projectile resources for weapons carried from a previous map with no pickup.
  Health, armor, weapons, ammunition, backpack capacities and loaded magazines
  persist. Keys, pickup counters and hints clear; controls/reload/flash reset.
  Failed transitions preserve the active level and inventory and allow retry.
  The existing direct Load API retains its movement-control behavior.
- Terminal routes freeze gameplay and display a completion label. DoomWindow
  consumes rare transition events and writes typed INFO/ERROR records through
  Doom.log outside Step/Render. Original intermissions/finales/switch texture
  changes and the secret-exit fallback when MAP31 is absent remain open.
- Native task check passed six engine executables, 242 WAD fixtures and 63
  game TEST procedures. Ten A64/QEMU suites, 24 isolated Xephyr scenarios, five
  logging cases and 132 original-map start/walk/turn/fire probes passed. Four
  tested engine files were promoted with clean-tree/base/hash guards; ordinary
  sibling-engine task build passed. scene.ppm and build/demo are preserved.
- Verification paths and setup are in scratch/exits-state.json. Final evidence,
  test results, hashes and remaining limits are saved in scratch/exits-check.md
  and scratch/exits-verification.json. Preserve scene.ppm and build/demo media.
- Next: tagged switches/doors and other map actions, then remaining classic
  actor/combat/game-flow behavior. Full campaigns and original compatibility
  are not established by synthetic exits or short original-map probes.

## Delivery checkpoint: common Doom engine mechanisms

The user requested coordinated updates of the engine and game. This checkpoint
accompanies feat(engine): use shared animation and world ray tracing. It requires
ao-game-engine commit 96545948c43940116fbf5849ae0af94aaf53a42f,
feat(engine): add shared animation and sloped ray tracing. Exact local commits,
publication status and remote verification are recorded in scratch/engine-check.md.
The uncommitted status below is the historical pre-delivery state. Publication
requires explicit approval for each repository/branch/push under the personal
AGENTS.md gate; prior approvals remain consumed.

## Previous continuation: common Doom engine mechanisms

The user asked to expand ao-game-engine with mechanisms used by Doom and
confirmed the current target as complete classic Doom and Doom II in Active
Oberon. Doom 3 and Doom 3: BFG Edition are deferred; the classic BFG weapon is
still in scope. ROADMAP.md records ownership, remaining areas and completion
evidence without claiming current full compatibility.

- Game main remains at published 374b86b; engine main remains at 045c00e.
  Both working trees now contain uncommitted changes. Previous push approvals
  are consumed; this request authorized implementation, not publication.
- Engine GameAnimation stores immutable tick clips, copied positive durations,
  looping/last-frame hold and constant-rate playback. Doom walking, attacks and
  impact/barrel effects now use it. Engine code has no Doom/YAML imports, frame
  names, actor IDs or default balance. Game rules still own images, selection,
  start time, expiry and damage. Current YAML authoring is unchanged.
- Engine World.TraceRay supplies shared sloped center-ray clipping for sight,
  player/enemy bullets and blast cover. The original probe crossed a floor and
  returned 4 instead of 0.5, failing with Trap 5.8. The common implementation
  clips floors/ceilings inside every sector as well as portal openings; that
  exact probe now returns 0.5 and passes. Original DoomActors.Trace API remains
  as a delegate for callers. Volume sweeps and original sight-cone fidelity
  remain separate work.
- Native task check passed five engine executables, 230 owned WAD fixtures and
  57 game TEST procedures plus three new engine TEST procedures. Eight fresh
  A64/QEMU suites passed: animation, sector geometry and six game suites. All
  20 isolated Xephyr scenarios, five logging cases and 132 original-map probes
  passed. Five captured fixture frame hashes match the pre-extraction output.
- Six validated engine files were applied to the real sibling repository only
  after checks, with clean-tree/base-commit guards. Game builds and SDK work
  used isolated outputs; no MiniA2/installed SDK edits. The ordinary task build
  against ../ao-game-engine also passed. Evidence: scratch/engine-check.md,
  engine-verification.json and corresponding logs. scene.ppm and build/demo
  captures remain preserved.
- Full campaigns, compatibility, CI, Windows, ARMhf, full A2, physical hardware
  and maximum-scene performance remain unchecked. Next milestones are classic
  map progression and remaining combat/actor/game-flow behavior in ROADMAP.md.

## Delivery checkpoint: impact animations and barrel chains

The user explicitly requested committing and pushing the validated impact and
barrel-explosion milestone. This checkpoint accompanies
feat(combat): animate impacts and chain barrel explosions. Exact commit and live
remote verification are recorded in scratch/explosions-check.md. The uncommitted
status below is the historical pre-delivery state. This push approval is single-use;
subsequent publication requires a new explicit request.

## Previous continuation: impact animations and barrel chains

Started on main after publishing 049524d91a76269adbbf8c8bb11f22daaf78b600,
feat(combat): add configurable rocket blast damage. The user explicitly asked
for that commit/push, then continued implementation. Remote main was verified
at the same commit after the normal push through SSH port 443. That single-use
push approval is consumed; this continuation remains uncommitted.

- The original barrel probe left its neighbor at health 20 after 45 ticks;
  the chain assertion failed with Trap 5.8. Current barrels animate and detonate
  once after the YAML delay; new deaths receive their own timers after the pass,
  preserving chain timing even when THINGS order is reversed.
- All projectile rules require impact: thing/frames/ticks. Every actor rule
  requires explosion: explicit null or a complete positive-blast mapping. First
  frames, height and fullbright come only from things. Standard barrel delay is
  15 ticks, damage/radius 128/128, animation 5/5/5/10/10. Profiles now define 125
  things, including owned effect IDs 60004-60008; all three full profiles agree.
- Effects use a separate 256-entry list with immutable frame/timer snapshots.
  Its visual cap cannot cancel damage: the 300-barrel regression passes. Frame
  resources are validated/cached before replacement; failed loads preserve
  current effects and health. Death freezes pending effects/blasts.
- Native task check passed engine regressions, 230 owned WAD fixtures and 57
  file-based TEST procedures. Six A64/QEMU suites and all 132 original-map
  start/walk/render/fire probes passed. The first GUI run exposed an obsolete
  immediate-static-frame assertion for imp impacts; its wait now lets surviving
  flight/impact finish. The full repeat passed all 20 isolated Xephyr scenarios
  and five structured-logging cases.
- Evidence: scratch/explosions-check.md, explosions-verification.json and logs.
  The clean MiniA2 890ac86 native SDK, read-only A64 SDK and isolated engine copy
  remain unchanged. scene.ppm and build/demo GIF/MP4/logs are preserved.
- Remaining: route finding, more monster attacks/map actions, monster death
  animation/drops, boss blast immunity and BFG secondary effect. CI, Windows,
  ARMhf, physical hardware, full A2, maximum-scene stress and full playthroughs
  remain unchecked. Custom YAML files must adopt the new mandatory fields.

## Delivery checkpoint: configurable rocket blast damage

Published 049524d91a76269adbbf8c8bb11f22daaf78b600 to origin/main after explicit
user approval; the live remote matched. Exact evidence: scratch/blast-check.md.
The continuation below retains its historical pre-delivery state. A new push
approval is required for subsequent work.

## Previous continuation: configurable rocket blast damage

Started on main at 7443a89, already published together with 3913c9e after the
user's explicit approval. That push used SSH port 443 after port 22 timed out;
its approval is consumed. The user then requested a GIF and continued game
implementation. The owned MAP01 GIF/MP4 and actual logs remain in build/demo.
The existing untracked scene.ppm is preserved.

- Original rocket probe killed the direct target but left its neighbor at
  health 20; the new nearby-damage assertion failed with Trap 5.8. Rockets now
  apply one distance-attenuated blast at their clipped first impact, including
  decoration, wall and plane impacts. Range exhaustion has no blast.
- All projectile profiles require blast_damage/blast_radius, both zero or both
  positive. Standard rockets use 128 damage over 128 Doom units; imp/plasma/BFG
  blasts are explicitly disabled. Complete default/custom/invalid profiles are
  updated atomically. Entity appearance/dimensions still come only from things.
- Damage uses quantized maximum horizontal axis distance minus target radius,
  plus two center sight traces. Cover/closed portals protect; open grilles pass
  the blast. Player self-damage uses normal armor. Actor hitpoints stay copied;
  victims killed by an earlier impact cannot act later in the same tick.
- Native task check passed 222 owned WAD fixtures, 51 file-based TEST procedures
  and engine checks. The final projectile suite also passed the added expiry
  case. Five A64/QEMU suites passed; the projectile suite was rebuilt/rerun with
  its final test. All 19 isolated Xephyr scenarios, five logging cases and all
  132 original-map start/walk/render probes passed. Exact evidence/source hashes:
  scratch/blast-check.md and scratch/blast-verification.json.
- Used the existing clean 890ac86 native SDK, read-only Logging-capable A64 SDK
  and an isolated engine copy. No engine/MiniA2/installed SDK edits or original
  asset copies. Changes remain uncommitted; no push was requested or performed.
- Deliberate limits: no explosion/impact animation, barrel chain explosions,
  boss blast immunity, original sight-cone equivalence or BFG secondary effect.
  CI, Windows, ARMhf, physical hardware, full A2, maximum-scene stress and full
  playthroughs remain unchecked. Next: visible explosions/barrel chains, route
  finding and additional map actions.

## Resumed delivery: modern controls and structured game logs

The previous session stopped before committing or pushing the delivery below.
Recovered the direct user request from its transcript and verified that local
main remained at 3913c9e while remote main remained at 2078712. The pending
commit/push authorization applies to this delivery only.

- Rebuilt clean MiniA2 890ac86 and its Linux64 SDK under
  /tmp/ao-doom-resume-1khrtq_c/minia2 after the previous temporary SDK disappeared.
  A64 module-list regeneration had no differences. The installed SDK, user-owned
  MiniA2 work and engine checkout were left unchanged; engine checks use a copy.
- Fresh task check passed engine regressions, 221 owned WAD fixtures and
  47 file-based TEST procedures. Fresh isolated Xephyr task gui-check passed
  all 18 game scenarios and the five logging cases. All 132 original-map
  start/walk/render probes passed again. No product-source correction was needed.
- Earlier five-suite A64/QEMU results are retained, not rerun in this recovery.
  CI, Windows, ARMhf, hardware, full A2, maximum-scene stress and complete
  playthroughs remain unchecked. Future builds require an SDK containing Logging.
- The existing untracked scene.ppm is preserved outside the delivery. Exact
  source hashes, logs, resulting commit and remote verification are recorded in
  scratch/resume-check.md. Later publication requires a new push approval.

## Delivery checkpoint: modern controls and structured game logs

The user deferred the full A2 port, asked to save its assessment, requested a
commit and push of ao-doom/main, and asked to use the new MiniA2 Logging module.
This checkpoint accompanies `feat(input): add modern controls and structured game logs`.
The pending controls below and structured logging are included. Publication also
includes the earlier local imp commit `3913c9e`; origin/main was verified at
`2078712` before delivery. This push approval is single-use.

- `Doom.log` owns one JSON handler and a dedicated KernelLog stream with the
  component context. Window startup/config/map events use INFO with typed fields;
  failures use ERROR, and shutdown records final ticks/result. The headless game
  check also uses Logging. No logging was added to rendering or simulation ticks.
  Kernel/driver and test diagnostics retain their existing output.
- The installed SDK lacked Logging. Built a clean archived MiniA2 snapshot at
  `890ac86` under `/tmp/ao-doom-logging.szafo7bb/minia2`. The A64 list regenerated
  without differences; Linux64/bundle, 60 A64 runtime modules and 380 A64 stdlib
  modules built. The A64 system answered shell commands under QEMU. Existing
  MiniA2 source/build/installed SDK trees were not modified by this task.
- `README.md` saves the full-A2 assessment: moderate adapter/library work;
  Unix/X11 launcher/capture need replacement, and full A2 lacks YAML/Logging.
  Start with a 320x200 window after compiler/API checks. No full A2 compile/run
  or hardware performance evidence exists; the user explicitly deferred it.
- Native `task check` passed 221 owned fixtures and 47 file-based {TEST}
  procedures. Five game suites passed on the fresh A64 SDK under QEMU, and all
  132 original-map start/walk/render probes passed on current game sources.
- Main-desktop attempts hit an Escape timeout and a remapped-frame mismatch;
  the frame difference had no established cause. An isolated Xephyr server
  exposed the shutdown race: restoring previous focus before synthetic Escape
  could make the controller ignore that key. The shared test shutdown now focuses
  its owned game window first. The new logging probe initially used the wrong
  fixture cwd; corrected it and made `gui-check` build that probe. Final full
  validation and exact source hashes are recorded in scratch/logging-check.md.
- Runtime logs require an SDK containing std/logging. The Logging source remains
  owned by MiniA2; it is not vendored. Durable logging rules are in local AGENTS
  and tracked README. Full-A2 execution, CI, Windows, ARMhf, hardware calibration,
  maximum-map stress and complete playthroughs remain unchecked.

## Current continuation: modern FPS controls

The user requested a commit first, then WASD/mouse/fire/aim/reload/weapon/use
controls with automatic pickups. Committed the validated imp milestone on main
as `3913c9e` (`feat(combat): add configurable imp fireballs`) before these edits.
The uncommitted/no-push status here describes the pre-delivery state; the newer
delivery checkpoint above records the subsequent user authorization.

- WASD moves/strafes; mouse movement changes yaw and pitch independently of tick
  frequency. LMB fires, held RMB zooms and reduces sensitivity, R reloads,
  1-7 select classic slots and the wheel cycles owned weapons. Repeating 1 or 3
  toggles fist/chainsaw or shotgun/super shotgun. E replaces Space for manual
  door use. Existing arrow/Ctrl aliases remain. Contact pickups stay automatic.
- `DoomMouse` is a Linux X11 input adapter over the installed SDK/Xlib. It confines
  and recenters the hidden pointer only in the focused game window, releases it
  on focus loss/exit and keeps allocation-capable controller calls outside the
  Machine.X11 lock. Focus clears buttons, keys, motion and pending edge actions.
- `DoomCombat` now owns selected weapons, persistent magazines, timed/partial
  reloads and shared reserves. Inventory ammo includes loaded rounds; selecting
  a weapon cannot create ammo. First selection fills its magazine from reserve;
  subsequent switches preserve it and cancel pending reloads. Empty magazines
  require R. The active weapon and loaded/reserve or reload state are visible.
- All nine owned weapons can attack: fist/chainsaw melee, pistol/chaingun rays,
  deterministic shotgun pellet fans, and rocket/plasma/BFG projectile flight.
  Player rays and projectiles follow the pitch slope. Projectile definitions
  reuse `things` through local IDs 60001-60003; appearance has no compiled table.
- New mandatory YAML weapon/mouse/reload/slot fields are validated atomically;
  complete default/custom/invalid profiles are updated. The custom profile also
  checks inversion, sensitivity and swapped fire/aim buttons. Engine/SDK sources
  and external archives were not changed; no original assets are redistributed.
- Final `task check` passed 221 owned WAD fixtures and 47 file-based {TEST}
  procedures. Final `task gui-check` passed 18 owned-window scenarios, including
  E doors, automatic pickups and all modern controls. Five final-source A64
  suites passed under QEMU (config, controls, combat, input, projectiles).
  All 132 original-map start/walk probes passed; these are short probes, not
  complete playthroughs. Exact logs/limits: scratch/controls-check.md.
- The first mouse GUI run exposed a Machine lock hierarchy assertion; fixed by
  releasing X11 before controller calls. The first release test used root focus,
  which the local window manager immediately returned to the game; the final
  test transfers real focus to a second owned window and verifies confinement
  release and stopped firing. Visibility checks now exclude weapon status text.
- Deliberate limits: pitch shears the existing 2.5D renderer, not a 3D camera;
  RMB supplies zoom without a weapon-view animation. Damage remains fixed;
  projectiles have no splash/impact animation or original BFG secondary effect.
  Captured mouse input is Linux/X11 only; A64 evidence covers headless logic.
  CI, Windows, ARMhf, physical mouse/hardware calibration, maximum-scene stress
  and complete playthroughs remain unchecked. Future publication needs approval.

## Delivery checkpoint: configurable imp fireballs

The user requested a commit of the existing validated changes before modernizing
the controls. This checkpoint accompanies `feat(combat): add configurable imp fireballs`.
The commit includes the projectile continuation below; its earlier uncommitted
status is historical. No push was requested or authorized for this delivery.
The next task is WASD, mouse look/fire/aim, reload, weapon selection and E use;
automatic pickups must remain enabled.

## Current continuation: configurable imp fireballs

The user asked to continue implementation. Started clean on main at `2078712`.
Imps now launch visible projectiles with fixed trajectories, finite flight range,
swept impacts, armor absorption and interception. Changes remain uncommitted;
no new commit or push was requested, authorized or performed.

- `behavior: projectile` reuses shared sight/chase/windup/frame settings and adds
  `thing` plus `shot_speed_per_tick`. `things` supplies all projectile appearance
  and dimensions; the standard profile adds local ID 60000 for the fireball.
- `DoomProjectiles` provides flight direction and geometry/volume clipping.
  `DoomSprites` publishes copied projectile state, renders it and resolves first
  impacts. Fired shots survive owner death; player death freezes them. Failed
  map replacement preserves flight, while successful replacement clears it.
- Original 80-tick imp probe kept health 100 and failed its attack assertion.
  Final task check passed 218 synthetic fixtures and 40 file-based {TEST}
  procedures; five fresh A64 suites passed under QEMU. All 17 X11 scenarios and
  all 132 original-map probes passed on final sources. Evidence and exact limits:
  scratch/projectiles-check.md. No engine/SDK/registry source changes.
- Projectiles have direct fixed damage and use a single configured flight frame.
  No impact animation, splash, same-species immunity or monster retaliation.
  Wall faces expand along the center ray; complete corner footprint sweeps are
  still approximate. Zero-height legacy decorations have no projectile volume.
  Active shots are capped at 256; excess launches are dropped.
- CI, Windows, ARMhf, physical hardware, maximum-map stress and full playthroughs
  remain unchecked. Next: route finding, other weapons, projectile refinement,
  further monster types and map actions. Prior push approval is consumed.

## Delivery checkpoint: YAML entity definitions

The user approved the constants/YAML boundary, asked to implement it and save
the result in memory, then explicitly requested a commit and push to ao-doom/main.
Implementation started clean on main at `57ef125`. The pre-delivery local and
remote main both point there, so publication can use a normal fast-forward.
This checkpoint accompanies `refactor(config): load entity definitions from YAML`.
The task reply records the resulting commit and verified remote state.
Push approval is single-use; later publication requires a new user request.

- `things` now owns all 116 existing entity definitions: spawn frame,
  fullbright/ceiling flags, height and radius. `combat.actors` references kind
  and keeps health/death/behavior rules; duplicate height/radius keys are removed.
- `DoomThings` keeps IDs, typed data and table lookup. No compiled fallback or
  new module/dependency. All callers and complete YAML test profiles are updated.
- Format, internal states/indices, precision and validation/resource bounds stay
  constants. Simulation frequency remains YAML with 35 in the standard profile.
  Durable rules are in local AGENTS.md and the tracked README.
- Final task check passed 206 fixtures and 34 file-based {TEST} procedures.
  Configuration/sprite/actor A64 suites passed under QEMU. All 132 original-map
  probes passed; four standard sprite PPMs match the baseline byte-for-byte.
- Final GUI check passed all 16 scenarios. The first run's pickup-HUD assertion
  failed; isolated/full repeats passed without code changes. Cause unconfirmed.
  Exact evidence and limits: scratch/things-data-check.md.
- External custom profiles need the new table and relocated combat dimensions.
  No live reload. CI, Windows, ARMhf, hardware, maximum-entity stress and full
  playthroughs remain unchecked. Next engine work remains route finding,
  projectile attacks, weapon view/selection and additional map actions.

## Delivery checkpoint: configurable combat

The user explicitly requested a commit and push of the accumulated pistol,
melee AI and ranged soldier changes to ao-doom/main. The pre-delivery local and
remote main both point to `286f1e9`; publication can use a normal fast-forward.
This checkpoint accompanies `feat(combat): add configurable pistol and monster attacks`.
The task reply records the resulting commit and verified remote state.

- Include all three new product modules, four new test modules, mandatory YAML
  profiles, task staging and documentation in the feature commit.
- Final Linux64 product sources and all 26 A64 product/test/config files match
  the validated source tree; the tested window executable hash also matches.
  Existing validation passed 205 fixtures, 32 {TEST} procedures, six A64 suites
  under QEMU, 16 X11 scenarios and 132 original map probes.
- No MiniA2, registry or engine source changes are part of this delivery.
  CI, physical hardware and full playthroughs remain unchecked.
- The continuation sections below preserve historical implementation states;
  their uncommitted/no-push notes predate this explicit delivery request.
  Push approval is single-use; later publication requires a new user request.

## Current continuation: configurable ranged soldiers

The latest user request was to continue. Zombiemen and shotgun soldiers now wake
on sight, chase into configured range and fire after a windup. Soldier rays aim
at current player height, cross open grilles and stop at walls/closed openings.
Each pellet hits the closest shootable actor or player. Enemy fire can damage
barrels/other enemies; killed actors cannot attack later in the same tick.

- Started on main at `286f1e9` with pistol/melee changes already dirty. Preserved
  all prior work. This continuation is also uncommitted; no push is authorized
  or attempted. No engine, MiniA2 or registry source changes were needed.
- BehaviorSettings replaces the melee-only internal settings type; shared
  motion/attack timing serves melee and hitscan. Active rules require matching
  sections; hitscan also requires pellets/spread_radians. Full default/custom/
  invalid YAML profiles and generated soldier animation resources are updated.
- Player/enemy shots share nearest-volume clipping. Enemy pellets share a private
  health copy; motion/timers/pickups and old render snapshots remain preserved.
  Sloped visibility supports different floor heights and rejects closed spawn
  heights. Corpses stop intercepting subsequent pellets in the same attack.
- Reproduced absent ranged damage before implementation. Final task check passed
  205 synthetic fixtures and 32 {TEST} procedures. Fresh hitscan/AI/config/combat/
  input/inventory A64 builds passed under QEMU, including the final multi-pellet
  interception case. All 16 X11 scenarios and all 132 original map probes passed.
  Evidence and exact limits: scratch/hitscan-check.md.
- GUI weapon/input checks use complete static-target profiles to isolate input
  from autonomous attacks; a separate scenario verifies ranged damage and kill.
  The previous modifier-synchronization safeguard remains active.
- No new product modules or MiniA2 modules were introduced. Doom module staging
  and explicit new test staging include the final native/A64 dependencies.
- Next: route finding, projectile attacks, weapon view/selection and map actions.
  Fixed damage/symmetric spread remain simplified; no enemy retaliation, random
  AI, sound wake, pain/death sequences or attack-frame fullbright transitions.
  Doors still protect only the player. No CI, physical hardware, maximum-size
  stress, original fidelity or full playthrough claim.

## Current continuation: configurable melee AI

The latest user request was to continue. Demons and spectres now wake on sight,
chase with wall/step/player/actor collision, animate walking and wind up bites.
An impact rechecks range and sight; death disables attacks. Armor absorption and
player death are integrated. Dead-player controls, doors and AI freeze; Escape
still works. Map replacement resets state only after full resource validation.

- Began on main at `286f1e9` with the preceding pistol milestone uncommitted.
  Preserved that dirty work; this continuation is also uncommitted. No push is
  authorized or attempted. No SDK, registry or engine source edits were needed.
- Damageable actor radii/behavior, melee speed/step/sight/range/damage/timing/frame
  lists and armor divisors are mandatory YAML. No Defaults or duplicate profile.
  Static actors reject melee fields; animation resources validate before loading.
- DoomActors handles sight/chase/bites; DoomSprites publishes immutable motion
  snapshots while preserving health/pickups. Both directions must pass sight
  traces, avoiding wake/bites through the back of a one-sided line.
- Reproduced absence of damage in the pre-AI dirty tree before implementation.
  Final task check passed 192 fixtures and 25 file-based {TEST} procedures;
  fresh config/AI/combat/input/inventory A64 builds passed under QEMU. All 15
  X11 scenarios and all 132 original map probes passed. Evidence: scratch/ai-check.md.
- An initial GUI Ctrl test saw Meta due to the driver's physical modifier
  snapshot; priming it with an unbound character key fixed the test. Full final
  checks passed. Product/SDK code was not changed for that test-driver issue.
- New DoomActors is staged automatically and included in native/A64 builds.
  No new MiniA2 modules, so no A64 standard-library list regeneration is needed.
- Next: route finding/ranged attacks, weapon view/selection and more map actions.
  Chase remains direct with fixed bites; no sound wake/randomized original AI.
  Door obstruction remains player-only; no monster crushing/reversal. No CI,
  physical hardware, maximum-size stress or full playthrough claim.

## Current continuation: configurable pistol combat

The latest user request was to continue implementing the game while keeping
runtime gameplay and appearance tuning in mandatory startup YAML. The first
combat milestone is complete locally: held-key pistol fire, ammunition/cooldown,
nearest target damage, corpse frames and passable dead targets. Solid walls and
closed doors stop shots; open windows/grilles pass them regardless of movement
blocking flags. Actor health/height/death frames, weapon/crosshair settings,
inventory capacities/pickup effects, pickup reach and all keyboard actions are
required YAML. DoomInput keeps pure action state separate from the X11 adapter.
Shift-letter releases and simultaneous physical aliases are covered.

- Started clean on main at local `286f1e9`; that earlier demo commit remains local.
  This continuation is uncommitted. No push is authorized or was attempted.
- Native task check and all fourteen X11 scenarios passed; new input/combat and
  inventory checks use {TEST}. Fresh config/combat/inventory/input A64 builds
  passed under QEMU. All 132 original maps loaded/rendered/walked/turned/fired.
- Reproduced original Ctrl-without-ammo-consumption failure before feature work.
  Corrected test fixture assumptions and isolated GUI imports in the input check;
  final required checks are green. Evidence and exact limits: scratch/combat-check.md.
- No MiniA2/registry/engine source changes were needed. Both new Doom modules are
  staged by the existing Doom*.Mod rule and compiled for native/A64 targets.
- Pistol damage remains fixed with horizontal aim. Next: monster AI/animation,
  weapon views/selection and additional map actions. No barrel splash, drops,
  boss actions or sound yet; no complete-game, CI or physical-hardware claim.

## Current continuation: configurable procedural demo appearance

The user asked to continue the magic-number refactor. Doom now reads demo eye
height, wall height, light and five brick parameters from mandatory YAML fields.
Eye/wall heights use Doom map units; texture dimensions use pixels. Alternate
courses shift by half the configured brick width rather than the course height.
Validation rejects invalid dimensions, fully covered bricks, zero shade divisors
and eyes above walls before game construction. Wall coordinates/start position
remain authored map data. Complete default/custom/invalid fixtures are updated.
Ten file-based {TEST} procedures passed on Linux64 and A64 under QEMU; the
completeness test now rejects each of the 58 required keys. Task check passed;
both default PPM images remain byte-identical to the pre-change captures.
X11 startup checks used one unchanged executable for default/custom/unlit/1x1
solid textures; Escape passed and five invalid configurations exited with error.
The new appearance regression failed on the original code with ASSERT (exit 1).
Evidence: scratch/demo-settings-check.md. CI and physical A64 were not checked.
Mandatory-YAML changes were committed and pushed as b7b6490. The user requested
a local commit for this demo follow-up; no additional push is authorized.

## Completed startup YAML configuration

The user asked for magic-number refactoring and clarified that configuration
must be read at startup without recompiling. DoomConfig, DoomFormat, doom.yaml
and the HUD refactor are complete. MiniA2 now supplies bounded configuration
YAML with {TEST}; a2-registry includes its manifest/index/API documentation.
The user subsequently required a complete mandatory YAML file. DoomConfig.Defaults
and the default-profile constants are removed; every section and setting is
required. All in-tree callers load the file before using DoomConfig.values.
The procedural demo's five wall colors come from demo.colors, including brick
texture generation. Eight file-based {TEST} procedures passed on Linux64 and
A64 under QEMU; the completeness test rejects each of the 49 required keys.
Task check, the isolated benchmark and X11 startup checks passed; both default
PPM images remain byte-identical. The same executable changed colors after a
YAML-only edit and accepted an explicit full --config without a default file.
Missing/incomplete files are rejected. Evidence: scratch/required-config-check.md.
This follow-up completes the mandatory-YAML refactor; CI was not rerun.
The user previously authorized one commit and push of the initial YAML/HUD
refactor to main in each repository. MiniA2 commit: 1648ac5. Registry commit: f8fda92.
The final SDK is installed; its previous version is backed up in
/tmp/ao-doom-config/previous-sdk. Evidence and exact limits: scratch/config-check.md.
Final Doom check, YAML native/A64 tests and startup configuration probes passed.
The full registry gate has unrelated pre-existing community/crypto divergence;
its standard synchronization passed. Combat remains the next engine milestone.

## Previous exit checkpoint (2026-10-10)

The user asked to save state and is leaving. Stop feature work after this
checkpoint. Resume from combat when the user next asks to continue.

- Both repositories are on main and were clean before this checkpoint edit.
- Doom implementation: d72901f; completed milestone documentation: c96bd69.
  Engine implementation: 6aceba1; documentation: 045c00e. All are local.
- Previous validation passed task check, all twelve X11 scenarios and the
  short 132-map regression. Exact evidence and limits: scratch/actors-check.md.
  This checkpoint changes documentation only; tests were not rerun.
- No agent build/test commands remain running. No pushes were made.
- Keep sprites-grate.wad passable. Next implement firing/damage/death before
  expanding monster movement or animation; solid monsters currently block
  routes and cannot be killed. Door obstruction remains player-only.

## Current continuation: solid actor collision

The user asked to continue. The live checkout already had locked manual doors,
so the next completed milestone adds player collision with static solid actors.
Doom and engine started clean on main. Logical local commits remain authorized;
no push is authorized. The passable grille remains as agreed.

- Engine `GameGeometry.PositionCheck` and `MovePlayerChecked` check game-owned
  occupancy before each accepted axis substep. Existing `MovePlayer` callers
  retain their interface and wall-only behavior through NIL. Position and floor
  update only on accepted axes; sliding, bounded motion and validation remain.
- DoomThings now supplies positive footprint radii for all 60 known visible
  classic MF_SOLID types; zero means passable. The values were compared with
  id Software info.c. DoomSprites.Free checks overlap on both axes, allows
  exact tangent contact and ignores actor height for player collision as
  p_map.c does. Solid hanging bodies block; non-solid variants, corpses and
  pickups remain passable. Skill/single-player filters are unchanged.
- Doom invokes occupancy under its game monitor. Immutable actor metadata is
  shared by pickup snapshots. Success/failure map replacement and initially
  overlapping starts have regression coverage; overlaps remain blocking.
  Existing sprites-grate.wad flags/passability are unchanged.
- Before implementation a 70-forward-tick probe in sprite-rotations.wad passed
  the monster center, then returned Trap 5.8 on its stop-before-footprint
  assertion. The new checked tests cover the correct blocked position.
- task check passed four engine executables, 165 generated WAD fixtures, every
  previous suite, the new DoomActorsSmoke suite and Linux64 GUI compilation.
  Tests cover tangent/corner contact, long movement, sliding, steps, monster/
  barrel/decoration types, passable actors/items, spawn flags, snapshot state,
  overlapping starts and success/failure loads. Python syntax, source operation
  layout across 38 modules and whitespace checks passed.
- task gui-check passed all twelve scenes. The new barrel scene verifies
  approach, unchanged view under another forward input and diagonal sliding.
  Existing release/focus/turn/Escape, pickup, grille and key-door checks passed.
  All 132 original maps passed load/render/short movement again, and the four
  archive hashes match the original-map report. Inspected blocked/sliding
  captures and the first map's start view from each IWAD.
- A new engine test initially required x > 0.5 after diagonal sliding; the valid
  result was about 0.4545 with the correct raised floor. It now checks x > 0.25,
  free footprint and floor. Corrected full checks passed. A temporary probe
  path and unsupported KernelLog.Real call were fixed before reproducing red.
  No failing required suites remain. Details: scratch/actors-check.md.
- Code commits: engine 6aceba1; Doom d72901f. Engine docs: 045c00e; Doom docs
  and reporting: c96bd69. No pushes, merges, deployments or external WAD
  additions. MiniA2 source stays unchanged; checks use the installed Linux64 SDK.
- Next: combat, actor movement/animation and other map actions/sound. Monsters
  cannot be killed yet and may block routes. Door obstruction remains player-
  only; actor crushing/reversal is absent. Unknown types, powers, inter-map
  inventory, switches/lifts and Brutal Doom PK3 remain unsupported.
  Full playthroughs, exact pixel/collision equivalence, every original placement,
  worst-case 65536-thing performance and other platforms remain unverified.

## Previous continuation: locked manual doors

The user asked to continue after pickups/inventory. Doom and engine started
clean on main. The next completed milestone uses collected keys for manual
doors. Logical local commits remain authorized; pushes are not authorized.

- DoomDoors now supports locked raise/wait/close types 26/27/28 and open-only
  types 32/33/34. Blue is 26/32, yellow 27/34 and red 28/33. Cards and skulls
  of the matching color work without consumption. Key authorization precedes
  active-door toggles. Existing front/range/occlusion, movement speed, waiting,
  player-clearance reversal and immutable world snapshots are preserved.
  Supported moving sectors preload and validate their future upper materials.
- Use receives the inventory under the game monitor. A missing color is kept
  in the captured inventory value and drawn by DoomHud. Hints clear on the next
  use, matching pickup or successful load; failed loads preserve them. They
  have no timed expiry. A collected key requires a fresh Space press after
  denial. The grille fixture's flags and actor collision were not changed.
- Before implementation, a six-strafe-tick game probe collected the blue card
  in door-key.wad, then asserted opening after Use; it returned Trap 5.8.
  The same probe passed after integration. The new fixture uses type 32 and
  puts the blue key 64 units to the player's right: run task run --
  build/door-key.wad E1M1, try Space, briefly hold D, then press Space again.
- task check passed four engine binaries, 157 generated WAD fixtures, the new
  locked-door suite and every previous suite, plus Linux64 GUI compilation.
  All six types passed with cards and skulls, wrong colors, authorization
  while active, key retention, motion cycles and hidden-material rejection.
  Actual game pickup/unlocking/crossing, hint and load/snapshot cases passed.
- All eleven X11 scenes passed, including blue-key denial/pickup/unlocking and
  existing Space/release/focus/turn/Escape checks. All 132 original maps passed
  loading/rendering/short movement again; all archive hashes still match.
  Locked-door probes passed Doom E1M2 line 528/type 28, Doom II MAP02 line
  396/type 32, TNT MAP02 line 704/type 26 and Plutonia MAP04 line 199/type 27.
  The probe's --keys mode verifies denial then explicitly supplies all keys;
  it does not collect them along a playable route. TNT MAP01 yielded no valid
  fixed probe position; MAP02 was used instead, without asserting a map bug.
- Inspected missing-key, collected-key and open-door captures. Source operation
  layout passed 37 modules; whitespace and Python syntax passed. Temporary
  caller-edit and CONTINUE compiler errors were fixed before full validation.
  A bwrap mount failure required authorized native execution for affected
  checks. No failing required task suites remain. Engine and MiniA2 stay clean
  and unchanged; this uses the installed Linux64 SDK. See
  scratch/locked-doors-check.md for exact evidence and validation limits.
- Doom code/tests commit: 94249c4. Doom documentation/reporting is separate.
  No pushes, merges or deployments were made.
- Next: solid actor collision and combat, then other map actions and sound.
  Locked tagged switches, walk-over actions, lifts, firing/damage, monster
  behavior/animation, powers and inter-map inventory remain absent.
  Full playthroughs, every original key/door, exact pixels/collision equivalence,
  performance targets, other platforms and Brutal Doom PK3 remain unverified
  or unsupported.

## Previous continuation: pickups and inventory

The user resumed Doom work after keeping the passable grille fixture unchanged.
The later continuation authorizes the next gameplay milestone. Both targets
started clean on main; logical local commits remain authorized, not pushes.

- DoomInventory supplies 30 classic placed-item effects: health/armor, four
  ammo classes, nine weapon ownership bits, backpacks, cards and skull keys.
  Accepted items disappear; capped supplies remain. Bonuses, duplicate keys
  and backpacks preserve their consumption rules. Capacity doubles once.
  Full-armor megaspheres retain the current armor type. Unsupported powers
  remain on the map. Success resets inventory; failed loads preserve it.
- DoomSprites keeps immutable actor/image data and copies a SET32 collection
  bitmap only when a tick accepts items. The copied payload is at most 8192
  bytes. Count now reports remaining visible objects. Horizontal/vertical
  reach and a bounded portal trace prevent collection through solid walls,
  blocking grilles and closed passages. Existing grille flags are unchanged.
- Doom captures pose, world, sprites and a value copy of inventory together.
  DoomHud displays health/armor, ammo stocks, pickup/weapon counts and colored
  card/skull indicators in the bottom 20 pixels. GameText is reusable engine
  drawing with an original 3-by-5 font and no font assets or per-frame heap
  allocation. Both visible-scene helpers exclude the panel.
- Before implementation, a 40-tick probe left 24852 sprite pixels above the
  panel instead of removing a reached armor bonus and returned Trap 5.8.
  The same probe passed after integration. The final task check passed four
  engine binaries, 142 generated WAD fixtures, new inventory/pickup suites,
  prior Doom suites and Linux64 window compilation. The 33-item case verifies
  the bitmap word boundary; old scenes remain unchanged after collection.
- Ten X11 scenes passed, including real pickup-driven panel updates and the
  existing door/release/focus/turn/Escape checks. All 132 original maps passed
  load/render/short-movement again; archive hashes still match. Captures were
  inspected. After the final SET32 cleanup, focused sprite/pickup/inventory
  checks, GUI compilation, normal task check, the pickup window and four
  representative original starts passed on the final binaries.
- The megasphere armor-type edge was fixed during review. Plain SET follows
  the SDK address width, so the bitmap now names SET32 explicitly. Source
  operation layout passed 36 modules; whitespace and Python syntax passed.
  MiniA2 is unchanged and clean; this uses the installed Linux64 SDK.
  See scratch/pickups-check.md for evidence and exact validation limits.
- Commits: engine text/tests `3f38b75`, engine documentation `5ac7532`, Doom
  pickup/HUD integration/tests `a730244`; Doom documentation/reporting is
  separate. No pushes, merges or deployments were made.
- Next: use collected keys for locked doors, then solid actor collision and
  combat. Weapon selection/firing, damage, monster behavior/animation, powers,
  sound, dropped loot and inventory continuity between maps are absent.
  Full playthroughs, performance targets, original pixel/collision equivalence,
  other platforms and Brutal Doom PK3 behavior remain unverified/unsupported.

## Previous continuation: static map sprites

This section supersedes the grille stop point below. The user asked to continue;
both Doom and engine started clean on main. Reusable rendering stays in the
engine; spawn semantics and resources stay here. Logical local commits remain
authorized; pushes are not authorized.

- GameSurface now reuses a FLOAT64 depth buffer, adding 512000 bytes at 320 x 200.
  GameRenderer projects generic sprites and uses the same camera-forward depth
  for walls, planes and grilles. Physical boundaries occlude sprites even when
  their material is absent. The old local grille-row buffer was removed.
- DoomThings owns spawn-image facts for 116 visible classic types. DoomSprites
  filters medium-skill single-player THINGS, validates frames, supports eight
  directions and paired mirrored names, and caches immutable actor images.
  DoomTextures reuses its patch decoder and resource budgets with a lump-index
  sprite cache and signed header offsets. Actor and directory-work caps apply.
- Doom captures camera, world and sprites together under its monitor. Rendering
  holds no game lock and allocates no per-frame heap data. Ceiling attachments
  follow current world heights without changing old snapshots. Failed loads
  keep the current frame intact and publish no incomplete sprite scene.
- The baseline ignored visible THINGS: its sprite and empty frames matched.
  Final task check passed four engine binaries, 136 generated WAD fixtures,
  all prior Doom checks and Linux64 GUI compilation. New coverage includes
  holes/black, walls/grilles, sprite depth order, flags, resource rejection,
  ceiling motion, rotation/mirroring and failed-load preservation.
- All nine X11 scenes passed, including sprites and sprites behind grilles.
  All 132 original maps passed loading, rendering and short movement again;
  all four hashes match. After the last map publication-order adjustment,
  normal task check, four representative original starts and the sprite/grille
  window check passed on the final binary. Captures were inspected.
- Initial fixture assertions sampled outside an image or inside a patch hole;
  the directional fixture had an occluding island. Correcting those tests
  restored passing results. The layout helper initially matched multiline
  parameter separators; fixing it yielded 31 passing source files. Sandbox
  DNS blocked a reference download; an authorized native download passed.
- Source layout and whitespace checks passed; MiniA2 is unchanged and clean.
  See scratch/sprites-check.md for evidence, reproduction and limitations.
  Commits: engine projection/depth `291ef26`, engine documentation `f4cb591`,
  Doom integration/tests `ead962c`; Doom documentation/reporting is separate.
  No pushes.
- Next: actor simulation, pickups/inventory and keys, then locked/tagged actions,
  weapons, monster behavior and sound. Actors are static spawn images without
  collision or pickups; spectres lack fuzz. Unknown types are skipped, medium
  skill is fixed, and whole routes, original pixels, performance targets,
  other platforms and Brutal Doom PK3 behavior remain unverified/unsupported.

## Previous continuation: masked middle walls

This section supersedes the manual-door stop point below. The user resumed
the interrupted Doom session; both Doom and engine started clean on main.
Reusable mechanisms remain in ao-game-engine, with Doom interpretation here.

- Engine textures retain binary coverage in the existing pixel array:
  `SampleMasked` returns -1 for untouched texels, while ordinary `Sample`
  retains black fallback. Explicit black is covered; ordered patches preserve
  earlier coverage through later holes.
- Engine portal rendering records the nearest covered grille pixel in a local
  4096-row buffer and applies it after drawing the rooms behind. It handles
  layered grilles without per-frame allocation or a list of every crossed wall.
  Physical openings, current ceilings, offsets and top/bottom anchoring clip
  one texture height; horizontal sampling repeats.
- DoomMap loads validated middle textures on both sides of two-sided lines.
  The existing blocking and clearance rules still determine crossing. No
  game-specific flags or resource parsing moved into the engine.
- `task check` passed engine checks and 113 generated WAD fixtures, including
  coverage/black, patch composition, layering, pegging, offsets, vertical
  clipping, same-sector lines, immutable ceiling snapshots, blocking and
  malformed-resource cases. Linux64 window compilation also passed.
- `task gui-check` passed all seven scenes, including the new grille scene
  and the existing door/input checks. All 132 supplied original maps passed
  load/render/short-movement again; all four archive hashes still match.
  Captures were inspected. See `scratch/masked-check.md` for evidence.
- Sandbox writes to neighboring engine output and sandbox X11 access failed;
  authorized native checks passed. Two assertions initially sampled invisible
  fixture posts, and the first layout helper falsely matched declarations;
  correcting those checks restored passing results. No product failures
  remained in the final stated suites.
- Source operation layout and whitespace checks passed. MiniA2 is unchanged;
  this uses the installed Linux64 SDK. Game data/captures remain external or
  ignored. Commits: engine coverage/rendering `7daa43b`, Doom integration/tests
  `825559f`, engine documentation `754b2d6`; Doom reporting is separate. No pushes.
- Next: sprites/actors, inventory/keys and other map actions, then weapons,
  monsters, sound and gravity. Extended tall patches and translucency are
  absent. Whole routes, original grille pixel comparisons, performance targets,
  other platforms and Brutal Doom PK3 behavior remain unverified/unsupported.

## Previous continuation: manual doors

This section supersedes the static-sector state below. The user asked to
continue and retains the instruction to make separate logical local commits.
Both target repositories were clean on main at the start of this continuation.

- ao-game-engine `WithCeilings` publishes copied height arrays on shared sealed
  geometry/materials/partition data. Region reads, ray hits and standing
  clearance see one snapshot; old render snapshots stay unchanged. Wall hits
  carry opaque caller IDs and update ceiling-relative texture anchors.
- ao-doom `DoomDoors` implements manual unlocked types 1/31/117/118. Space
  activates from the front within 64 Doom units. Normal/fast speeds are 2/8
  units per tick; the target is the lowest neighboring ceiling minus 4 units.
  Raise doors wait 150 ticks and close; open doors stay open and consume their
  action. Active raise doors toggle direction. Obstruction by the player
  reverses closure before its world snapshot is published.
- DoomMap copies validated line/sector references into the door controller,
  maps wall IDs to linedefs and loads future upper materials around moving
  ceilings. Pegging flags retain correct texture anchoring during motion.
- Keyboard handling queues one use pulse until Space release and clears held
  input on focus loss. Game simulation consumes the pulse on its next tick;
  camera/world snapshots still use the game monitor without holding it while
  rendering. A failed replacement map leaves the current controller intact.
- `task check` passed engine checks, 103 generated WAD fixtures, full door
  cycles, obstruction/range/side/occlusion cases, texture anchors, snapshot
  immutability, local-door probing and Linux64 GUI compilation.
- `task gui-check` passed all six scenes, including animated opening, held
  Space, released/new Space, manual closure and reopening, followed by the
  existing movement/release/focus/turn/Escape checks.
- All 132 original maps passed the strengthened load/render/short-movement
  check again: Doom 36/36 and Doom II/TNT/Plutonia 32/32 each. `door-check`
  confirmed blocked-before/open-after crossing at Doom E1M1 line 148 (type 1),
  Doom II MAP01 line 47 (31), TNT MAP01 line 512 (31), and Plutonia MAP01 line
  205 (117). The probe places a camera near a door; it does not walk there
  from the original player start. See `scratch/doors-check.md` for evidence.
- The first door GUI check falsely rejected a legitimate two-color frame with
  `Frame contains no visible scene`. The helper now rejects uniform startup
  frames and background-only colors while accepting that textured door.
  The first original-door probe build missed an END; correcting its loop
  terminator restored compilation. All affected checks passed afterward.
- Source layout and whitespace checks passed. Game data and captures remain
  external/ignored. MiniA2 is unchanged; the existing Linux64 SDK was used.
- Commits: engine snapshots/anchors `4270236`; Doom doors/input/regressions
  `eeb13e0`. Documentation/reporting is committed separately. No pushes.
- Next: masked walls and sprites/actors, then inventory/keys and other map
  actions. Locked doors, tagged switches, walk-over triggers, lifts, moving
  floors, sound, weapons, monsters, gravity and Brutal Doom PK3 behavior are
  absent. Use traces scan walls and stop after 256 hits; ceiling motion copies
  a full height array per plane update. Full routes, performance targets,
  original pixel accuracy and other platforms remain unverified.

## Previous continuation: all original maps load

This section supersedes the earlier 90/132-map result. The user asked to
continue Doom work and retains the instruction to commit changes in separate
logical groups. All repositories were clean at the start of this continuation.

- ao-game-engine now accepts a copied, validated bottom-up partition tree for
  sector lookup. Nonnegative children must precede their parent; negative
  children name leaves. Wall bounds reject distant outside positions.
- ao-doom reads classic SEGS/SSECTORS/NODES, validates references and ranges,
  and follows the first seg for each subsector. Unused sectors and non-closed
  sector contours no longer reject valid original BSP maps. Empty BSP lumps
  retain the existing bounded contour checks for synthetic maps.
- Remaining original cases required exact wall tangency, inverted closed
  sector heights and absent one-sided middle materials. Missing materials
  remain physically solid; unknown named materials still fail.
- Doom E4M5 exposed a blank start frame at an exact portal boundary. Rays now
  choose the sector immediately ahead of the camera; regressions cover both
  viewing directions. The headless check now rejects background-only frames.
- `task check` passed engine checks, 92 generated WAD fixtures, map/resource
  rejection, movement, rendering, the local-map check and GUI compilation.
- The stronger native check passed all 132 original maps: Doom 36/36, Doom II
  32/32, TNT 32/32 and Plutonia 32/32. Each map renders start/walk views, takes
  35 forward and 97 turning ticks, then verifies a valid standing pose.
  Archive hashes and reproduced edge cases are in `scratch/original-map-check.md`.
- `task gui-check` passed all five generated scenes. Original Doom E4M5,
  Doom II MAP03, TNT MAP16 and Plutonia MAP02 passed targeted X11 input,
  release, focus loss, turning and Escape shutdown on the final build.
- GUI checks use a unique temporary executable copy and wait for a visible
  frame. A two-copy regression confirmed the other game's process, window
  and frame remain unchanged. An earlier parallel Plutonia MAP02 check
  exceeded the five-second shutdown budget; isolated checks passed, and its
  original cause remains unconfirmed. E4M5's separate rendering failure was
  reproduced natively and fixed. The first visible-frame helper used constant
  ASSERT(FALSE), rejected by the compiler; its runtime boolean check passed.
- Source operation layout and whitespace checks passed. Original WADs and
  captures remain external/ignored. MiniA2 is unchanged in this continuation;
  the installed Linux64 SDK and its previous driver fixes were used.
- Commits: ao-game-engine `a7eef4a`; ao-doom map loading/regressions `eaf13b1`.
  Window-check isolation, stronger frame checks and reporting are committed
  separately. No pushes were made.
- Next: masked walls, sprites/actors, moving doors and gameplay. Geometry is
  static; there are no weapons, monsters or gravity. These short checks do
  not establish a full playthrough, exact original pixels or performance.
  BSP accelerates region lookup only; edited leaf coverage, Brutal Doom PK3
  behavior and other platforms remain unverified or unsupported.

## Previous continuation: original maps

The user supplied local base-game IWADs in
`/home/andrejjj/Downloads/0/BRUTAL DOOM - I AM CRONHOLIO 1.2`.
This section supersedes the previous current state below.

- Added fullbright sky panoramas to ao-game-engine, sealed material/mapping
  validation and shared-sky boundaries with different physical ceiling heights.
- ao-doom maps F_SKY1 ceilings to SKY1-SKY4 by episode/map number and accepts
  explicitly absent upper/lower wall tiers (`-`); unknown names still fail.
- Added caller-provided tier omission flags to the engine without changing
  physical collision. Doom constants remain in ao-doom.
- Original E1M1/MAP01 initially failed with
  `Wall texture is not defined in TEXTURE1 or TEXTURE2`. Sky and absent-tier
  fixes resolved both. The generic sky test initially used a camera where the
  wall hid the sky; moving it into the lower room corrected that assertion.
- `task check` passed: engine checks, 64 original synthetic WAD fixtures, sky
  selection/pixels, omitted-tier pixels, invalid-resource rejection, movement
  and the new headless map check, followed by GUI compilation.
- `task gui-check` passed on the corridor, single-sector, multi-sector and sky
  scenes. Original Doom E1M1 and Doom II MAP01 passed the same input/window test.
- All 132 original maps received the short headless check: Doom 29/36,
  Doom II 21/32, TNT 26/32, Plutonia 14/32. The final build reproduced the same
  90 passes and 42 loader rejections; exact failures and archive hashes are in
  `scratch/original-map-check.md`. This is not a playthrough or pixel comparison.
- `task wad-check -- '/absolute/path/to/DOOM.WAD' E1M1` runs without a display
  and exports `build/original-start.ppm` / `build/original-walk.ppm`. Quoted
  absolute paths with spaces were tested. No game data/captures are committed.
- Engine sky/material changes: `7c1d3cd`. Doom compatibility and synthetic
  regressions: `ea3f8d3`. Local-WAD tooling/reporting form the next separate
  Doom commit. MiniA2 is unchanged. No pushes were made.
- Next: compatible interpretation of the 42 rejected maps, masked walls,
  actors, weapons and moving doors. Brutal Doom PK3 behavior is unsupported.
  No other platforms or original-map performance targets were checked.

## Previous continuation: sector milestone

### State at the end of the sector milestone

The user resumed Doom work and requested logical commits in every changed
repository. The multi-sector milestone is implemented; this section supersedes
all previous stop points below.

- ao-game-engine owns immutable sectors, directed sector walls, ray traversal
  through openings, projected floor/ceiling materials and circle collision with
  caller-provided height/step limits. Material density is supplied by the game.
- ao-doom loads multiple classic sectors, validates each closed contour, composes
  upper/lower wall materials and decodes cached 64 x 64 palette flats.
- Players cross openings, climb at most 24 Doom units, respect 56-unit clearance,
  slide against blocking lines and descend onto the floor. Height changes snap;
  there is no gravity or camera smoothing yet.
- `task run -- build/sectors.wad E1M1` opens three generated rooms. `task check`
  generates this and 49 other original fixtures without Doom assets.
- Staging removes only generated object/symbol files from build/ before copying
  sources, preventing incompatible imports after manual compiler invocations.

### Verification of the sector milestone

- `task check`: engine loop/scene/sector checks, 50 WAD fixtures, texture/flat
  decoding, sector movement/pixels and native GUI compilation passed.
- `task gui-check`: the corridor, single-sector WAD and multi-sector WAD passed
  visible rendering, movement, release, focus loss, turning and Escape shutdown.
- MiniA2 `task x11-keys`: release/focus messages passed again on Xephyr. The prior
  driver fixes were committed; no additional SDK source changes were needed.
  The previous exact Linux64 bundle remains the tested/installed SDK. Other
  targets were not rebuilt in this turn.
- `task bench`: 200 corridor frames in 502 ms, without display transfer; this is
  not a real-map or multi-sector performance claim.
- Pixel assertions exposed seams at portal boundaries and narrow multiplication
  overflow in flat palette conversion. Both were fixed and the checks passed.
- A later Wall record extension exposed stale adjacent compiler objects:
  `GameGeometry.Wall in Doom.@CodeSections: error: incompatible`. Clearing the
  staged compiler artifacts resolved it; the SDK sources were not changed.
- Sandbox-only baseline build failure came from writing the neighboring engine
  output; the authorized build outside that restriction passed.
- Source statement layout and whitespace checks passed.

### Commits and remaining work at the sector milestone

- ao-game-engine: simulation/clock (`9cf754a`), basic rendering/collision
  (`5de0899`), then sectors/portal rendering and movement as a separate commit.
- ao-doom: WAD/maps/textures (`61b9efd`), window/input/builds (`bb7aa84`), then
  multi-sector map interpretation, flats and regression checks separately.
- MiniA2: ordinary X11 releases (`2231be2`), then focus messages and automated
  key lifetime checks (`276a8d3`).
- No pushes, merges or deployments were performed.
- Next: validate an original map, then masked walls, sky rendering, sprites,
  actors, weapons and moving doors. Original Doom compatibility is unverified.
- Masked middle textures are still omitted. Geometry remains static. Collision
  and sector location scan geometry without a spatial index.

## Previous continuation: 2026-10-10

This section supersedes the original stop point below. The user requested a
reusable Active Oberon engine in ao-game-engine, Doom as its first game, Task
instead of Make, continued autonomous work, and MiniA2 fixes when necessary.

### Implemented

- ao-game-engine owns simulation, clock, immutable wall geometry/materials,
  collision, binary reads, framebuffer export, ray rendering and presentation.
- ao-doom owns the corridor scene, procedural brick art, 35 Hz player rules,
  the WAD archive/map/texture parsers and Linux64 window/input integration.
- `task run` launches the built-in scene; W/S and Up/Down move, A/D strafe,
  Left/Right turn, Escape exits. `task run -- build/valid.wad E1M1` loads an
  original generated fixture after `task check`.
- The WAD loader validates bounds, record sizes, references, closed boundaries,
  and a player start inside the sector. It supports single-sector maps only.
  Multi-sector maps fail explicitly. Classic wall textures load from PLAYPAL,
  PNAMES and TEXTURE1/TEXTURE2; patches are composed with clipping and cached.
- Renderer captures camera and sealed world together under the game monitor,
  then renders without holding that monitor. It uses a reused 320 x 200 buffer.
- Window rendering follows simulation ticks and does not redraw identical frames
  between ticks. Long frame delays are clamped to 250 ms by game policy.

### MiniA2 fixes and exact SDK

- Ordinary X11 key releases were missing. The original installed SDK failed the
  window release test and the standalone key test timed out. Fixed
  source/Unix.KbdMouse.Mod; letters, arrows, modifiers and Escape now release.
- Losing focus also left movement held. Reproduced that separately, added
  Inputs.FocusMsg and X11 focus notifications, and reset held controls in Doom.
- Added tests/X11Keys.Mod, tests/x11-keys.c, tests/x11-keys-check.sh and
  `task x11-keys` in MiniA2. Tests run on their own Xephyr server.
- Ran tests/gen-a64-stdlib.sh; configs/moduleListA64.txt remained unchanged.
- Rebuilt `task Linux64` and `task bundle` after each driver/API change, then
  installed the exact local tarball through sdk/install.sh. Installed KbdMouse
  and Inputs object checksums match target/bundle.
- SDK version: 2026.09.26-2-g07139b1-dirty. Only Linux64 was rebuilt/validated;
  advertised cross-target libraries are not evidence of checks in this session.

### Verification

- `task check`: passed engine, signed decoding, pixel/material and collision
  assertions, WAD/map/texture parsing with 39 generated fixtures, and native GUI compilation.
- `task gui-check`: passed both corridor and WAD scenes for visible rendering,
  movement, release, focus loss, turning and Escape shutdown on local X11.
- `task x11-keys` in MiniA2: passed release and focus messages on Xephyr.
- Invalid window startup returned exit 1 for missing WAD, bad vertices, damaged
  patch columns, and unsupported multi-sector maps.
- `task gui-repaint` after the first driver change: passed covered-window
  restoration; unmap preservation is explicitly not required by that check.
- `task bench`: 200 textured 320 x 200 frames in 453 ms on this machine; rendering
  only, not display transfer or real Doom map performance.
- Inspected build/scene.ppm and build/wad-scene.ppm; PNG previews are diagnostic
  build artifacts. Whitespace checks passed in all three repositories.

### Texture continuation

- Split DoomWad (archive), DoomMap (level interpretation), and DoomTextures
  (palettes, texture definitions, classic posts and cached composites) to keep
  dependencies acyclic. GameMaterials remains format-independent in the engine.
- Added texture scale/offset and light fields to immutable engine wall materials.
  Map texture coordinates account for sidedef offsets and bottom alignment flags.
- Texture tests cover caching, case-insensitive lookup, TEXTURE2, clipping,
  ordered multi-patch composition, invalid references and truncated post data.
- Texture limits: 1024 dimensions, 16 million cached pixels, 64 million decode
  samples/posts/columns. No masked wall drawing or extended tall-patch support.

### Remaining work and boundaries

- Next: sector portals, floors and multi-sector collision. Original Doom maps, sprites, actors, weapons, doors and compatibility
  remain unimplemented or unverified. Do not call the prototype a finished clone.
- Callback traps/reentrant calls are unsupported by GameLoop. Geometry/rendering
  currently scan all walls; no spatial index or original-game performance claim.
- No original Doom assets or upstream implementation code were copied. Format
  references are id Software's w_wad.c, doomdata.h, r_data.c and r_segs.c; generated fixtures are ours.
- No commits or pushes were made. Existing dirty/untracked work was preserved.
- Writes/builds outside ao-doom needed sandbox escalation, already authorized by
  the user's engine placement and explicit MiniA2 instruction.

## Original objective and stop point

Rewrite the classic Doom engine in Active Oberon.
The user authorized repository setup, explicitly asked to stop there, and then requested a reference review.
The latest instruction is to save state and exit. Engine implementation has not started.

## Current repository

- Path: /home/andrejjj/Projects/A2/ao-doom.
- Branch: main. Existing HEAD: 96cf17e (`Initial coomit`).
- The tracked worktree was clean before this handoff was written.
- README.md describes the project, the initial Linux64/MiniA2 target, and the first milestone: load a WAD, render one map, and walk with collision detection.
- .gitignore excludes compiler output, build output, local WAD files, and agent files.
- AGENTS.md exists locally and is ignored by Git. Read it before continuing; it owns the one-operation-per-line rule for all Active Oberon source.
- No source modules, build scripts, game data, or runnable game have been added.

## Reference decisions and findings

- Recommended primary reference: https://github.com/id-Software/DOOM/tree/master/linuxdoom-1.10.
- Doom was recommended over Quake for the first rewrite because Quake adds full 3D models and a QuakeC interpreter.
- Additional reference reviewed: https://github.com/PascalCorpsman/FPC_DOOM.
- Inspected FPC_DOOM commit: a901194e01c6153875761f63e362ef345f2b8057, dated 2026-09-06.
- FPC_DOOM is derived from Crispy Doom and has its own behavior changes. Use it as a porting example; keep id Software's code as the primary reference.
- Its lessons_learned.md documents signed shifts, C expression side effects, pointers, and array layout pitfalls.
- Its OpenGL output uploads an already rendered software framebuffer as a texture; this is not a replacement 3D renderer.
- A source scan found 44 explicit `Port me.` exceptions in 18 of 107 engine units.
- Its README reports broken demo playback and unavailable savegames. These claims were not tested.
- Its license.md offers Postcardware or modified LGPL, while Crispy Doom is GPL. Clarify applicable terms before copying FPC_DOOM code.
- Temporary checkout: /tmp/ao-doom-fpc-reference.QRDoiE. It may disappear; recover it from the upstream commit if needed.

## Verification and continuation

Whitespace, final newlines, and .gitignore behavior were checked during repository setup.
FPC_DOOM was inspected only; it was not built or run. Game compatibility and Active Oberon performance remain unverified.
No commits, pushes, upstream messages, or engine implementation were performed by the agent.
Continue from README.md and AGENTS.md when the user gives the next implementation instruction.
