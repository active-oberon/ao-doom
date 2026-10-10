# ao-doom session handoff

Updated: 2026-10-10 15:11:55 UTC

## Current continuation: original maps

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
