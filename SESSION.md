# ao-doom session handoff

Updated: 2026-10-10 21:02:00 UTC

## Current continuation: masked middle walls

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
